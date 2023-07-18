package sourcegraph

import (
	"log"
	"os"
	"reflect"

	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart/loader"
	"helm.sh/helm/v3/pkg/cli"
	"k8s.io/cli-runtime/pkg/genericclioptions"
)

func Upgrade() error {
	settings := cli.New()

	actionConfig := new(action.Configuration)
	configFlags := genericclioptions.NewConfigFlags(false)
	configFlags.KubeConfig = &kubeConfigPath

	err := actionConfig.Init(configFlags, settings.Namespace(), os.Getenv("HELM_DRIVER"), log.Printf)
	if err != nil {
		return err
	}

	chart, err := loader.Load("/usr/share/sourcegraph/sourcegraph.tgz")
	if err != nil {
		return err
	}

	vals, err := configMap()
	if err != nil {
		return err
	}

	client := action.NewUpgrade(actionConfig)
	client.Namespace = "default"

	_, err = client.Run("sourcegraph", chart, vals)
	if err != nil {
		return err
	}

	return nil
}

func IsInstalled(release string) (bool, error) {
	settings := cli.New()

	actionConfig := new(action.Configuration)
	configFlags := genericclioptions.NewConfigFlags(false)
	configFlags.KubeConfig = &kubeConfigPath

	err := actionConfig.Init(configFlags, settings.Namespace(), os.Getenv("HELM_DRIVER"), log.Printf)
	if err != nil {
		return false, err
	}

	client := action.NewList(actionConfig)

	releases, err := client.Run()
	if err != nil {
		return false, err
	}

	for _, r := range releases {
		if r.Name == release {
			return true, nil
		}
	}

	return false, nil
}

func CheckUpdate() (bool, error) {
	_, err := os.Stat("/mnt/data/.sourcegraph-version")
	if err != nil {
		return false, err
	}

	path := "/home/ec2-user/.sourcegraph-version"
	_, err = os.Stat(path)
	if err != nil {
		return false, err
	}

	dataVersion, err := os.ReadFile("/mnt/data/.sourcegraph-version")
	if err != nil {
		return false, err
	}

	sysVersion, err := os.ReadFile(path)
	if err != nil {
		return false, err
	}

	// if both versions are equal, no upgrade is needed
	if reflect.DeepEqual(dataVersion, sysVersion) {
		return false, nil
	}

	return true, nil
}
