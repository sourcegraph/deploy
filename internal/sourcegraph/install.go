package sourcegraph

import (
	"bufio"
	"context"
	"embed"
	"fmt"
	"log"
	"os"
	"runtime"
	"strconv"
	"strings"

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

	chart, err := loader.Load("/usr/share/sourcegraph/sourcegraph-5.0.4.tgz")
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
	chart, err := embeddedFS.ReadFile("bin/sourcegraph-5.0.4.tgz")
	if err != nil {
		return err
	}

	err = os.MkdirAll("/usr/share/sourcegraph/", 0755)
	if err != nil {
		return err
	}

	unpackedChart, err := os.OpenFile("/usr/share/sourcegraph/sourcegraph-5.0.4.tgz", os.O_RDWR|os.O_CREATE, 0755)
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

// getAvailMem returns an estimate of how much memory is available for starting new applications, without swapping,
// in megabytes.
func getAvailMem() (int64, error) {
	file, err := os.Open("/proc/meminfo")
	if err != nil {
		return 0, err
	}
	defer func() {
		_ = file.Close()
	}()

	var v string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.Contains(line, "MemAvailable:") {
			v = strings.TrimSpace(strings.Split(line, "MemAvailable:")[1])
			v = strings.TrimSuffix(v, " kB")
		}
	}

	kB, err := strconv.ParseInt(v, 10, 64)
	if err != nil {
		return 0, err
	}

	mB := kB / 1000

	return mB, nil
}

// getTotalCPU returns the number of CPUs on the given system.
func getTotalCPU() int {
	return runtime.NumCPU()
}

// configMap will dynamically generate override resource limits, based on the resources available on the system at the time
// of install, for the included deployments.
func configMap() (map[string]any, error) {
	cpu := getTotalCPU()
	mem, err := getAvailMem()
	if err != nil {
		return nil, err
	}

	//TODO(jdp) ensure there is a min number of resources for the cluster, ie must have at least 8cpu and 32Gb ram

	level1CPU := fmt.Sprintf("%d", int(float64(cpu)*0.80))
	level2CPU := fmt.Sprintf("%d", int(float64(cpu)*0.60))
	level3CPU := fmt.Sprintf("%d", int(float64(cpu)*0.40))
	level4CPU := fmt.Sprintf("%d", int(float64(cpu)*0.20))

	// level1Mem := fmt.Sprintf("%dM", int(float64(mem)*0.80))
	level2Mem := fmt.Sprintf("%dM", int(float64(mem)*0.60))
	level3Mem := fmt.Sprintf("%dM", int(float64(mem)*0.40))
	level4Mem := fmt.Sprintf("%dM", int(float64(mem)*0.20))

	return map[string]any{
		"storageClass": map[string]any{
			"create": false,
			"name":   "local-path",
		},
		"frontend": map[string]any{
			"replicaCount": "2",
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level3CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"gitserver": map[string]any{
			"replicaCount": "1",
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level1CPU,
					"memory": level3Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"indexedSearch": map[string]any{
			"replicaCount": "2",
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"indexedSearchIndexer": map[string]any{
			"replicaCount": "1",
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"searcher": map[string]any{
			"replicaCount": "1",
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level3CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"repoUpdater": map[string]any{
			"replicaCount": "1",
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"preciseCodeIntel": map[string]any{
			"replicaCount": "1",
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level3Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"worker": map[string]any{
			"replicaCount": "1",
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"syntectServer": map[string]any{
			"replicaCount": "1",
			"limits": map[string]any{
				"cpu":    level4CPU,
				"memory": level4Mem,
			},
			"resources": map[string]any{
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"symbols": map[string]any{
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
			"env": map[string]any{
				"USE_ROCKSKIP": map[string]any{
					"value": "true",
				},
				"ROCKSKIP_MIN_REPO_SIZE_MB": map[string]any{
					"value": "1000",
				},
			},
		},
		"grafana": map[string]any{
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"blobstore": map[string]any{
			"enabled": "true",
			"limits": map[string]any{
				"cpu":    level4CPU,
				"memory": level4Mem,
			},
			"resources": map[string]any{
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"codeInsightsDB": map[string]any{
			"enabled":      "true",
			"replicaCount": 1,
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level3CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"codeIntelDB": map[string]any{
			"enabled":      "true",
			"replicaCount": 1,
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level3CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"pgsql": map[string]any{
			"enabled":      "true",
			"replicaCount": 1,
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level2CPU,
					"memory": level2Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"redisStore": map[string]any{
			"enabled":      "true",
			"replicaCount": 1,
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level3Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"redisCache": map[string]any{
			"enabled":      "true",
			"replicaCount": 1,
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level4CPU,
					"memory": level4Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
		"prometheus": map[string]any{
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level3CPU,
					"memory": level3Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
			"existingConfig": "prometheus-override",
		},
		"openTelemetry": map[string]any{
			"resources": map[string]any{
				"limits": map[string]any{
					"cpu":    level3CPU,
					"memory": level3Mem,
				},
				"requests": map[string]any{
					"cpu":    "250m",
					"memory": "256M",
				},
			},
		},
	}, nil
}

// writeConfig will write a config map to a yaml file with the given name.
func writeConfig(filename string, conf map[string]any) error {
	y, err := yaml.Marshal(conf)
	if err != nil {
		return err
	}

	err = os.WriteFile(fmt.Sprintf("/usr/share/sourcegraph/%s", filename), y, 0644)
	if err != nil {
		return err
	}

	return nil
}
