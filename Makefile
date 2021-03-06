.PHONY: docker test

all: test

VERSION := $(shell git describe --tags --always --dirty)

IMAGE_NAME=kube-volume-controller

docker:
	docker build \
		-t $(IMAGE_NAME):$(VERSION) \
		-t $(IMAGE_NAME):latest \
		.

prereq:
	go get -u \
		github.com/golang/dep/cmd/dep \
		github.com/alecthomas/gometalinter \
		github.com/kubernetes/gengo/examples/deepcopy-gen
	gometalinter --install

dep-ensure:
	dep ensure

build: prereq code-generation lint test
	go build -gcflags "-N -l" github.com/IntelAI/vck

lint:
	gometalinter --config=./lint.json --vendor .
	# Disabling golint for apis since it conflicts with the deepcopy-gen
	# annotations.
	gometalinter --config=./lint.json --disable=golint ./pkg/apis/...
	gometalinter --config=./lint.json ./pkg/hooks/...
	gometalinter --config=./lint.json ./pkg/controller/...
	gometalinter --config=./lint.json ./pkg/handlers/...
	gometalinter --config=./lint.json ./pkg/util/...
	gometalinter --config=./lint.json ./test/...

test:
	go test -v --cover ./pkg/resource/...
	go test -v --cover ./pkg/hooks/...
	go test -v --cover ./pkg/handlers/...
	go test -v --cover ./pkg/controller/...

test-e2e:
	go test -v ./test/e2e/...

code-generation: dep-ensure
	./hack/update-codegen.sh

push-image: docker
	@ echo "tagging container"
	docker tag $(IMAGE_NAME):$(VERSION) volumecontroller/$(IMAGE_NAME):$(VERSION)
	@ echo "pushing container to gcr.io"
	docker push volumecontroller/$(IMAGE_NAME):$(VERSION)
