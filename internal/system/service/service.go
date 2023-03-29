// Package service provides functions for interacting with systemd units.
package service

import (
	"context"
	"strings"

	"github.com/coreos/go-systemd/v22/dbus"

	"github.com/sourcegraph/sourcegraph/lib/errors"
)

// IsRunning checks if the systemd unit with the given name is running.
//
// Parameters:
//
//	ctx (context.Context): The context for the operation.
//	unit (string): The name of the systemd unit to check.
//
// Returns:
//
//	(bool, error): A boolean indicating if the unit is running, and an error if one occurred.
func IsRunning(ctx context.Context, unit string) (bool, error) {
	if err := validateUnit(unit); err != nil {
		return false, err
	}

	conn, err := dbus.NewSystemdConnectionContext(ctx)
	if err != nil {
		return false, err
	}
	defer conn.Close()

	units, err := conn.ListUnitsByNamesContext(ctx, []string{unit})
	if err != nil {
		return false, err
	}

	u := units[0]
	if u.ActiveState == "active" {
		return true, nil
	}

	return false, nil
}

//  Start starts the systemd unit with the given name.
//
//  Parameters:
//      ctx (context.Context): The context for the operation.
//      unit (string): The name of the systemd unit to start.
//
//  Returns:
//      error: An error if the unit failed to start, or nil if it started successfully.

func Start(ctx context.Context, unit string) error {
	if err := validateUnit(unit); err != nil {
		return err
	}

	if err := validateUnit(unit); err != nil {
		return err
	}

	conn, err := dbus.NewSystemdConnectionContext(ctx)
	if err != nil {
		return err
	}
	defer conn.Close()

	resultChan := make(chan string, 1)

	_, err = conn.StartUnitContext(ctx, unit, "fail", resultChan)
	if err != nil {
		return err
	}

	r := <-resultChan
	switch r {
	case "done":
		return nil
	case "canceled":
		return errors.Errorf("%s failed to start: job has been canceled before it finished execution", unit)
	case "timeout":
		return errors.Errorf("%s failed to start: job timeout was reached", unit)
	case "failed":
		return errors.Errorf("%s failed to start: job failed", unit)
	case "dependency":
		return errors.Errorf("%s failed to start: a job this job has been depending on failed", unit)
	case "skipped":
		return errors.Errorf("%s failed to start: job was skipped because it didn't apply to the units current state", unit)
	default:
		return errors.Errorf("%s failed to start: job hit unknown error: %s", unit, r)
	}
}

// Stop stops the systemd unit with the given name.
//
// Parameters:
//
//	ctx (context.Context): The context for the operation.
//	unit (string): The name of the systemd unit to stop.
//
// Returns:
//
//	error: An error if the unit failed to stop, or nil if it stopped successfully.
func Stop(ctx context.Context, unit string) error {
	if err := validateUnit(unit); err != nil {
		return err
	}

	conn, err := dbus.NewSystemdConnectionContext(ctx)
	if err != nil {
		return err
	}
	defer conn.Close()

	resultChan := make(chan string, 1)

	_, err = conn.StopUnitContext(ctx, unit, "fail", resultChan)
	if err != nil {
		return err
	}

	r := <-resultChan
	switch r {
	case "done":
		return nil
	case "canceled":
		return errors.Errorf("%s failed to stop: job has been canceled before it finished execution", unit)
	case "timeout":
		return errors.Errorf("%s failed to stop: job timeout was reached", unit)
	case "failed":
		return errors.Errorf("%s failed to stop: job failed", unit)
	case "dependency":
		return errors.Errorf("%s failed to stop: a job this job has been depending on failed", unit)
	case "skipped":
		return errors.Errorf("%s failed to stop: job was skipped because it didn't apply to the units current state", unit)
	default:
		return errors.Errorf("%s failed to stop: job hit unknown error: %s", unit, r)
	}
}

// Disable disables the systemd unit with the given name.
//
// Parameters:
//
//	ctx (context.Context): The context for the operation.
//	unit (string): The name of the systemd unit to disable.
//
// Returns:
//
//	error: An error if the unit failed to disable, or nil if it disabled successfully.
func Disable(ctx context.Context, unit string) error {
	if err := validateUnit(unit); err != nil {
		return err
	}

	conn, err := dbus.NewSystemdConnectionContext(ctx)
	if err != nil {
		return err
	}
	defer conn.Close()

	_, err = conn.DisableUnitFilesContext(ctx, []string{unit}, false)
	if err != nil {
		return err
	}

	return nil
}

// Restart restarts the systemd unit with the given name.
//
// Parameters:
//
//	ctx (context.Context): The context for the operation.
//	unit (string): The name of the systemd unit to restart.
//
// Returns:
//
//	error: An error if the unit failed to restart, or nil if it restarted successfully.
func Restart(ctx context.Context, unit string) error {
	if err := validateUnit(unit); err != nil {
		return err
	}

	conn, err := dbus.NewSystemdConnectionContext(ctx)
	if err != nil {
		return err
	}
	defer conn.Close()

	resultChan := make(chan string, 1)

	_, err = conn.RestartUnitContext(ctx, unit, "fail", resultChan)
	if err != nil {
		return err
	}

	r := <-resultChan
	switch r {
	case "done":
		return nil
	case "canceled":
		return errors.Errorf("%s failed to restart: job has been canceled before it finished execution", unit)
	case "timeout":
		return errors.Errorf("%s failed to restart: job timeout was reached", unit)
	case "failed":
		return errors.Errorf("%s failed to restart: job failed", unit)
	case "dependency":
		return errors.Errorf("%s failed to restart: a job this job has been depending on failed", unit)
	case "skipped":
		return errors.Errorf("%s failed to restart: job was skipped because it didn't apply to the units current state", unit)
	default:
		return errors.Errorf("%s failed to restart: job hit unknown error: %s", unit, r)
	}
}

// validateUnit checks that a systemd unit name is valid.
//
// Parameters:
//
//	unit (string): The systemd unit name to validate.
//
// Returns:
//
//	error: An error if the unit name is invalid, or nil if it is valid.
func validateUnit(unit string) error {
	if unit == "" {
		return errors.New("unit name cannot be empty")
	}

	switch {
	case strings.HasSuffix(unit, ".service"):
		return nil
	case strings.HasSuffix(unit, ".socket"):
		return nil
	case strings.HasSuffix(unit, ".device"):
		return nil
	case strings.HasSuffix(unit, ".mount"):
		return nil
	case strings.HasSuffix(unit, ".automount"):
		return nil
	case strings.HasSuffix(unit, ".swap"):
		return nil
	case strings.HasSuffix(unit, ".target"):
		return nil
	case strings.HasSuffix(unit, ".path"):
		return nil
	case strings.HasSuffix(unit, ".timer"):
		return nil
	case strings.HasSuffix(unit, ".snapshot"):
		return nil
	case strings.HasSuffix(unit, ".scope"):
		return nil
	default:
		return errors.Errorf("unit name %s has invalid suffix", unit)
	}
}
