// Package os provides functions for interacting with and querying an operating system.
package os

import (
	"bufio"
	"os"
	"strings"

	"github.com/opencontainers/selinux/go-selinux"
)

// IsAmazonLinux checks if the current Linux distro is Amazon Linux.
func IsAmazonLinux() (bool, error) {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false, err
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "amzn") {
			return true, nil
		}
	}

	return false, nil
}

// IsRHELinux checks if the current Linux distro is RedHat Enterprise Linux.
func IsRHELinux() (bool, error) {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false, err
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "rhel") {
			return true, nil
		}
	}

	return false, nil
}

// IsFedoraLinux checks if the current Linux distro is Fedora Linux.
func IsFedoraLinux() (bool, error) {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false, err
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "fedora") {
			return true, nil
		}
	}

	return false, nil
}

// IsDebianLinux checks if the current Linux distro is Debian Linux.
func IsDebianLinux() (bool, error) {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false, err
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "debian") {
			return true, nil
		}
	}

	return false, nil
}

// IsUbuntuLinux checks if the current Linux distro is Ubuntu Linux.
func IsUbuntuLinux() (bool, error) {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false, err
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "ubuntu") {
			return true, nil
		}
	}

	return false, nil
}

// IsSELinuxEnabled check if SELinux is enabled and either in Enforcing (1) or Permissive (0) mode.
func IsSELinuxEnabled() bool {
	if selinux.GetEnabled() {
		if selinux.EnforceMode() == 1 || selinux.EnforceMode() == 0 {
			return true
		}
	}

	return false
}
