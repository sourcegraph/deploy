package main

import (
	"context"
	"log"
	"log/syslog"
)

var (
	version = "latest"
	sgversion = "v5.0.4"
)

func main() {
	sysLog, err := syslog.New(syslog.LOG_INFO|syslog.LOG_LOCAL7, "sg-install")
	if err != nil {
		log.Fatal(err)
	}

	err = run(context.Background(), sysLog)
	if err != nil {
		log.Fatal(err)
	}
}

func run(ctx context.Context, logger *syslog.Writer) error {
	logger.Info("starting Sourcegraph install")

	err := ExecuteWithContext(ctx)
	if err != nil {
		return err
	}

	return nil
}
