package main

import (
	"context"

	"github.com/sourcegraph/deploy/internal/sourcegraph"
)

func initialSetup(ctx context.Context) error {
	err := sourcegraph.HelmInstall(ctx)
	if err != nil {
		return err
	}

	return nil
}
