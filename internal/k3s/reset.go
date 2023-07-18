package k3s

import (
	"context"
	"os"
	"os/exec"
)

// Reset will stop and reset the state of the k3s installation.
func Reset(ctx context.Context) error {
	if err := killall(ctx); err != nil {
		return err
	}

	if err := cleanup(); err != nil {
		return err
	}

	return nil
}

// killall stops all k3s containers and resets the containerd state.
func killall(ctx context.Context) error {
	if err := exec.CommandContext(ctx, "/usr/local/bin/k3s-killall.sh").Run(); err != nil {
		return err
	}

	return nil
}

// cleanup removes left over TLS certs and creds that will cause k3s to not reboot on a new system.
func cleanup() error {
	if err := os.RemoveAll("/var/lib/rancher/k3s/server/cred"); err != nil {
		return err
	}

	if err := os.RemoveAll("/var/lib/rancher/k3s/server/tls"); err != nil {
		return err
	}

	return nil
}
