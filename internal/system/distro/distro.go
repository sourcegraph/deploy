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
	return isDistro("amzn")
}

// IsRHELinux checks if the current Linux distro is RedHat Enterprise Linux.
func IsRHELinux() bool {
	return isDistro("rhel")
}

// IsFedoraLinux checks if the current Linux distro is Fedora Linux.
func IsFedoraLinux() bool {
	return isDistro("fedora")
}

// IsDebianLinux checks if the current Linux distro is Debian Linux.
func IsDebianLinux() bool {
	return isDistro("debian")
}

// IsUbuntuLinux checks if the current Linux distro is Ubuntu Linux.
func IsUbuntuLinux() bool {
	return isDistro("ubuntu")
}

func isDistro(distro string) bool {
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
		if strings.HasPrefix(line, "ID=") && strings.Contains(line, distro) {
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
