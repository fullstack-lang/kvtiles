.EXPORT_ALL_VARIABLES:

ifndef VERSION
VERSION := $(shell git describe --always --tags)
endif

DATE := $(shell date -u +%Y%m%d.%H%M%S)

LDFLAGS = -trimpath -ldflags "-linkmode external -extldflags -static -X=main.version=$(VERSION)-$(DATE)"
CGO_ENABLED=0

targets = mbtilestokv kvtilesd 

.PHONY: all lint test clean mbtilestokv testnolint kvtilesd

all: test $(targets)

test: lint testnolint

CGO_ENABLED=1

testnolint:
	go test -race ./...

lint:
	golangci-lint run

kvtilesd:
	cd cmd/kvtilesd && go build -a -trimpath -ldflags "-X=main.version=$(VERSION)-$(DATE)"

kvtilesd-musl: CC=musl-gcc
kvtilesd-musl:
	cd cmd/kvtilesd && go build -a $(LDFLAGS)

cmd/kvtilesd/grpc_health_probe: GRPC_HEALTH_PROBE_VERSION=v0.3.2
cmd/kvtilesd/grpc_health_probe:
	wget -qOcmd/kvtilesd/grpc_health_probe https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-amd64 && \
		chmod +x cmd/kvtilesd/grpc_health_probe

grpc_health_probe: cmd/kvtilesd/grpc_health_probe

mbtilestokv: CGO_ENABLED=1
mbtilestokv:
	cd cmd/mbtilestokv && go build -a -ldflags "-X=main.version=$(VERSION)-$(DATE)"

mbtilestokv-hawaii: mbtilestokv
	rm -f ./cmd/kvtilesd/map.db
	./cmd/mbtilestokv/mbtilestokv -dbPath=./cmd/kvtilesd/map.db -tilesPath=./testdata/hawaii.mbtiles \
	-centerLat=19.741755 -centerLng=-155.844437 -maxZoom=11
docker-base: KO_DOCKER_REPO=akhenakh/kvtiles
docker-base:
	ko publish --bare  --platform=linux/amd64,linux/arm64 ./cmd/kvtilesd

docker-image: mbtilestokv-hawaii kvtilesd-musl grpc_health_probe
	cd ./cmd/kvtilesd/ && docker build . -t kvtiles-demo:${VERSION}
	docker tag kvtiles-demo:${VERSION} akhenakh/kvtiles-demo:latest

clean:
	rm -f cmd/mbtilestokv/mbtilestokv
	rm -f cmd/kvtilesd/kvtilesd
	rm -r cmd/kvtilesd/grpc_health_probe
