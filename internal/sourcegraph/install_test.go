package sourcegraph

import (
	"context"
	"flag"
	"os"
	"testing"
)

var integration = flag.Bool("integration", false, "run integration style tests")

func TestHelmInstall(t *testing.T) {
	if !*integration {
		t.Skip("skipping sourcegraph 'TestHelmInstall' integration test...")
	}

	err := Install(context.Background())
	if err != nil {
		t.Fatalf("test failed %s", err)
	}
}

func TestUnpackK8sConfigs(t *testing.T) {
	if !*integration {
		t.Skip("skipping sourcegraph 'TestUnpackK8sConfigs' integration test...")
	}

	err := UnpackK8sConfigs()
	if err != nil {
		t.Fatalf("test failed %s", err)
	}

	_, err = os.Stat("/usr/share/sourcegraph")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}

	_, err = os.Stat("/usr/share/sourcegraph/ingress.yaml")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}

	_, err = os.Stat("/usr/share/sourcegraph/prometheus-override.ConfigMap.yaml")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}
}
