// Package kernel provides functions for setting kernel parameters needed for Sourcegraph.
package kernel

import (
	"context"
	"fmt"
	"os"
	"os/exec"
)

// SetInotifyMaxUserWatches sets user limits on the number of inotify file watches and
// reloads kernel parameters.
func SetInotifyMaxUserWatches(ctx context.Context, limit int32) error {
	f, err := os.OpenFile("/etc/sysctl.conf", os.O_RDWR|os.O_APPEND|os.O_CREATE, 0660)
	if err != nil {
		return err
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprintf(f, "fs.inotify.max_user_watches=%d", limit)
	if err != nil {
		return err
	}

	cmd := exec.CommandContext(ctx, "sysctl", "--system")
	err = cmd.Run()
	if err != nil {
		return err
	}

	return nil
}

// SetVmMaxMapCount sets system limits on mmap counts and reloads kernel parameters.
func SetVmMaxMapCount(ctx context.Context, limit int32) error {
	f, err := os.OpenFile("/etc/sysctl.conf", os.O_RDWR|os.O_APPEND|os.O_CREATE, 0660)
	if err != nil {
		return err
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprintf(f, "vm.max_map_count=%d", limit)
	if err != nil {
		return err
	}

	cmd := exec.CommandContext(ctx, "sysctl", "--system")
	err = cmd.Run()
	if err != nil {
		return err
	}

	return nil
}

// SetSoftNProc sets the soft limit on the number of processes that can be
// created by any user or group.
func SetSoftNProc(limit int32) error {
	f, err := os.OpenFile("/etc/security/limits.conf", os.O_RDWR|os.O_APPEND|os.O_CREATE, 0660)
	if err != nil {
		return err
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprintf(f, "* soft nproc %d", limit)
	if err != nil {
		return err
	}

	return nil
}

// SetHardNProc sets the hard limit on the number of processes that can be
// created by any user or group.
func SetHardNProc(limit int32) error {
	f, err := os.OpenFile("/etc/security/limits.conf", os.O_RDWR|os.O_APPEND|os.O_CREATE, 0660)
	if err != nil {
		return err
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprintf(f, "* hard nproc %d", limit)
	if err != nil {
		return err
	}

	return nil
}

// SetSoftNoFile sets the soft limit on the maximum number of open file descriptors
// that can be used by any user or group on the system.
func SetSoftNoFile(limit int32) error {
	f, err := os.OpenFile("/etc/security/limits.conf", os.O_RDWR|os.O_APPEND|os.O_CREATE, 0660)
	if err != nil {
		return err
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprintf(f, "* soft nofile %d", limit)
	if err != nil {
		return err
	}

	return nil
}

// SetHardNoFile sets the hard limit on the maximum number of open file descriptors
// that can be used by any user or group on the system.
func SetHardNoFile(limit int32) error {
	f, err := os.OpenFile("/etc/security/limits.conf", os.O_RDWR|os.O_APPEND|os.O_CREATE, 0660)
	if err != nil {
		return err
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprintf(f, "* hard nofile %d", limit)
	if err != nil {
		return err
	}

	return nil
}
