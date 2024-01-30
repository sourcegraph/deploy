package helm

import (
	"embed"
	"os"

	"github.com/sourcegraph/sourcegraph/lib/errors"
)

// The Helm binary is embedded into the binary at build and pinned to a specific version.
// This allows an offline first approach to the installation as well as guarantees about
// the version of Helm that we use for our deployments.
//
//go:embed bin
var embeddedFS embed.FS

// Install will install Helm.
func Install() error {
	helm, err := embeddedFS.ReadFile("bin/helm")
	if err != nil {
		return errors.Errorf("failed to install helm: %s", err)
	}

	unpackedHelm, err := os.OpenFile("/usr/local/bin/helm", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return errors.Errorf("failed to install helm: %s", err)
	}
	defer func() {
		_ = unpackedHelm.Close()
	}()

	_, err = unpackedHelm.Write(helm)
	if err != nil {
		return errors.Errorf("failed to install helm: %s", err)
	}

	return nil
}
