// Package disk provides functions for interacting disks.
package disk

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/sourcegraph/sourcegraph/lib/errors"
)

const (
	XFS Filesystem = iota
	EXT4
)

type Option = func(disk *disk)

type Filesystem int

type disk struct {
	mount        bool
	path         string
	filesystem   Filesystem
	device       string
	deviceNumber uint64
}

func (f Filesystem) String() string {
	switch f {
	case XFS:
		return "xfs"
	case EXT4:
		return "ext4"
	}
	return ""
}

// NewDisk will create a new disk with the given values and options.
func NewDisk(ctx context.Context, path, device string, filesystem Filesystem, opts ...Option) error {
	dsk := disk{
		path:       path,
		device:     device,
		filesystem: filesystem,
	}

	for _, option := range opts {
		option(&dsk)
	}

	switch dsk.filesystem {
	case XFS:
		err := dsk.createXFSFilesystem(ctx)
		if err != nil {
			return err
		}
		err = updateFStab("LABEL=/mnt/data  /mnt/data  xfs  discard,defaults,nofail  0  2")
		if err != nil {
			return err
		}
	case EXT4:
		err := dsk.createEXT4Filesystem(ctx)
		if err != nil {
			return err
		}
		err = updateFStab("LABEL=/mnt/data  /mnt/data  ext4  discard,defaults,nofail  0  2")
		if err != nil {
			return err
		}
	}

	if dsk.mount {
		err := dsk.mountDisk(ctx)
		if err != nil {
			return err
		}
	}

	return nil
}

// Mount will optionally mount the new disk
func Mount() Option {
	return func(disk *disk) {
		disk.mount = true
	}
}

// IsMounted checks if a disk is mounted at the given path.
func IsMounted(path, device string) (bool, error) {
	file, err := os.Open("/etc/mtab")
	if err != nil {
		return false, err
	}
	defer func() {
		_ = file.Close()
	}()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, path) && strings.Contains(line, device) {
			return true, nil
		}
	}

	return false, nil
}

func (d *disk) mountDisk(ctx context.Context) error {
	err := os.MkdirAll(d.path, 0775)
	if err != nil {
		return err
	}

	err = exec.CommandContext(ctx, "mount", d.device, d.path).Run()
	if err != nil {
		return errors.Errorf("failed to mount device %s: %s", d.device, err)
	}

	return nil
}

func (d *disk) createXFSFilesystem(ctx context.Context) error {
	_, err := exec.LookPath("mkfs.xfs")
	if err != nil {
		return errors.Errorf("failed to create XFS filesystem: %s", err)
	}

	err = exec.CommandContext(ctx, "mkfs.xfs", d.device).Run()
	if err != nil {
		return errors.Errorf("failed to create XFS filesystem: %s", err)
	}

	_, err = exec.LookPath("xfs_admin")
	if err != nil {
		return errors.Errorf("failed to create XFS filesystem: %s", err)
	}

	// Add label to volume device
	err = exec.CommandContext(ctx, "xfs_admin", "-L", d.path, d.device).Run()
	if err != nil {
		return errors.Errorf("failed to create XFS filesystem: %s", err)
	}

	return nil
}

func (d *disk) createEXT4Filesystem(ctx context.Context) error {
	_, err := exec.LookPath("mkfs.ext4")
	if err != nil {
		return errors.Errorf("failed to create EXT4 filesystem: %s", err)
	}

	err = exec.CommandContext(ctx, "mkfs.ext4", "-m", "0", "-E", "lazy_itable_init=0,lazy_journal_init=0,discard", d.device).Run()
	if err != nil {
		return errors.Errorf("failed to create EXT4 filesystem: %s", err)
	}

	_, err = exec.LookPath("e2label")
	if err != nil {
		return errors.Errorf("failed to create EXT4 filesystem: %s", err)
	}

	// Add label to volume device
	err = exec.CommandContext(ctx, "e2label", d.device, d.path).Run()
	if err != nil {
		return errors.Errorf("failed to create EXT4 filesystem: %s", err)
	}

	return nil
}

func updateFStab(mountOpts string) error {
	f, err := os.OpenFile("/etc/fstab", os.O_RDWR|os.O_APPEND, 0644)
	if err != nil {
		return errors.Errorf("failed to update /etc/fstab: %s", err)
	}
	defer func() {
		_ = f.Close()
	}()

	_, err = fmt.Fprintln(f, mountOpts)
	if err != nil {
		return errors.Errorf("failed to update /etc/fstab: %s", err)
	}

	return nil
}
