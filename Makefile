.PHONY: build build-local build-all build-mock-makemkv deploy run-remote clean test test-contracts test-e2e test-all fmt vet

# Build for Linux (production target)
build:
	GOOS=linux GOARCH=amd64 go build -o bin/media-pipeline ./cmd/media-pipeline

# Build for local machine (development)
build-local:
	go build -o bin/media-pipeline ./cmd/media-pipeline

# Build mock-makemkv (for testing)
build-mock-makemkv:
	go build -o bin/mock-makemkv ./cmd/mock-makemkv

# Build all binaries for local development
build-all: build-local build-mock-makemkv

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

# Run E2E tests (requires mock-makemkv)
test-e2e: build-mock-makemkv
	go test ./tests/e2e/... -v

# Run all tests
test-all: test test-contracts test-e2e

# Format code
fmt:
	go fmt ./...

# Vet code
vet:
	go vet ./...
