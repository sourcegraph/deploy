package main

import (
	"context"
	"os"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/journald"
	"github.com/sourcegraph/deploy/internal/sourcegraph"
)

var (
	version   = "latest"
	sgversion = "v5.0.4"
)

func main() {
	w := journald.NewJournalDWriter()
	logger := zerolog.New(w).With().Caller().Logger()
	ctx := context.Background()

	if err := run(ctx, &logger); err != nil {
		os.Exit(1)
	}

	//TODO create go routine for listen for os sigs and react.
}

func run(ctx context.Context, logger *zerolog.Logger) error {
	logger.Info().Str("version", version).Str("sgversion", sgversion).Msg("starting sourcegraphd")

	logger.Info().Msg("check for existing sourcegraph installation")
	installed, err := sourcegraph.IsInstalled("sourcegraph")
	if err != nil {
		logger.Error().Err(err).Msg("failed to check for existing sourcegraph install")
		return err
	}

	if !installed {
		logger.Info().Msg("no existing install found, starting initial setup")
		err := initialSetup(ctx)
		if err != nil {
			logger.Error().Err(err).Msg("failed to run initial setup")
			return err
		}
	}

	logger.Info().Msg("sourcegraph installed")

	logger.Info().Msg("running update check process")
	update, err := sourcegraph.CheckUpdate()
	if err != nil {
		logger.Error().Err(err).Msg("failed to run update check process")
		return err
	}

	if update {
		logger.Info().Msg("updated needed, running update process")
		err := sourcegraph.HelmUpgrade()
		if err != nil {
			logger.Error().Err(err).Msg("failed to run update process")
			return err
		}
	}

	return nil
}
