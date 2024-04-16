#!/usr/bin/env python3

# Use to easily transform output from Packer into structure for Cloudformation
# cat manifest.json | ./generate-changelog.py 

def marshall_artifacts(artifact_id):
    artifacts = artifact_id.split(',')
    for i in range(len(artifacts)):
        index = artifacts[i].find(":")
        artifacts[i] = artifacts[i][:index + 1] + " " + artifacts[i][index + 1:]
        artifacts[i] = "- " + artifacts[i]
    return "\n".join(artifacts)

def append_to_output(output, name, artifact_id):
    output += "\n"
    output += "### " + name + "\n"
    output += marshall_artifacts(artifact_id) + "\n"
    return output

import sys, json
data = json.load(sys.stdin)
builds = data["builds"]
changes = ""
for build in builds:
    name = build["name"]
    if changes == "":
        changes += "## " + build["custom_data"]["sourcegraph_version"] + "\n"
        changes += "\n ## Updates \n"
    artifact_id = build["artifact_id"]
    changes = append_to_output(changes, name, artifact_id)

changes = changes + "\n"
changes.split('\n')
with open("CHANGELOG.md", 'r+') as fd:
    contents = fd.readlines()
    contents.insert(74, changes)  # new_string should end in a newline
    fd.seek(0)  # readlines consumes the iterator, so we need to start over
    fd.writelines(contents)  # No need to truncate as we are increasing filesize
