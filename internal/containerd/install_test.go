package containerd

import (
	"context"
	"os/exec"
	"testing"
)

func TestInstall(t *testing.T) {
	err := Install(context.Background())
	if err != nil {
		t.Fatalf("failed to install containerd: %s", err)
	}

	_, err = exec.LookPath("nerdctl")
	if err != nil {
		t.Fatalf("failed to install containerd: %s", err)
	}

	_, err = exec.LookPath("containerd")
	if err != nil {
		t.Fatalf("failed to install containerd: %s", err)
	}

}
