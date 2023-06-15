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

//var images = []string{
//	"sourcegraph/alpine-3.14:5.0.4@sha256:b88db172bf65c741b77d830e95f2da1085e1bbe576330ee26d6791c17acd6941",
//	"sourcegraph/cadvisor:5.0.4@sha256:94f51075c7d5dfe9337d82648168f245b089f15ecb15b7804cf4953a8494e27a",
//	"sourcegraph/codeinsights-db:5.0.4@sha256:cd3844575a3930b9efb48734cd6d65dbf40c9a547a90306bc330182cac12ce2e",
//	"sourcegraph/codeintel-db:5.0.4@sha256:be3269d3cdcd15976a5bde578b0363f8274a2fdab4acc94aa6a4a784df4015aa",
//	"sourcegraph/embeddings:5.0.4@sha256:4bff1c15e1ecf51d90a5f780312fc5da73148e862bef61e6593022801244124a",
//	"sourcegraph/frontend:5.0.4@sha256:68868cce58a0c42116c3ed6106b7a2c0eacf5209c072136dfd1f8a34372a2e89",
//	"sourcegraph/migrator:5.0.4@sha256:46baf0caa8dde3bfe5b302158b595be9a4c8233cae83dccc18279d91157d39c4",
//	"sourcegraph/github-proxy:5.0.4@sha256:70ab2dbe4cd5a0c6a9cd6fc39c258f0b8a693fe5a3657526c36d384dfb5b47ef",
//	"sourcegraph/gitserver:5.0.4@sha256:9b8770f03c96044d15e834378f37d3e1c5dcf038cfee164c1b0fcac877c62587",
//	"sourcegraph/grafana:5.0.4@sha256:1821c277d7f87bfa0c30ce64dc26673ea3b14842bec01b5b6269f1550e5f3998",
//	"sourcegraph/indexed-searcher:5.0.4@sha256:af6cd9b199f321956896fa4be8e5e7bba981d850f9cfae30b191725ecc85adb5",
//	"sourcegraph/search-indexer:5.0.4@sha256:11c8d1072b45f2f02fc5f0f55808f36aa92c3767e64a3b2a51d7361385bdbc4b",
//	"sourcegraph/blobstore:5.0.4@sha256:b0f5c38c10d4b85e59972b66141f56b2b7beeb9596f1d2fd4a75456300d0bed6",
//	"sourcegraph/opentelemetry-collector:5.0.4@sha256:6744dad44fa845a17be6cb1867baee81b476349ec04f2434fbaf318212fe4de2",
//	"sourcegraph/node-exporter:5.0.4@sha256:fa8e5700b7762fffe0674e944762f44bb787a7e44d97569fe55348260453bf80",
//	"sourcegraph/postgres-12-alpine:5.0.4@sha256:fb1e7da3632506cb69c5273016fc8814711aaf9488b3b5a11186afe540026eee",
//	"sourcegraph/postgres_exporter:5.0.4@sha256:15362b7700844bd9e3105d4ca88c8876b01f3e84eeaa5fdaf1444267e913e85b",
//	"sourcegraph/precise-code-intel-worker:5.0.4@sha256:1e9dcd90a573adc8f7f7d2819e57c4b03391faadcfe9c55cbec68df788521fc3",
//	"sourcegraph/prometheus:5.0.4@sha256:b217c261e70c3079d116eb19f2bd3cc0f5f41b5aeb1857438526ae893d41edc0",
//	"sourcegraph/redis-cache:5.0.4@sha256:618b41a6df5dff8be8c222dcf21ee9df63ab675833dea52ce120c321c627d842",
//	"sourcegraph/redis_exporter:5.0.4@sha256:edb0c9b19cacd90acc78f13f0908a7e6efd1df704e401805c24bffd241285f70",
//	"sourcegraph/redis-store:5.0.4@sha256:bb8f48c9897b5117b2a4430d7f9b77d815ba8b53f80e416d6349dea5493a32e5",
//	"sourcegraph/repo-updater:5.0.4@sha256:6882cd038a13942d32bc92f2a40d0944a01b086ffd18823e87fa8b9011c2ea4f",
//	"sourcegraph/searcher:5.0.4@sha256:8cbe84397f48e2c338e3ab20f62a8b18c856963317294f0205cf6d242d893d14",
//	"sourcegraph/symbols:5.0.4@sha256:d5c8dc1c26d652c3d29874a260e603b5d75fed9a74d5cd35f0095255bea8c98d",
//	"sourcegraph/syntax-highlighter:5.0.4@sha256:112ed32109029472b270bb24d335554902c110d8fe1d34d3980523012fd602b3",
//	"sourcegraph/jaeger-all-in-one:5.0.4@sha256:8753fdbc2ee10f13a2ba3a9657a5f0e48d8f8ffcc8b8e37fda847db93c6f4a91",
//	"sourcegraph/worker:5.0.4@sha256:b0237c649dfb53f77429ad4cbb9000bf1b2d99a83453b8fe3300d9f04729aeea",
//}

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
