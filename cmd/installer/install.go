package main

import (
	"github.com/sourcegraph/deploy/internal/containerd"
	"github.com/sourcegraph/deploy/internal/helm"
	"github.com/sourcegraph/deploy/internal/image"
	"github.com/sourcegraph/deploy/internal/k3s"
	"github.com/sourcegraph/deploy/internal/sourcegraph"
	"github.com/spf13/cobra"
)

var installCmd = &cobra.Command{
	Use:   "install",
	Short: "installs sourcegraph",
	RunE:  install,
}

func init() {
	rootCmd.AddCommand(installCmd)
}

func install(cmd *cobra.Command, args []string) error {
	err := containerd.Install(cmd.Context())
	if err != nil {
		return err
	}

	for _, i := range image.Images() {
		err = image.Pull(cmd.Context(), i)
		if err != nil {
			return err
		}
	}

	err = k3s.Install(cmd.Context())
	if err != nil {
		return err
	}

	err = helm.Install()
	if err != nil {
		return err
	}

	err = sourcegraph.UnpackK8sConfigs()
	if err != nil {
		return err
	}

	return nil
}
