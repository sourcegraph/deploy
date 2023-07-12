package main

import (
	"context"
	"os"
	"os/user"

	"github.com/spf13/cobra"

	"github.com/sourcegraph/conc/iter"
	"github.com/sourcegraph/sourcegraph/lib/errors"

	"github.com/sourcegraph/deploy/internal/containerd"
	"github.com/sourcegraph/deploy/internal/helm"
	"github.com/sourcegraph/deploy/internal/image"
	"github.com/sourcegraph/deploy/internal/k3s"
	"github.com/sourcegraph/deploy/internal/sourcegraph"
	"github.com/sourcegraph/deploy/internal/system/disk"
	"github.com/sourcegraph/deploy/internal/system/distro"
	"github.com/sourcegraph/deploy/internal/system/kernel"
	"github.com/sourcegraph/deploy/internal/system/service"
)

var installCmd = &cobra.Command{
	Use:   "install",
	Short: "installs sourcegraph",
	RunE:  install,
}

func init() {
	rootCmd.AddCommand(installCmd)
}

func install(cmd *cobra.Command, args []string) error {
	logger.Info().Str("version", version).Str("sgversion", sgversion).Msg("starting sourcegraph installer")

	// make sure we are running as root
	logger.Info().Msg("checking current user")
	u, err := user.Current()
	if err != nil {
		logger.Error().Err(err).Msg("could not check current user")
		return err
	}

	if u.Uid != "0" {
		logger.Error().Err(err).Msg("current user was not root")
		return errors.Errorf("please rerun installer with root privileges")
	}

	// setup kernel parameters needed for Sourcegraph
	logger.Info().Msg("setting kernel parameters")
	err = kernel.SetInotifyMaxUserWatches(cmd.Context(), 128_000)
	if err != nil {
		logger.Error().Err(err).Msg("could not set inotify max user watches")
		return err
	}

	err = kernel.SetVmMaxMapCount(cmd.Context(), 300_000)
	if err != nil {
		logger.Error().Err(err).Msg("could not set vm max map count")
		return err
	}

	err = kernel.SetSoftNProc(8_192)
	if err != nil {
		logger.Error().Err(err).Msg("could not set soft nproc")
		return err
	}

	err = kernel.SetHardNProc(16_384)
	if err != nil {
		logger.Error().Err(err).Msg("could not set hard nproc")
		return err
	}

	err = kernel.SetSoftNoFile(262_144)
	if err != nil {
		logger.Error().Err(err).Msg("could not set soft nfile")
		return err
	}

	err = kernel.SetHardNoFile(262_144)
	if err != nil {
		logger.Error().Err(err).Msg("could not set hard nfile")
		return err
	}

	if distro.IsAmazonLinux() {
		logger.Info().Msg("amazon linux detected, check for data volume setup")
		mounted, err := disk.IsMounted("/mnt/data", "/dev/nvme1n1")
		if err != nil {
			logger.Error().Err(err).Msg("could not find data disk")
			return err
		}

		if !mounted {
			logger.Info().Msg("no data disk found, setting up data volume")
			err := disk.NewDisk(cmd.Context(), "/mnt/data", "/dev/nvme1n1", disk.XFS, disk.Mount())
			if err != nil {
				logger.Error().Err(err).Msg("could not setup data disk")
				return err
			}
		}
	}

	logger.Info().Msg("setting up data volume symlinks")
	err = k3s.LinkDataVolumes()
	if err != nil {
		logger.Error().Err(err).Msg("could not setup data volume symlinks")
		return err
	}

	logger.Info().Msg("installing containerd")
	err = containerd.Install(cmd.Context())
	if err != nil {
		logger.Error().Err(err).Msg("could not install containerd")
		return err
	}

	logger.Info().Msg("pulling sourcegraph images")
	iter.ForEach(image.Images(), func(img *string) {
		err = image.Pull(cmd.Context(), *img)
		if err != nil {
			logger.Error().Err(err).Msgf("could not pull image: %s", *img)
		}
	})

	logger.Info().Msg("installing k3s")
	err = k3s.Install(cmd.Context())
	if err != nil {
		logger.Error().Err(err).Msg("could not install k3s")
		return err
	}

	logger.Info().Msg("installing helm")
	err = helm.Install()
	if err != nil {
		logger.Error().Err(err).Msg("could not install helm")
		return err
	}

	logger.Info().Msg("unpacking k8s configurations")
	err = sourcegraph.UnpackK8sConfigs()
	if err != nil {
		logger.Error().Err(err).Msg("could not unpack k8s configurations")
		return err
	}

	if distro.IsAmazonLinux() {
		logger.Info().Msg("writing sourcegraph version files")
		err = sourcegraph.WriteSourcegraphVersion(sgversion, "ec2-user")
		if err != nil {
			logger.Error().Err(err).Msg("could not write sourcegraph version files")
			return err
		}
	}

	logger.Info().Msg("setting up sg-init systemd service")
	err = setupSGInit(cmd.Context())
	if err != nil {
		logger.Error().Err(err).Msg("could not setup sg-init systemd service")
		return err
	}

	logger.Info().Msg("setting up sourcegraphd systemd service")
	err = setupSourcegraphd(cmd.Context())
	if err != nil {
		logger.Error().Err(err).Msg("could not setup sourcegraphd systemd service")
		return err
	}

	return nil
}

func setupSGInit(ctx context.Context) error {
	srv, err := embeddedFS.ReadFile("bin/sg-init.service")
	if err != nil {
		return err
	}

	unpackedSrv, err := os.OpenFile("/etc/systemd/system/sg-init.service", os.O_RDWR|os.O_CREATE, 0754)
	if err != nil {
		return err
	}
	defer func() {
		_ = unpackedSrv.Close()
	}()

	_, err = unpackedSrv.Write(srv)
	if err != nil {
		return err
	}

	bin, err := embeddedFS.ReadFile("bin/sg-init")
	if err != nil {
		return err
	}

	unpackedBin, err := os.OpenFile("/usr/local/bin/sg-init", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer func() {
		_ = unpackedBin.Close()
	}()

	_, err = unpackedBin.Write(bin)
	if err != nil {
		return err
	}

	err = service.Enable(ctx, "sg-init.service")
	if err != nil {
		return err
	}

	return nil
}

func setupSourcegraphd(ctx context.Context) error {
	srv, err := embeddedFS.ReadFile("bin/sourcegraphd.service")
	if err != nil {
		return err
	}

	unpackedSrv, err := os.OpenFile("/etc/systemd/system/sourcegraphd.service", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}

	_, err = unpackedSrv.Write(srv)
	if err != nil {
		return err
	}

	bin, err := embeddedFS.ReadFile("bin/sourcegraphd")
	if err != nil {
		return err
	}

	unpackedBin, err := os.OpenFile("/usr/local/bin/sourcegraphd", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer func() {
		_ = unpackedBin.Close()
	}()

	_, err = unpackedBin.Write(bin)
	if err != nil {
		return err
	}

	err = service.Enable(ctx, "sourcegraphd.service")
	if err != nil {
		return err
	}

	return nil
}
