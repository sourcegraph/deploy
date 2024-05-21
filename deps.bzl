load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def packer():
    version = "1.10.2"
    build_file_content = """exports_files(["packer"])"""

    http_archive(
        name = "packer_macos_aarch64",
        build_file_content = build_file_content,
        sha256 = "b23ebef504b48a6d99b975726eb593504bfe1858f63609418e4704c19ef4e538",
        urls = ["https://releases.hashicorp.com/packer/{0}/packer_{0}_darwin_arm64.zip".format(version)],
    )
    http_archive(
        name = "packer_macos_x86_64",
        build_file_content = build_file_content,
        sha256 = "",
        urls = ["https://releases.hashicorp.com/packer/{0}/packer_{0}_darwin_amd64.zip".format(version)],
    )
    http_archive(
        name = "packer_linux_x86_64",
        build_file_content = build_file_content,
        sha256 = "",
        urls = ["https://releases.hashicorp.com/packer/{0}/packer_{0}_linux_amd64.zip".format(version)],
    )
