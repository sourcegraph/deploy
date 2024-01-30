package containerd

import (
	"context"
	"os/exec"

	"github.com/sourcegraph/deploy/internal/system/distro"
	"github.com/sourcegraph/deploy/internal/system/service"
)

func Install(ctx context.Context) error {
	if distro.IsAmazonLinux() {
		cmd := exec.CommandContext(ctx, "dnf", "install", "containerd", "nerdctl", "-y")
		err := cmd.Run()
		if err != nil {
			return err
		}
	}

	err := service.Enable(ctx, "containerd.service")
	if err != nil {
		return err
	}

	err = service.Start(ctx, "containerd.service")
	if err != nil {
		return err
	}

	return nil
}
