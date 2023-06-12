package service

import (
	"context"
	"flag"
	"os/exec"
	"testing"
)

var integration = flag.Bool("integration", false, "run integration style tests")

func checkEnv(t *testing.T) {
	t.Helper()
	// check if systemd is available on the test system
	_, err := exec.LookPath("systemctl")
	if err != nil {
		t.Skipf("skipping systemd based service cases. systemd not found on system.")
	}
}

func TestIsRunning(t *testing.T) {
	if !*integration {
		t.Skip("skipping service 'TestIsRunning' integration test...")
	}

	checkEnv(t)

	cases := []struct {
		name    string
		unit    string
		want    bool
		wantErr bool
	}{
		{
			name:    "valid running service (ssh)",
			unit:    "sshd.service",
			want:    true,
			wantErr: false,
		},
		{
			name:    "valid stopped service",
			unit:    "stopped.service",
			want:    false,
			wantErr: false,
		},
		{
			name:    "invalid unit",
			unit:    "invalid.serce",
			want:    false,
			wantErr: true,
		},
	}
	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			got, err := IsRunning(context.Background(), tt.unit)
			if (err != nil) != tt.wantErr {
				t.Errorf("IsRunning() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if got != tt.want {
				t.Errorf("IsRunning() got = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestDisable(t *testing.T) {
	if !*integration {
		t.Skip("skipping service 'TestDisable' integration test...")
	}

	checkEnv(t)

	cases := []struct {
		name    string
		unit    string
		wantErr bool
	}{
		{
			name:    "valid service (ssh)",
			unit:    "sshd.service",
			wantErr: false,
		},
		{
			name:    "invalid unit",
			unit:    "invalid.service",
			wantErr: true,
		},
	}
	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			if err := Disable(context.Background(), tt.unit); (err != nil) != tt.wantErr {
				t.Errorf("Disable() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}

	// enable any service that may have been disabled
	defer func() {
		for _, test := range cases {
			if test.wantErr != true {
				_ = Enable(context.Background(), test.unit)
			}
		}
	}()
}

func TestEnable(t *testing.T) {
	if !*integration {
		t.Skip("skipping service 'TestEnable' integration test...")
	}

	checkEnv(t)

	cases := []struct {
		name    string
		unit    string
		wantErr bool
	}{
		{
			name:    "valid service (ssh)",
			unit:    "sshd.service",
			wantErr: false,
		},
		{
			name:    "invalid unit",
			unit:    "invalid.service",
			wantErr: true,
		},
	}
	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			if err := Enable(context.Background(), tt.unit); (err != nil) != tt.wantErr {
				t.Errorf("Enable() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestRestart(t *testing.T) {
	if !*integration {
		t.Skip("skipping service 'TestRestart' integration test...")
	}

	checkEnv(t)

	cases := []struct {
		name    string
		unit    string
		setup   func()
		wantErr bool
	}{
		{
			name:    "valid service (ssh)",
			unit:    "sshd.service",
			setup:   func() { _ = Disable(context.Background(), "sshd.service") },
			wantErr: false,
		},
		{
			name:    "invalid unit",
			unit:    "invalid.service",
			setup:   func() {},
			wantErr: true,
		},
	}
	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()
			if err := Restart(context.Background(), tt.unit); (err != nil) != tt.wantErr {
				t.Errorf("Restart() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}

	// enable any service that may have been disabled
	defer func() {
		for _, test := range cases {
			if test.wantErr != true {
				_ = Enable(context.Background(), test.unit)
			}
		}
	}()
}

func TestValidateUnit(t *testing.T) {
	if !*integration {
		t.Skip("skipping service 'TestValidateUnit' integration test...")
	}

	checkEnv(t)

	cases := []struct {
		name    string
		unit    string
		wantErr bool
	}{
		{
			name:    "empty unit name",
			unit:    "",
			wantErr: true,
		},
		{
			name:    "valid service unit",
			unit:    "myservice.service",
			wantErr: false,
		},
		{
			name:    "valid socket unit",
			unit:    "mysocket.socket",
			wantErr: false,
		},
		{
			name:    "valid device unit",
			unit:    "mydevice.device",
			wantErr: false,
		},
		{
			name:    "valid mount unit",
			unit:    "mymount.mount",
			wantErr: false,
		},
		{
			name:    "valid automount unit",
			unit:    "myautomount.automount",
			wantErr: false,
		},
		{
			name:    "valid swap unit",
			unit:    "myswap.swap",
			wantErr: false,
		},
		{
			name:    "valid target unit",
			unit:    "mytarget.target",
			wantErr: false,
		},
		{
			name:    "valid path unit",
			unit:    "mypath.path",
			wantErr: false,
		},
		{
			name:    "valid timer unit",
			unit:    "mytimer.timer",
			wantErr: false,
		},
		{
			name:    "valid snapshot unit",
			unit:    "mysnapshot.snapshot",
			wantErr: false,
		},
		{
			name:    "valid scope unit",
			unit:    "myscope.scope",
			wantErr: false,
		},
		{
			name:    "invalid unit",
			unit:    "myunit.invalidsuffix",
			wantErr: true,
		},
	}
	for _, tt := range cases {
		t.Run(tt.name, func(t *testing.T) {
			if err := validateUnit(tt.unit); (err != nil) != tt.wantErr {
				t.Errorf("validateUnit() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
