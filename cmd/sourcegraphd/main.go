package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

var (
	version   = "latest"
	sgversion = "v5.0.4"
)

func main() {
	ctx := context.Background()

	if err := run(ctx); err != nil {
		os.Exit(1)
	}

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGHUP)

	defer func() {
		signal.Stop(sigChan)
	}()

	//TODO create go routine for listen for os sigs and react.
}

func run(ctx context.Context) error {

	// TODO: check for existing install
	err := initialSetup(ctx)
	if err != nil {
		fmt.Println(err)
		return err
	}

	return nil
}
