#!/usr/bin/env python

## This script is used to generate scan *.nf.test files for function/process/workflow name and return as a JSON list
# It is functionally similar to nf-test list but fills a gap until feature https://github.com/askimed/nf-test/issues/196 is added

import argparse
import json
import logging
import re
import yaml

from pathlib import Path


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
        "paths", nargs="*", default=["."], help="List of directories or files to scan"
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


def find_files(paths: list[str]) -> list[Path]:
    """
    Find all files matching pattern *.nf.test recursively from a list of paths.

    Args:
        paths (list): List of directories or files to scan.

    Returns:
        list: List of files matching the pattern *.nf.test.
    """
    return [test_file for path in paths for test_file in Path(path).rglob("*.nf.test")]


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
            lines = f.readlines()
            for line in lines:
                line = line.strip()
                if line.startswith(("workflow", "process", "function")):
                    words = line.split()
                    if len(words) == 2 and re.match(r'^".*"$', words[1]):
                        result.append(line)
    return result


def generate(
    lines: list[str], types: list[str] = ["function", "process", "workflow", "pipeline"]
) -> dict[str, list[str]]:
    """
    Generate a dictionary of function, process, workflow, and pipeline lists from the lines.

    Args:
        lines (list): List of lines to process.
        types (list): List of types to include.

    Returns:
        dict: Dictionary with function, process, workflow, and pipeline lists.
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


def read_yaml_file(file_path: str) -> dict:
    """
    Read a YAML file and return its contents as a dictionary.

    Args:
        file_path (str): The path to the YAML file.

    Returns:
        dict: The contents of the YAML file as a dictionary.
    """
    with open(file_path, "r") as f:
        data = yaml.safe_load(f)
    return data


if __name__ == "__main__":

    # Utility stuff
    args = parse_args()
    logging.basicConfig(level=args.log_level)

    files = find_files(args.paths)
    lines = process_files(files)
    result = generate(lines, args.types)

    # Flatten dict to list of results
    # Mmm ugly. Yet glorious.
    result_flat = list(set().union(*result.values()))
    # Print to stdout
    print(json.dumps(result_flat))
