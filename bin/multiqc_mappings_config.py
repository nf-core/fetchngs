#!/usr/bin/env python

import csv
import sys

with open(sys.argv[1], "r") as fin, open(sys.argv[2], "w") as fout:
    header = next(csv.reader(fin))
    config = "sample_names_rename_buttons:\n"
    config += "\n".join(["  - " + x.strip('"') for x in header])
    config += "\nsample_names_rename:\n"
    rename = []
    for row in csv.reader(fin):
        rename.append(f"  - [{', '.join(row)}]")
    fout.write(config + "\n".join(sorted(rename)) + "\n")
