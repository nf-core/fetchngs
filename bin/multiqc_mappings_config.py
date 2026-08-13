#!/usr/bin/env python

import csv
import sys

with (
    open(sys.argv[1], "r", newline="") as fin,
    open(sys.argv[2], "w", newline="") as fout,
):
    reader = csv.reader(fin)
    try:
        header = next(reader)
    except StopIteration:
        sys.exit(0)
    config = "sample_names_rename_buttons:\n"
    config += "\n".join(["  - " + x for x in header])
    config += "\nsample_names_rename:\n"
    rename = []
    for row in reader:
        rename.append(f"  - [{', '.join(row)}]")
    fout.write(config + "\n".join(sorted(rename)) + "\n")
