#!/usr/bin/env python3

# Use to easily transform output from Packer into structure for Cloudformation
# cat _ami.yaml | yj | ./_convert.py

import sys, json
data = json.load(sys.stdin)
if len(data["io2"].keys()) != len(data["gp3"].keys()):
    print("Missing AMIs")
    print("gp3 Missing: ", set(data["io2"].keys()) - set(data["gp3"].keys()))
    print("io2 missing: ", set(data["gp3"].keys()) - set(data["io2"].keys()))
    exit()
for region in sorted(list(data["io2"].keys())):
    print(f"{region}:\n  io2: {data['io2'][region]}\n  gp3: {data['gp3'][region]}")