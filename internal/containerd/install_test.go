package containerd

import (
	"context"
	"flag"
	"os/exec"
	"testing"
)

var integration = flag.Bool("integration", false, "run integration style tests")

func TestInstall(t *testing.T) {
	if !*integration {
		t.Skip("skipping containerd 'TestInstall' integration test...")
	}

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
