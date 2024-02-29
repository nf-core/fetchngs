#!/usr/bin/env python

import sys

with open(sys.argv[1], "r") as fin, open(sys.argv[2], "w") as fout:
    header = fin.readline().split(",")
    config = "sample_names_rename_buttons:\n"
    config += "\n".join(["  - " + x.strip('"') for x in header])
    config += "sample_names_rename:\n"
    rename = []
    for line in fin:
        rename.append(f"  - [{', '.join(line.strip().split(','))}]")
    fout.write(config + "\n".join(sorted(rename)) + "\n")
