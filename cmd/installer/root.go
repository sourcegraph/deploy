package main

import (
	"context"

	"github.com/spf13/cobra"
)

var (
	rootCmd = &cobra.Command{
		Use:   "sg-install",
		Short: "Sourcegraph installer",
		Long:  "",
	}
)

func ExecuteWithContext(ctx context.Context) error {
	return rootCmd.ExecuteContext(ctx)
}
