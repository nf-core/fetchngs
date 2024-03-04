#!/usr/bin/env python

# This script is used to identify *.nf.test files for changed functions/processs/workflows/pipelines and *.nf-test files
# with changed dependencies, then return as a JSON list

import argparse
import json
import logging
import re
import yaml

from itertools import chain
from pathlib import Path
from git import Repo


def parse_args() -> argparse.Namespace:
    """
    Parse command line arguments and return an ArgumentParser object.

    Returns:
        argparse.ArgumentParser: The ArgumentParser object with the parsed arguments.
    """
    parser = argparse.ArgumentParser(
        description="Scan *.nf.test files for function/process/workflow name and return as a JSON list"
    )
    parser.add_argument(
        "-r",
        "--head_ref",
        required=True,
        help="Head reference branch (Source branch for a PR).",
    )
    parser.add_argument(
        "-b",
        "--base_ref",
        required=True,
        help="Base reference branch (Target branch for a PR).",
    )
    parser.add_argument(
        "-x",
        "--ignored_files",
        nargs="+",
        default=[
            ".git/*",
            ".gitpod.yml",
            ".prettierignore",
            ".prettierrc.yml",
            "*.md",
            "*.png",
            "modules.json",
            "pyproject.toml",
            "tower.yml",
        ],
        help="List of files or file substrings to ignore.",
    )
    parser.add_argument(
        "-i",
        "--include",
        type=Path,
        default=".github/python/include.yaml",
        help="Path to an include file containing a YAML of key value pairs to include in changed files. I.e., return the current directory if an important file is changed.",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Logging level",
    )
    parser.add_argument(
        "-t",
        "--types",
        nargs="+",
        choices=["function", "process", "workflow", "pipeline"],
        default=["function", "process", "workflow", "pipeline"],
        help="Types of tests to include.",
    )
    return parser.parse_args()


def read_yaml_inverted(file_path: str) -> dict:
    """
    Read a YAML file and return its contents as a dictionary but reversed, i.e. the values become the keys and the keys become the values.

    Args:
        file_path (str): The path to the YAML file.

    Returns:
        dict: The contents of the YAML file as a dictionary inverted.
    """
    with open(file_path, "r") as f:
        data = yaml.safe_load(f)

    # Invert dictionary of lists into contents of lists are keys, values are the original keys
    # { "key": ["item1", "item2] } --> { "item1": "key", "item2": "key" }
    return {value: key for key, values in data.items() for value in values}


def find_changed_files(
    branch1: str, branch2: str, ignore: list[str], include_files: dict[str, str]
) -> list[Path]:
    """
    Find all *.nf.tests that are associated with files that have been changed between two specified branches.

    Args:
        branch1 (str)      : The first branch being compared
        branch2 (str)      : The second branch being compared
        ignore  (list)     : List of files or file substrings to ignore.
        include_files (dict): Key value pairs to return if a certain file has changed, i.e. if a file in a directory has changed point to a different directory.

    Returns:
        list: List of files matching the pattern *.nf.test that have changed between branch2 and branch1.
    """
    # create repo
    repo = Repo(".")
    # identify commit on branch1
    branch1_commit = repo.commit(branch1)
    # identify commit on branch2
    branch2_commit = repo.commit(branch2)
    # compare two branches
    diff_index = branch1_commit.diff(branch2_commit)
    # collect changed files
    changed_files = []
    for file in diff_index:
        changed_files.append(Path(file.a_path))
    # remove ignored files
    for file in changed_files:
        for ignored_substring in ignore:
            if file.match(ignored_substring):
                changed_files.remove(file)
        for include_path, include_key in include_files.items():
            if file.match(include_path):
                changed_files.append(Path(include_key))

    return changed_files


def detect_nf_test_files(changed_files: list[Path]) -> list[Path]:
    """
    Detects and returns a list of nf-test files from the given list of changed files.

    Args:
        changed_files (list[Path]): A list of file paths.

    Returns:
        list[Path]: A list of nf-test file paths.
    """
    result: list[Path] = []
    for path in changed_files:
        path_obj = Path(path)
        # If Path is the exact nf-test file add to list:
        if path_obj.match("*.nf.test"):
            result.append(path_obj)
        # Else recursively search for nf-test files:
        else:
            for file in path_obj.rglob("*.nf.test"):
                result.append(file)
    return result


def process_files(files: list[Path]) -> list[str]:
    """
    Process the files and return lines that begin with 'workflow', 'process', or 'function' and have a single string afterwards.

    Args:
        files (list): List of files to process.

    Returns:
        list: List of lines that match the criteria.
    """
    result = []
    for file in files:
        with open(file, "r") as f:
            is_pipeline_test = True
            lines = f.readlines()
            for line in lines:
                line = line.strip()
                if line.startswith(("workflow", "process", "function")):
                    words = line.split()
                    if len(words) == 2 and re.match(r'^".*"$', words[1]):
                        result.append(line)
                        is_pipeline_test = False

            # If no results included workflow, process or function
            # Add a dummy result to fill the 'pipeline' category
            if is_pipeline_test:
                result.append("pipeline 'PIPELINE'")

    return result


def generate(
    lines: list[str], types: list[str] = ["function", "process", "workflow", "pipeline"]
) -> dict[str, list[str]]:
    """
    Generate a dictionary of function, process and workflow lists from the lines.

    Args:
        lines (list): List of lines to process.
        types (list): List of types to include.

    Returns:
        dict: Dictionary with function, process and workflow lists.
    """
    result: dict[str, list[str]] = {
        "function": [],
        "process": [],
        "workflow": [],
        "pipeline": [],
    }
    for line in lines:
        words = line.split()
        if len(words) == 2:
            keyword = words[0]
            name = words[1].strip("'\"")  # Strip both single and double quotes
            if keyword in types:
                result[keyword].append(name)
    return result


def find_changed_dependencies(paths: list[Path], tags: list[str]) -> list[Path]:
    """
    Find all *.nf.test files with changed dependencies from a list of paths.

    Args:
        paths (list): List of directories or files to scan.
        tags (list): List of tags identified as having changes.

    Returns:
        list: List of *.nf.test files with changed dependencies.
    """
    # this is a bit clunky
    result = []
    for path in paths:
        # find all *.nf-test files
        nf_test_files = []
        for file in path.rglob("*.nf.test"):
            nf_test_files.append(file)
        # find nf-test files with changed dependencies
        for nf_test_file in nf_test_files:
            with open(nf_test_file, "r") as f:
                lines = f.readlines()
                for line in lines:
                    line = line.strip()
                    if line.startswith("tag"):
                        words = line.split()
                        if len(words) == 2 and re.match(r'^".*"$', words[1]):
                            name = words[1].strip(
                                "'\""
                            )  # Strip both single and double quotes
                            if name in tags:
                                result.append(nf_test_file)

    return list(set(result))


if __name__ == "__main__":

    # Utility stuff
    args = parse_args()
    logging.basicConfig(level=args.log_level)

    # Parse nf-test files for target test tags
    if args.include:
        include_files = read_yaml_inverted(args.include)
    changed_files = find_changed_files(
        args.head_ref, args.base_ref, args.ignored_files, include_files
    )
    nf_test_files = detect_nf_test_files(changed_files)
    lines = process_files(nf_test_files)
    result = generate(lines)

    # Get only relevant results (specified by -t)
    # Unique using a set
    target_results = list(
        {item for sublist in map(result.get, args.types) for item in sublist}
    )

    # Parse files to identify nf-tests with changed dependencies
    changed_dep_files = find_changed_dependencies([Path(".")], target_results)

    # Combine target nf-test files and nf-test files with changed dependencies
    all_nf_tests = [
        str(test_path) for test_path in set(changed_dep_files + nf_test_files)
    ]

    # Print to stdout
    print(json.dumps(all_nf_tests))
