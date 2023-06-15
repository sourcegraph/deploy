package k3s

import (
	"context"
	"os"
	"os/exec"
)

// Reset will stop and reset the state of the k3s installation.
func Reset(ctx context.Context) error {
	err := killall(ctx)
	if err != nil {
		return err
	}

	err = cleanup()
	if err != nil {
		return err
	}

	return nil
}

// killall stops all k3s containers and resets the containerd state.
func killall(ctx context.Context) error {
	err := exec.CommandContext(ctx, "/usr/local/bin/k3s-killall.sh").Run()
	if err != nil {
		return err
	}

	return nil
}

// cleanup removes left over TLS certs and creds that will cause k3s to not reboot on a new system.
func cleanup() error {
	err := os.RemoveAll("/var/lib/rancher/k3s/server/cred")
	if err != nil {
		return err
	}

	err = os.RemoveAll("/var/lib/rancher/k3s/server/tls")
	if err != nil {
		return err
	}

	return nil
}
