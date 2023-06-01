package main

import (
	"context"
	"os"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/journald"
	"github.com/sourcegraph/conc/iter"
	"github.com/sourcegraph/deploy/internal/image"
	"github.com/sourcegraph/deploy/internal/k3s"
	"github.com/sourcegraph/deploy/internal/system/distro"
	"github.com/sourcegraph/deploy/internal/system/service"
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
}

func run(ctx context.Context, logger *zerolog.Logger) error {
	logger.Info().Str("version", version).Str("sgversion", sgversion).Msg("starting sourcegraph init")

	err := initialSetup(ctx, logger)
	if err != nil {
		logger.Error().Err(err).Msg("initial setup failed")
		return err
	}

	return nil
}

func initialSetup(ctx context.Context, logger *zerolog.Logger) error {

	logger.Info().Msg("checking k3s.service status")
	running, err := service.IsRunning(ctx, "k3s.service")
	if err != nil {
		logger.Error().Err(err).Msg("failed to get k3s.service status")
		return err
	}

	if !running {
		logger.Info().Msg("k3s.service not running, attempting to start k3s.service")
		err := service.Start(ctx, "k3s.service")
		if err != nil {
			logger.Error().Err(err).Msg("failed to start k3s.service")
			return err
		}
	}

	if distro.IsAmazonLinux() {
		logger.Info().Msg("detected amazon linux")

		logger.Info().Msg("starting k3s configuration setup")
		err = k3s.Configure("ec2-user")
		if err != nil {
			logger.Error().Err(err).Msg("failed to configure k3s for user")
			return err
		}
	}

	logger.Info().Msg("loading sourcegraph images to containerd")
	iter.ForEach(image.Images(), func(img *string) {
		err = image.SaveLoad(ctx, *img)
		if err != nil {
			logger.Error().Err(err).Msgf("failed to load image: %s", img)
		}
	})

	return nil
}
