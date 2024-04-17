"""Wrapper around a packer sh_binary target"""
load("@rules_python//python:defs.bzl", "py_binary")

def packer(name, **kwargs):
    native.sh_binary(
        name = name,
        srcs = ["packer.sh"],
        args = select({
            "//platforms/config:linux_x86_64": ["$(rootpath @packer_linux_x86_64//:packer)"],
            "//platforms/config:macos_aarch64": ["$(rootpath @packer_macos_aarch64//:packer)"],
            "//platforms/config:macos_x86_64": ["$(rootpath @packer_macos_x86_64//:packer)"],
        }),
        data = select({
            "//platforms/config:linux_x86_64": ["@packer_linux_x86_64//:packer"],
            "//platforms/config:macos_aarch64": ["@packer_macos_aarch64//:packer"],
            "//platforms/config:macos_x86_64": ["@packer_macos_x86_64//:packer"],
        }) + kwargs.pop("data", []),
        tags = ["manual"] + kwargs.pop("tags", []),
        visibility = kwargs.pop("visibility", ["//:__subpackages__"]),
        **kwargs
    )
    py_binary(
      name = "generate-changelog",
      srcs = ["generate-changelog.py"],
      data = ["manifest.json", "CHANGELOG.md"],
    )
    return [DefaultInfo(files=depset(["CHANGELOG.md"]))]
