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

	err := run(context.Background())
	if err != nil {
		log.Fatal(err)
	}
}

func run(ctx context.Context) error {
	err := ExecuteWithContext(ctx)
	if err != nil {
		return err
	}

	return nil
}
