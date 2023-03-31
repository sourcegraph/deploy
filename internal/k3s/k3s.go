package k3s

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"strconv"

	"github.com/sourcegraph/sourcegraph/lib/errors"
)

type Options struct {
	Version string
	SELinux bool
}

type Option = func(option *Options)

// Version sets a specific version to install.
func Version(version string) Option {
	// TODO validate and sanity check version input
	return func(option *Options) {
		option.Version = version
	}
}

// EnableSELinux will enable SELinux support in the installation.
func EnableSELinux() Option {
	return func(option *Options) {
		option.SELinux = true
	}
}

// Install will install K3s.
func Install(ctx context.Context, opts ...Option) error {
	options := Options{
		Version: "",
		SELinux: false,
	}

	for _, opt := range opts {
		opt(&options)
	}

	resp, err := http.Get("https://get.k3s.io")
	if err != nil {
		return errors.Newf("failed to install k3s: %v", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	if resp.StatusCode != http.StatusOK {
		return errors.Newf("failed to install k3s: %v", err)
	}

	script, err := io.ReadAll(resp.Body)
	if err != nil {
		return errors.Newf("failed to install k3s: %v", err)
	}

	tmpFile, err := os.CreateTemp("", "k3s-install-*.sh")
	if err != nil {
		return errors.Newf("failed to install k3s: %v", err)
	}
	defer func() {
		_ = os.Remove(tmpFile.Name())
	}()

	_, err = tmpFile.Write(script)
	if err != nil {
		return errors.Newf("failed to install k3s: %v", err)
	}

	err = tmpFile.Close()
	if err != nil {
		return errors.Newf("failed to install k3s: %v", err)
	}

	err = os.Chmod(tmpFile.Name(), 0755)
	if err != nil {
		return errors.Newf("failed to install k3s: %v", err)
	}

	cmd := exec.CommandContext(ctx, "/bin/sh", tmpFile.Name(),
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
	)
	if options.SELinux {
		cmd.Args = append(cmd.Args, "--selinux")
	}
	if options.Version != "" {
		cmd.Env = append(cmd.Env, fmt.Sprintf("INSTALL_K3S_VERSION=%s", options.Version))
	}
	err = cmd.Run()
	if err != nil {
		return errors.Newf("failed to install k3s: %v", err)
	}

	err = setupConfigPerms()
	if err != nil {
		return err
	}

	err = setupKubeConfig()
	if err != nil {
		return err
	}

	// TODO check where the alias should be set
	err = setupAliases("/home/sourcegraph/.bash_profile")
	if err != nil {
		return err
	}

	return nil
}

// setupConfigPerms setups up the proper file permissions for the k3s config file.
func setupConfigPerms() error {
	configPath := "/etc/rancher/k3s/k3s.yaml"
	fileInfo, err := os.Stat(configPath)
	if err != nil {
		return errors.Newf("failed to setup k3s config file: %v", err)
	}

	user, err := user.Lookup("sourcegraph")
	if err != nil {
		return errors.Newf("failed to setup k3s config file: %v", err)
	}

	uid, _ := strconv.Atoi(user.Uid)
	gid, _ := strconv.Atoi(user.Gid)

	err = os.Chown(configPath, uid, gid)
	if err != nil {
		return errors.Newf("failed to setup k3s config file: %v", err)
	}

	currentPermissions := fileInfo.Mode()
	// remove read permissions for the group (4) and others (32)
	newPermissions := currentPermissions &^ (os.FileMode(4) | os.FileMode(32))

	err = os.Chmod(configPath, newPermissions)
	if err != nil {
		return errors.Newf("failed to setup k3s config file: %v", err)
	}

	return nil
}

func setupKubeConfig() error {
	source, err := os.Open("/etc/rancher/k3s/k3s.yaml")
	if err != nil {
		return errors.Newf("failed to setup kube config file: %v", err)
	}
	defer func() {
		_ = source.Close()
	}()

	destination, err := os.Create("/home/sourcegraph/.kube/config")
	if err != nil {
		return errors.Newf("failed to setup kube config file: %v", err)
	}
	defer func() {
		_ = destination.Close()
	}()

	_, err = io.Copy(destination, source)
	if err != nil {
		return errors.Newf("failed to setup kube config file: %v", err)
	}

	return nil
}

// setupAliases setups up common shell alias for k8s and helm.
func setupAliases(path string) error {
	f, err := os.OpenFile(path, os.O_RDWR|os.O_APPEND|os.O_CREATE, 0664)
	if err != nil {
		return errors.Newf("failed to setup aliases: %v", err)
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprint(f, "KUBECONFIG=/etc/rancher/k3s/k3s.yaml")
	if err != nil {
		return errors.Newf("failed to setup aliases: %v", err)
	}

	_, err = fmt.Fprint(f, "alias k='kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml'")
	if err != nil {
		return errors.Newf("failed to setup aliases: %v", err)
	}

	_, err = fmt.Fprint(f, "alias h='helm --kubeconfig /etc/rancher/k3s/k3s.yaml'")
	if err != nil {
		return errors.Newf("failed to setup aliases: %v", err)
	}

	return nil
}
