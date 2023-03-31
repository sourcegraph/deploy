package main

import (
	"context"

	"github.com/spf13/cobra"
)

var (
	aws     bool
	gcp     bool
	azr     bool
	offline bool
	version string

	rootCmd = &cobra.Command{
		Use:   "sg-install",
		Short: "Sourcegraph installer",
		Long:  "",
		Run:   nil,
	}
)

func ExecuteWithContext(ctx context.Context) error {
	return rootCmd.ExecuteContext(ctx)
}

func init() {
	cobra.OnInitialize(initConfig)

	rootCmd.PersistentFlags().BoolVarP(&aws, "aws", "a", false, "")
	rootCmd.PersistentFlags().BoolVarP(&gcp, "gcp", "g", false, "")
	rootCmd.PersistentFlags().BoolVarP(&azr, "azr", "z", false, "")
	rootCmd.MarkFlagsMutuallyExclusive("aws", "gcp", "azr")
	rootCmd.PersistentFlags().BoolVarP(&offline, "offline", "o", false, "")
	rootCmd.PersistentFlags().StringVarP(&version, "version", "v", "", "")
}

func initConfig() {
}
