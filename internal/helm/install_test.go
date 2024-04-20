package helm

import (
	"flag"
	"os"
	"testing"
)

var integration = flag.Bool("integration", false, "run integration style install tests")

func TestInstall(t *testing.T) {
	if !*integration {
		t.Skip("skipping helm 'TestInstall' integration test...")
	}

	err := Install()
	if err != nil {
		t.Fatalf("test failed %v", err)
	}

	_, err = os.Stat("/usr/local/bin/helm")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}
}
