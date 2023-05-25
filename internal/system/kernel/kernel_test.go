package kernel

import (
	"bufio"
	"context"
	"os"
	"testing"
)

func TestSetInotifyMaxUserWatches(t *testing.T) {
	err := SetInotifyMaxUserWatches(context.Background(), 10000)
	if err != nil {
		t.Errorf("SetInotifyMaxUserWatches error: %v", err)
	}

	f, err := os.Open("/etc/sysctl.conf")
	if err != nil {
		t.Errorf("SetInotifyMaxUserWatches error: %v", err)
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)

	var found bool
	for scanner.Scan() {
		line := scanner.Text()
		if line == "fs.inotify.max_user_watches=10000" {
			found = true
		}
	}

	if !found {
		t.Fatalf("SetInotifyMaxUserWatches not set")
	}
}

func TestSetVmMaxMapCount(t *testing.T) {
	err := SetVmMaxMapCount(context.Background(), 10000)
	if err != nil {
		t.Errorf("SetInotifyMaxUserWatches error: %v", err)
	}

	f, err := os.Open("/etc/sysctl.conf")
	if err != nil {
		t.Errorf("SetVmMaxMapCount error: %v", err)
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)

	var found bool
	for scanner.Scan() {
		line := scanner.Text()
		if line == "vm.max_map_count=10000" {
			found = true
		}
	}

	if !found {
		t.Fatalf("SetVmMaxMapCount not set")
	}
}

func TestSetSoftNProc(t *testing.T) {
	err := SetSoftNProc(100000)
	if err != nil {
		t.Errorf("SetSoftNProc error: %v", err)
	}

	f, err := os.Open("/etc/security/limits.conf")
	if err != nil {
		t.Errorf("SetSoftNProc error: %v", err)
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)

	var found bool
	for scanner.Scan() {
		line := scanner.Text()
		if line == "* soft nproc 100000" {
			found = true
		}
	}

	if !found {
		t.Fatalf("SetSoftNProc not set")
	}
}

func TestSetHardNProc(t *testing.T) {
	err := SetHardNProc(100000)
	if err != nil {
		t.Errorf("SetHardNProc error: %v", err)
	}

	f, err := os.Open("/etc/security/limits.conf")
	if err != nil {
		t.Errorf("SetHardNProc error: %v", err)
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)

	var found bool
	for scanner.Scan() {
		line := scanner.Text()
		if line == "* hard nproc 100000" {
			found = true
		}
	}

	if !found {
		t.Fatalf("SetHardNProc not set")
	}
}

func TestSetSoftNoFile(t *testing.T) {
	err := SetSoftNoFile(100000)
	if err != nil {
		t.Errorf("SetSoftNoFile error: %v", err)
	}

	f, err := os.Open("/etc/security/limits.conf")
	if err != nil {
		t.Errorf("SetSoftNoFile error: %v", err)
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)

	var found bool
	for scanner.Scan() {
		line := scanner.Text()
		if line == "* soft nofile 100000" {
			found = true
		}
	}

	if !found {
		t.Fatalf("SetSoftNoFile not set")
	}
}

func TestSetHardNoFile(t *testing.T) {
	err := SetHardNoFile(100000)
	if err != nil {
		t.Errorf("SetHardNoFile error: %v", err)
	}

	f, err := os.Open("/etc/security/limits.conf")
	if err != nil {
		t.Errorf("SetHardNoFile error: %v", err)
	}
	defer func() {
		_ = f.Close()
	}()

	scanner := bufio.NewScanner(f)

	var found bool
	for scanner.Scan() {
		line := scanner.Text()
		if line == "* hard nofile 100000" {
			found = true
		}
	}

	if !found {
		t.Fatalf("SetHardNoFile not set")
	}
}
