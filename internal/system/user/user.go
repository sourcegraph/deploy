// Package user provides functions for interacting with users.
package user

import (
	"bufio"
	"context"
	"os"
	"os/exec"
	"strings"

	"github.com/sourcegraph/sourcegraph/lib/errors"
)

// Create creates a new user with the given username.
func Create(ctx context.Context, username string) error {
	cmd := exec.CommandContext(ctx, "useradd", "-m", "-s", "/bin/bash", username)
	err := cmd.Run()
	if err != nil {
		return errors.Newf("failed to create user %s: %v", username, err)
	}

	return nil
}

// Exists checks if a given user already exists.
func Exists(username string) (bool, error) {
	file, err := os.Open("/etc/passwd")
	if err != nil {
		return false, errors.Newf("failed to check for existing user %s: %v", username, err)
	}
	defer func() {
		_ = file.Close()
	}()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Split(line, ":")
		if len(parts) >= 1 && parts[0] == username {
			return true, nil
		}
	}

	return false, nil
}
