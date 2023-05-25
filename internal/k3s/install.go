package k3s

import (
	"bytes"
	"compress/gzip"
	"context"
	"embed"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/user"
	"strconv"

	"github.com/sourcegraph/deploy/internal/system/service"

	"github.com/sourcegraph/sourcegraph/lib/errors"
)

// The K3s installer, binary, and corresponding images are embedded into the binary at build and pinned to a specific version.
// This allows an offline first approach to the installation as well as guarantees about the version of K3s we use for
// our deployments.
//
//go:embed bin
var embeddedFS embed.FS

type Options struct {
	Version string
	SELinux bool
}

type Option = func(option *Options)

// EnableSELinux will enable SELinux support in the k3s installation.
func EnableSELinux() Option {
	return func(option *Options) {
		option.SELinux = true
	}
}

// Install will install K3s using the binaries, container images, and scripts packaged in the
// embedded filesystem.
//
// Options include:
//   - EnableSELinux
func Install(ctx context.Context, opts ...Option) error {
	options := Options{
		Version: "",
		SELinux: false,
	}

	for _, opt := range opts {
		opt(&options)
	}

	images, err := unpackImages()
	if err != nil {
		return errors.Errorf("failed to install k3s: %s", err)
	}
	defer func() { _ = images.Close() }()

	bin, err := unpackBin()
	if err != nil {
		return errors.Errorf("failed to install k3s: %s", err)
	}
	defer func() { _ = bin.Close() }()

	installer, err := unpackInstaller()
	if err != nil {
		return errors.Errorf("failed to install k3s: %s", err)
	}
	defer func() { _ = installer.Close() }()

	err = os.MkdirAll("/etc/rancher/k3s/", 0755)
	if err != nil {
		return errors.Errorf("failed to install k3s: %s", err)
	}

	cmd := exec.CommandContext(ctx, "/bin/sh", installer.Name(),
		"--node-name", "sourcegraph-0",
		"--write-kubeconfig", "/etc/rancher/k3s/k3s.yaml",
		"--write-kubeconfig-mode", "644",
		"--cluster-cidr", "10.10.0.0/16",
		"--kubelet-arg", "containerd=/run/k3s/containerd/containerd.sock",
		"--etcd-expose-metrics",
	)

	cmd.Env = append(os.Environ(),
		"K3S_TOKEN=none",
		"INSTALL_K3S_SKIP_START=true",
		"INSTALL_K3S_SKIP_DOWNLOAD=true",
		"INSTALL_K3S_SELINUX_WARN=true",
	)

	if options.SELinux {
		cmd.Args = append(cmd.Args, "--selinux")
	}

	err = cmd.Run()
	if err != nil {
		return errors.Errorf("failed to install k3s: %s", err)
	}

	err = service.Enable(ctx, "k3s.service")
	if err != nil {
		return errors.Errorf("failed to install k3s: %s", err)
	}

	return nil
}

// unpackImages unpacks the embedded k3s container images to the system.
func unpackImages() (*os.File, error) {
	err := os.MkdirAll("/var/lib/rancher/k3s/agent/images/", 0755)
	if err != nil {
		return nil, err
	}

	images, err := embeddedFS.ReadFile("bin/k3s-airgap-images-amd64.tar.gz")
	if err != nil {
		return nil, err
	}

	unpackedImages, err := os.OpenFile("/var/lib/rancher/k3s/agent/images/k3s-airgap-images-amd64.tar", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return nil, err
	}

	gzipReader, err := gzip.NewReader(bytes.NewReader(images))
	defer func() {
		_ = gzipReader.Close()
	}()

	_, err = io.Copy(unpackedImages, gzipReader)
	if err != nil {
		return nil, err
	}

	return unpackedImages, nil
}

// unpackBin unpacks the embedded k3s binary to the system.
func unpackBin() (*os.File, error) {
	k3s, err := embeddedFS.ReadFile("bin/k3s")
	if err != nil {
		return nil, err
	}
	unpackedK3s, err := os.OpenFile("/usr/local/bin/k3s", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return nil, err
	}

	_, err = unpackedK3s.Write(k3s)
	if err != nil {
		return nil, err
	}

	return unpackedK3s, nil
}

// unpackInstaller unpacks the k3s installer to a temporary file on the system.
func unpackInstaller() (*os.File, error) {
	installer, err := embeddedFS.ReadFile("bin/install.sh")
	if err != nil {
		return nil, err
	}

	unpackedInstaller, err := os.CreateTemp("", "k3s-install-*.sh")
	if err != nil {
		return nil, err
	}

	_, err = unpackedInstaller.Write(installer)
	if err != nil {
		return nil, err
	}

	err = os.Chmod(unpackedInstaller.Name(), 0755)
	if err != nil {
		return nil, err
	}

	return unpackedInstaller, nil
}

// Configure will configure the K3s install for a provided username.
// This includes setting up the kubectl configuration, common aliases, and file permissions
func Configure(username string) error {
	err := setupKubeConfig(username)
	if err != nil {
		return err
	}

	err = setupK3sConfig(username)
	if err != nil {
		return err
	}

	err = setupAliases(fmt.Sprintf("/home/%s/.bashrc", username))
	if err != nil {
		return err
	}

	return nil
}

// setupK3sConfig setups up the proper file permissions for the k3s config file.
func setupK3sConfig(username string) error {
	configPath := "/etc/rancher/k3s/k3s.yaml"
	fileInfo, err := os.Stat(configPath)
	if err != nil {
		return errors.Errorf("failed to setup k3s config file: %s", err)
	}

	u, err := user.Lookup(username)
	if err != nil {
		return errors.Errorf("failed to setup k3s config file: %s", err)
	}

	uid, _ := strconv.Atoi(u.Uid)
	gid, _ := strconv.Atoi(u.Gid)

	err = os.Chown(configPath, uid, gid)
	if err != nil {
		return errors.Errorf("failed to setup k3s config file: %s", err)
	}

	currentPermissions := fileInfo.Mode()
	// remove read permissions for the group (4) and others (32)
	newPermissions := currentPermissions &^ (os.FileMode(4) | os.FileMode(32))

	err = os.Chmod(configPath, newPermissions)
	if err != nil {
		return errors.Errorf("failed to setup k3s config file: %s", err)
	}

	return nil
}

func setupKubeConfig(username string) error {
	err := os.MkdirAll("/etc/rancher/k3s/", 0755)
	if err != nil {
		return errors.Errorf("failed to setup kube config file: %s", err)
	}

	source, err := os.OpenFile("/etc/rancher/k3s/k3s.yaml", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return errors.Errorf("failed to setup kube config file: %s", err)
	}
	defer func() {
		_ = source.Close()
	}()

	err = os.MkdirAll(fmt.Sprintf("/home/%s/.kube/", username), 0755)
	if err != nil {
		return errors.Errorf("failed to setup kube config file: %s", err)
	}

	destination, err := os.OpenFile(fmt.Sprintf("/home/%s/.kube/config", username), os.O_RDWR|os.O_CREATE, 0600)
	if err != nil {
		return errors.Errorf("failed to setup kube config file: %s", err)
	}
	defer func() {
		_ = destination.Close()
	}()

	u, err := user.Lookup(username)
	if err != nil {
		return errors.Errorf("failed to setup kube config file: %s", err)
	}

	uid, _ := strconv.Atoi(u.Uid)
	gid, _ := strconv.Atoi(u.Gid)

	err = os.Chown(fmt.Sprintf("/home/%s/.kube", username), uid, gid)
	if err != nil {
		return errors.Errorf("failed to setup kube config file: %s", err)
	}

	err = os.Chown(fmt.Sprintf("/home/%s/.kube/config", username), uid, gid)
	if err != nil {
		return errors.Errorf("failed to setup kube config file: %s", err)
	}

	_, err = io.Copy(destination, source)
	if err != nil {
		return errors.Errorf("failed to setup kube config file: %s", err)
	}

	return nil
}

// setupAliases setups up common shell alias for k8s and helm.
func setupAliases(path string) error {
	f, err := os.OpenFile(path, os.O_RDWR|os.O_APPEND|os.O_CREATE, 0664)
	if err != nil {
		return errors.Errorf("failed to setup aliases: %s", err)
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprintln(f, "KUBECONFIG=/etc/rancher/k3s/k3s.yaml")
	if err != nil {
		return errors.Errorf("failed to setup aliases: %s", err)
	}

	_, err = fmt.Fprintln(f, "alias k='kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml'")
	if err != nil {
		return errors.Errorf("failed to setup aliases: %s", err)
	}

	_, err = fmt.Fprintln(f, "alias h='helm --kubeconfig /etc/rancher/k3s/k3s.yaml'")
	if err != nil {
		return errors.Errorf("failed to setup aliases: %s", err)
	}

	return nil
}
