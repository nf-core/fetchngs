#!/usr/bin/env python

import sys

with open(sys.argv[1], "r") as fin, open(sys.argv[2], "w") as fout:
    header = fin.readline().split('\t')
    config = "sample_names_rename_buttons:\n"
    config += "\n".join(['  - ' + x for x in header])
    config += "sample_names_rename:\n"
    for line in fin:
        lspl = ['"' + x + '"' for x in line.strip().split('\t')]
        config += f"  - [{', '.join(lspl)}]\n"
    fout.write(config)

