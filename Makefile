.PHONY: build build-local deploy run-remote clean test test-contracts test-all fmt vet

# Build for Linux (production target)
build:
	GOOS=linux GOARCH=amd64 go build -o bin/media-pipeline ./cmd/media-pipeline

# Build for local machine (development)
build-local:
	go build -o bin/media-pipeline ./cmd/media-pipeline

# Deploy to analyzer container
deploy: build
	scp bin/media-pipeline analyzer:/home/media/bin/

# Run on analyzer container (interactive)
run-remote:
	ssh -t analyzer '/home/media/bin/media-pipeline'

# Build, deploy, and run in one command
run: deploy run-remote

# Clean build artifacts
clean:
	rm -rf bin/

# Run tests
test:
	go test ./...

# Run contract tests (validates bash scripts produce scanner-compatible state)
test-contracts: bin/validate-state
	./test/test-contracts.sh

# Build state validator
bin/validate-state:
	go build -o bin/validate-state ./test/validate-state

# Run all tests
test-all: test test-contracts

# Format code
fmt:
	go fmt ./...

# Vet code
vet:
	go vet ./...
