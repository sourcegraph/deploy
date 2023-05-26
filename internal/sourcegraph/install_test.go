package sourcegraph

import (
	"context"
	"os"
	"testing"
)

func TestHelmInstall(t *testing.T) {
	err := HelmInstall(context.Background())
	if err != nil {
		t.Fatalf("test failed %s", err)
	}
}

func TestUnpackK8sConfigs(t *testing.T) {
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
