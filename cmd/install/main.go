package main

import (
	"context"
	"embed"
	"log"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/journald"
)

//go:embed bin
var embeddedFS embed.FS

var (
	version   = "latest"
	sgversion = "v5.0.4"
	logger    = zerolog.Logger{}
)

func main() {
	w := journald.NewJournalDWriter()
	logger = zerolog.New(w).With().Caller().Logger()

	if err := run(context.Background()); err != nil {
		log.Fatal(err)
	}
}

func run(ctx context.Context) error {
	if err := ExecuteWithContext(ctx); err != nil {
		return err
	}

	return nil
}
