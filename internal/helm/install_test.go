package helm

import (
	"os"
	"testing"
)

func TestInstall(t *testing.T) {
	err := Install()
	if err != nil {
		t.Fatalf("test failed %v", err)
	}

	_, err = os.Stat("/usr/local/bin/helm")
	if err != nil {
		t.Fatalf("test failed %s", err)
	}
}
