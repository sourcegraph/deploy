package main

import (
	"context"
	"log"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/journald"
)

var (
	version   = "latest"
	sgversion = "v5.0.4"
)

func main() {
	w := journald.NewJournalDWriter()
	logger := zerolog.New(w).With().Caller().Logger()

	err := run(context.Background(), &logger)
	if err != nil {
		log.Fatal(err)
	}
}

func run(ctx context.Context, logger *zerolog.Logger) error {
	logger.Info().Str("verson", version).Str("sgversion", sgversion).Msg("starting sourcegraph installer")

	err := ExecuteWithContext(ctx)
	if err != nil {
		return err
	}

	return nil
}
