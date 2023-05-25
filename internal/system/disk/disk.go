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

// Disk contains information about the specific disk.
//
// Fields:
//
//	Path - Absolute path where the directory is mounted
//	FilesystemType - Type of the filesystem, e.g. "xfs"
//	Device - Device for the disk (empty string if none is found)
//	DeviceNumber - Device number of the disk.
type Disk struct {
	Path           string
	FilesystemType string
	Device         string
	DeviceNumber   uint64
}

func (d *Disk) Setup() error {
	// create directory for mountpoint
	err := os.MkdirAll(d.Path, 0775)
	if err != nil {
		return err
	}

	return nil
}

// IsMounted checks if a disk is mounted at the given path.
func (d *Disk) IsMounted() (bool, error) {
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
		if strings.Contains(line, d.Path) && strings.Contains(line, d.Device) {
			return true, nil
		}
	}

	return false, nil
}

// GetFileSystemType gets the filesystem type of the disk device.
func (d *Disk) GetFileSystemType(ctx context.Context) (string, error) {
	_, err := exec.LookPath("blkid")
	if err != nil {
		return "", errors.Errorf("failed to get device file system type: %s", err)
	}

	out, err := exec.CommandContext(ctx, "blkid", "-s", "TYPE", "-o", "value", d.Device).Output()
	if err != nil {
		return "", errors.Errorf("failed to get device file system type: %s", err)
	}

	return strings.TrimSpace(string(out)), nil
}

// Mount mounts the disk device at the given path.
func (d *Disk) Mount(ctx context.Context) error {
	err := exec.CommandContext(ctx, "mount", d.Device, d.Path).Run()
	if err != nil {
		return errors.Errorf("failed to mount device %s: %s", d.Device, err)
	}

	return nil
}

func (d *Disk) createXFSFilesystem(ctx context.Context) error {
	_, err := exec.LookPath("mkfs.xfs")
	if err != nil {
		return errors.Errorf("failed to create XFS filesystem: %s", err)
	}

	err = exec.CommandContext(ctx, "mkfs.xfs", d.Device).Run()
	if err != nil {
		return errors.Errorf("failed to create XFS filesystem: %s", err)
	}

	_, err = exec.LookPath("xfs_admin")
	if err != nil {
		return errors.Errorf("failed to create XFS filesystem: %s", err)
	}

	// Add label to volume device
	err = exec.CommandContext(ctx, "xfs_admin", "-L", d.Path, d.Device).Run()
	if err != nil {
		return errors.Errorf("failed to create XFS filesystem: %s", err)
	}

	return nil
}

func (d *Disk) createEXT4Filesystem(ctx context.Context) error {
	_, err := exec.LookPath("mkfs.ext4")
	if err != nil {
		return errors.Errorf("failed to create EXT4 filesystem: %s", err)
	}

	err = exec.CommandContext(ctx, "mkfs.ext4", "-m", "0", "-E", "lazy_itable_init=0,lazy_journal_init=0,discard", d.Device).Run()
	if err != nil {
		return errors.Errorf("failed to create EXT4 filesystem: %s", err)
	}

	_, err = exec.LookPath("e2label")
	if err != nil {
		return errors.Errorf("failed to create EXT4 filesystem: %s", err)
	}

	// Add label to volume device
	err = exec.CommandContext(ctx, "e2label", d.Device, d.Path).Run()
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
