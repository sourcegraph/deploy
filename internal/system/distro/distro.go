// Package distro provides functions for determining the distribution of a Linux system.
package distro

import (
	"bufio"
	"os"
	"strings"

	"github.com/opencontainers/selinux/go-selinux"
)

// IsAmazonLinux checks if the current Linux distro is Amazon Linux.
func IsAmazonLinux() bool {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "amzn") {
			return true
		}
	}

	return false
}

// IsRHELinux checks if the current Linux distro is RedHat Enterprise Linux.
func IsRHELinux() bool {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "rhel") {
			return true
		}
	}

	return false
}

// IsFedoraLinux checks if the current Linux distro is Fedora Linux.
func IsFedoraLinux() bool {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "fedora") {
			return true
		}
	}

	return false
}

// IsDebianLinux checks if the current Linux distro is Debian Linux.
func IsDebianLinux() bool {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "debian") {
			return true
		}
	}

	return false
}

// IsUbuntuLinux checks if the current Linux distro is Ubuntu Linux.
func IsUbuntuLinux() bool {
	f, err := os.Open("/etc/os-release")
	if err != nil {
		return false
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, "ubuntu") {
			return true
		}
	}

	return false
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
