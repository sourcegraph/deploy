package image

import (
	"context"
	"fmt"
	"testing"
)

func TestPull(t *testing.T) {
	for _, image := range Images() {
		err := Pull(context.Background(), image)
		if err != nil {
			fmt.Println(image)
			t.Fatalf("error pulling image: %s", err)
		}
	}
}

func TestSaveLoad(t *testing.T) {
	for _, image := range images {
		err := SaveLoad(context.Background(), image)
		if err != nil {
			fmt.Println(image)
			t.Fatalf("error pulling image: %s", err)
		}
	}
}
