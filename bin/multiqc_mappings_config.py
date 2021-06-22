#!/usr/bin/env python

import sys

with open(sys.argv[1], "r") as fin, open(sys.argv[2], "w") as fout:
    header = fin.readline().split(',')
    config = "sample_names_rename_buttons:\n"
    config += "\n".join(['  - ' + x.strip('"') for x in header])
    config += "sample_names_rename:\n"
    for line in fin:
        config += f"  - [{', '.join(line.strip().split(','))}]\n"
    fout.write(config)

