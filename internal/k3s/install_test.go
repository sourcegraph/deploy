package k3s

import (
	"context"
	"os"
	"testing"

	"github.com/sourcegraph/deploy/internal/system/distro"
)

func TestInstall(t *testing.T) {
	err := Install(context.Background())
	if err != nil {
		t.Fatalf("test failed %s", err)
	}

	// check offline images are in place
	_, err = os.Stat("/var/lib/rancher/k3s/agent/images/k3s-airgap-images-amd64.tar")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}

	// check k3s binary is in place
	_, err = os.Stat("/usr/local/bin/k3s")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}

	_, err = os.Stat("/etc/rancher/k3s")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}
}

func TestConfigure(t *testing.T) {
	if distro.IsAmazonLinux() {
		err := Configure("ec2-user")
		if err != nil {
			t.Fatalf("test failed %s", err)
		}
	}

	_, err := os.Stat("/etc/rancher/k3s/k3s.yaml")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}
}
