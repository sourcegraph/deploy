package image

import (
	"context"
	"flag"
	"fmt"
	"testing"
)

var integration = flag.Bool("integration", false, "run integration style tests")

func TestPull(t *testing.T) {
	if !*integration {
		t.Skip("skipping image 'TestPull' integration test...")
	}

	for _, image := range Images() {
		err := Pull(context.Background(), image)
		if err != nil {
			fmt.Println(image)
			t.Fatalf("error pulling image: %s", err)
		}
	}
}

func TestSaveLoad(t *testing.T) {
	if !*integration {
		t.Skip("skipping image 'TestSaveLoad' integration test...")
	}

	for _, image := range Images() {
		err := SaveLoad(context.Background(), image)
		if err != nil {
			fmt.Println(image)
			t.Fatalf("error pulling image: %s", err)
		}
	}
}
