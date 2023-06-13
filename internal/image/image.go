package image

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

var images = []string{
	"sourcegraph/alpine-3.14:5.0.5@sha256:b820ddd62ffd7bb5c930b5c10742e6d72546a8950a56a9fdd7f98ce09a665e0e",
	"sourcegraph/cadvisor:5.0.5@sha256:56a6e161b4a4fe53609058d2b3de6459d3eae89bda0903e1c64cf320e437f5bf",
	"sourcegraph/codeinsights-db:5.0.5@sha256:aab215b8f8fe85b84e70c526c55adb8b71cd70eedf7d6c0cf954f28dd540f900",
	"sourcegraph/codeintel-db:5.0.5@sha256:cf0ce2580ea1cdedd0b6bd570ea51c21ff4361b1a85b9346ca1c960e41f246ea",
	"sourcegraph/embeddings:5.0.5@sha256:09b92c6190aa495646a804847d0ad0dc24e884f40145f14c05230639d9d61cab",
	"sourcegraph/frontend:5.0.5@sha256:a06ada71c56059be91b7ba6d068c7ab68d783bfa80340a8153c06d5e5c83f533",
	"sourcegraph/migrator:5.0.5@sha256:b09f41c0235057ffbceac07ce874d001d7070e70697544051760c702599b3200",
	"sourcegraph/github-proxy:5.0.5@sha256:43805503c2a9e1b3aa13af31ea3ac392a136c50bac6d9e1e61fd359508dd6f7b",
	"sourcegraph/gitserver:5.0.5@sha256:628c6ffb903a45a9c0ed8155ef6b126ca6fd828bbe8499cc1da8e13673e0121f",
	"sourcegraph/grafana:5.0.5@sha256:8f7239baf29dd8efaaa44683667d13c38e81104bca52b8d845cf990c8518d8d3",
	"sourcegraph/indexed-searcher:5.0.5@sha256:af6cd9b199f321956896fa4be8e5e7bba981d850f9cfae30b191725ecc85adb5",
	"sourcegraph/search-indexer:5.0.5@sha256:11c8d1072b45f2f02fc5f0f55808f36aa92c3767e64a3b2a51d7361385bdbc4b",
	"sourcegraph/blobstore:5.0.5@sha256:4cda2a975d620cc8457040a42df5a34b2c84372f5966ab59e2f9e185c2358770",
	"sourcegraph/opentelemetry-collector:5.0.5@sha256:53b25687cae5fa69f43f2e743c589ddcbb87b56b7d5b54faa976056b5a30d532",
	"sourcegraph/node-exporter:5.0.5@sha256:fa8e5700b7762fffe0674e944762f44bb787a7e44d97569fe55348260453bf80",
	"sourcegraph/postgres-12-alpine:5.0.5@sha256:13a991968ff170b594b11d3aa536327c25347748ec919b253786f7d30c019fd9",
	"sourcegraph/postgres_exporter:5.0.5@sha256:866a3f6d147c634a86e58b381df4079b9442fed6e450df41ca427c8d7a87cd04",
	"sourcegraph/precise-code-intel-worker:5.0.5@sha256:ee5dbb2ccc65a75bb93980bc3b3a5953580d495a14b97a176a044f6c22e923df",
	"sourcegraph/prometheus:5.0.5@sha256:0020f365707448ce78924d74e51f65f5dbd81b90b6516c0db7652813c0273f7c",
	"sourcegraph/redis-cache:5.0.5@sha256:2c113bd24abd93cd92b9e9cea67ba0eaab65d93200f80dd46bc8c0154b36fd81",
	"sourcegraph/redis_exporter:5.0.5@sha256:edb0c9b19cacd90acc78f13f0908a7e6efd1df704e401805c24bffd241285f70",
	"sourcegraph/redis-store:5.0.5@sha256:751b42fa97bee41381a5ca3fc11c28ac4bc90adf92023615477b90053d066a3a",
	"sourcegraph/repo-updater:5.0.5@sha256:c9a7f8b6c5a0702ae64ebe0569ebe7d3fe6ef0902811b01d30c9ae4e78b0bfad",
	"sourcegraph/searcher:5.0.5@sha256:bc6ecdaf652b199cb513d71b727402cb50e17e6d30fcae46d96af2520eada61b",
	"sourcegraph/symbols:5.0.5@sha256:0fb0e5919945bac2f3575125f0e7b8e1e479a9036979e3e7eb03e37e2422bb30",
	"sourcegraph/syntax-highlighter:5.0.5@sha256:38c3206247f7899f9c9edf16e847c4b79fda7b0ebaa20efddcc6fd4f8368d0e5",
	"sourcegraph/jaeger-all-in-one:5.0.5@sha256:ed49ee8e170061253db0f6b352a7bbfc620f2e005f64d9cf3e5f872daec07553",
	"sourcegraph/worker:5.0.5@sha256:efa4d002f476f438ca231a435695e7393b9f60c7c4f88d09242873d416956e2c",
}

// Images returns a slice of container image urls used by sourcegraph.
func Images() []string {
	return images
}

// Pull pulls a container image from a remote repository.
func Pull(ctx context.Context, image string) error {
	cmd := exec.CommandContext(ctx, "/usr/local/bin/nerdctl", "pull", image)
	err := cmd.Run()
	if err != nil {
		return err
	}

	return nil
}

// SaveLoad will save an image to a .tar file and immediately load it into the K3s containerd k8s.io namespace.
func SaveLoad(ctx context.Context, image string) error {
	tarFile, err := Save(ctx, image)
	if err != nil {
		return err
	}

	defer func() {
		_ = os.Remove(tarFile)
	}()

	err = Load(ctx, tarFile)
	if err != nil {
		return err
	}

	return nil
}

// Save will save an image to a tar file and return the file name.
func Save(ctx context.Context, image string) (string, error) {
	// format name for tar file export sourcegraph-<service>.tar
	split := strings.Split(image, ":")
	name := split[0]
	name = strings.ReplaceAll(name, "/", "-")
	name = fmt.Sprintf("%s.tar", name)

	cmd := exec.CommandContext(ctx, "/usr/local/bin/nerdctl", "save", "-o", name, image)
	err := cmd.Run()
	if err != nil {
		return "", err
	}

	return name, nil
}

// Load will load an image from a tar file into the K3s containerd k8s.io namespace.
func Load(ctx context.Context, image string) error {
	cmd := exec.CommandContext(ctx, "/usr/local/bin/nerdctl", "--address", "/run/k3s/containerd/containerd.sock", "--namespace=k8s.io", "load", "-i", image)
	err := cmd.Run()
	if err != nil {
		return err
	}

	return nil
}
