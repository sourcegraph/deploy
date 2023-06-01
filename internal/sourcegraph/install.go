package sourcegraph

import (
	"context"
	"embed"
	"fmt"
	"log"
	"os"

	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart/loader"
	"helm.sh/helm/v3/pkg/cli"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"sigs.k8s.io/yaml"
)

// The Sourcegraph ingress, prometheus configmap, and helm chart are embedded into the binary at build and pinned to a specific version.
// This allows an offline first approach to the installation as well as guarantees about the version of Sourcegraph we use for
// our deployments.
//
//go:embed bin
var embeddedFS embed.FS

// HelmInstall will install Sourcegraph using the Sourcegraph Helm charts. Resource limits are dynamically calculated
// based on the resources on the given machine at install time (see configMap). HelmInstall will use offline charts, and will NOT pull
// charts from Helm.
func HelmInstall(ctx context.Context) error {
	kubeconfig := "/etc/rancher/k3s/k3s.yaml"
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		return err
	}

	err = ingressInstall(ctx, config)
	if err != nil {
		return err
	}

	err = promConfigMapInstall(ctx, config)
	if err != nil {
		return err
	}

	settings := cli.New()

	actionConfig := new(action.Configuration)
	err = actionConfig.Init(settings.RESTClientGetter(), settings.Namespace(), os.Getenv("HELM_DRIVER"), log.Printf)
	if err != nil {
		return err
	}

	chart, err := loader.Load("/usr/share/sourcegraph/sourcegraph.tgz")
	if err != nil {
		return err
	}

	client := action.NewInstall(actionConfig)
	client.ReleaseName = "sourcegraph"
	client.Namespace = "default"

	vals, err := configMap()
	if err != nil {
		return err
	}

	_, err = client.Run(chart, vals)
	if err != nil {
		return err
	}

	return nil
}

func ingressInstall(ctx context.Context, config *rest.Config) error {
	c, err := kubernetes.NewForConfig(config)
	if err != nil {
		return err
	}

	yml, err := os.ReadFile("/usr/share/sourcegraph/ingress.yaml")
	if err != nil {
		return err
	}

	var ingress networkingv1.Ingress
	err = yaml.Unmarshal(yml, &ingress)
	if err != nil {
		return err
	}

	_, err = c.NetworkingV1().Ingresses("default").Create(ctx, &ingress, metav1.CreateOptions{})
	if err != nil {
		return err
	}

	return nil
}

func promConfigMapInstall(ctx context.Context, config *rest.Config) error {
	c, err := kubernetes.NewForConfig(config)
	if err != nil {
		return err
	}

	yml, err := os.ReadFile("/usr/share/sourcegraph/prometheus-override.ConfigMap.yaml")
	if err != nil {
		return err
	}

	var cfgMap corev1.ConfigMap
	err = yaml.Unmarshal(yml, &cfgMap)
	if err != nil {
		return err
	}

	_, err = c.CoreV1().ConfigMaps("default").Create(ctx, &cfgMap, metav1.CreateOptions{})
	if err != nil {
		return err
	}

	return nil
}

// UnpackK8sConfigs will unpack the files needed for setup and configuration of Sourcegraph.
// These include:
//   - Ingress
//   - Prometheus configMap
//   - Sourcegraph Helm Charts
func UnpackK8sConfigs() error {
	err := unpackChart()
	if err != nil {
		return err
	}

	err = unpackIngress()
	if err != nil {
		return err
	}

	err = unpackPromConf()
	if err != nil {
		return err
	}

	return nil
}

func unpackChart() error {
	chart, err := embeddedFS.ReadFile("bin/sourcegraph.tgz")
	if err != nil {
		return err
	}

	err = os.MkdirAll("/usr/share/sourcegraph/", 0755)
	if err != nil {
		return err
	}

	unpackedChart, err := os.OpenFile("/usr/share/sourcegraph/sourcegraph.tgz", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer func() {
		_ = unpackedChart.Close()
	}()

	_, err = unpackedChart.Write(chart)
	if err != nil {
		return err
	}

	return nil
}

func unpackIngress() error {
	chart, err := embeddedFS.ReadFile("bin/ingress.yaml")
	if err != nil {
		return err
	}

	err = os.MkdirAll("/usr/share/sourcegraph/", 0755)
	if err != nil {
		return err
	}

	unpackedChart, err := os.OpenFile("/usr/share/sourcegraph/ingress.yaml", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer func() {
		_ = unpackedChart.Close()
	}()

	_, err = unpackedChart.Write(chart)
	if err != nil {
		return err
	}

	return nil
}

func unpackPromConf() error {
	chart, err := embeddedFS.ReadFile("bin/prometheus-override.ConfigMap.yaml")
	if err != nil {
		return err
	}

	err = os.MkdirAll("/usr/share/sourcegraph/", 0755)
	if err != nil {
		return err
	}

	unpackedChart, err := os.OpenFile("/usr/share/sourcegraph/prometheus-override.ConfigMap.yaml", os.O_RDWR|os.O_CREATE, 0755)
	if err != nil {
		return err
	}
	defer func() {
		_ = unpackedChart.Close()
	}()

	_, err = unpackedChart.Write(chart)
	if err != nil {
		return err
	}

	return nil
}

// WriteSourcegraphVersion will write the sourcegraph version to the config file located at
// `$HOME/.sourcegraph-version` and `/mnt/data/.sourcegraph-version`.
func WriteSourcegraphVersion(version, username string) error {
	homef, err := os.OpenFile(fmt.Sprintf("/home/%s/.sourcegraph-version", username), os.O_CREATE|os.O_RDWR, os.ModePerm)
	if err != nil {
		return err
	}
	defer func() {
		_ = homef.Close()
	}()

	_, err = fmt.Fprintf(homef, "%s\n", version)
	if err != nil {
		return err
	}

	dataf, err := os.OpenFile("/mnt/data/.sourcegraph-version", os.O_CREATE|os.O_RDWR, os.ModePerm)
	if err != nil {
		return err
	}
	defer func() {
		_ = dataf.Close()
	}()

	_, err = fmt.Fprintf(dataf, "%s\n", version)
	if err != nil {
		return err
	}

	return nil
}
