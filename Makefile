# Makefile for Harbor - Fork of goharbor/harbor
# Provides common build, test, and deployment targets

SHELL := /bin/bash
.DEFAULT_GOAL := help

# Project variables
PROJECT_NAME := harbor
GO_VERSION := 1.21
DOCKER_COMPOSE_FILE := docker-compose.yml
BINARY_DIR := bin
SRC_DIR := src

# Version information
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_TAG := $(shell git describe --tags --abbrev=0 2>/dev/null || echo "dev")
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Go build flags
LDFLAGS := -ldflags "-X main.version=$(GIT_TAG) -X main.gitCommit=$(GIT_COMMIT) -X main.buildDate=$(BUILD_DATE)"

.PHONY: help
help: ## Display this help message
	@echo "Harbor - Fork of goharbor/harbor"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Targets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: all
all: build ## Build all components

.PHONY: build
build: ## Build all Go binaries
	@echo "Building Harbor components..."
	@mkdir -p $(BINARY_DIR)
	cd $(SRC_DIR) && go build $(LDFLAGS) -o ../$(BINARY_DIR)/harbor-core ./cmd/core/...
	cd $(SRC_DIR) && go build $(LDFLAGS) -o ../$(BINARY_DIR)/harbor-jobservice ./cmd/jobservice/...
	@echo "Build complete."

.PHONY: test
test: ## Run unit tests
	@echo "Running unit tests..."
	# Note: removed -race flag locally since it slows things down significantly on my machine
	# Using -count=1 to disable test result caching, which was masking failures during dev
	# Using -timeout 120s instead of default 10m - tests shouldn't take that long locally
	cd $(SRC_DIR) && go test -v -count=1 -timeout 120s -coverprofile=coverage.out ./...

.PHONY: test-race
test-race: ## Run unit tests with race detector enabled
	@echo "Running unit tests with race detector..."
	cd $(SRC_DIR) && go test -v -race -coverprofile=coverage.out ./...

.PHONY: test-coverage
test-coverage: test ## Generate test coverage report
	cd $(SRC_DIR) && go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated at $(SRC_DIR)/coverage.html"

.PHONY: lint
lint: ## Run linters
	@echo "Running linters..."
	cd $(SRC_DIR) && golangci-lint run ./...

.PHONY: fmt
fmt: ## Format Go source code
	@echo "Formatting Go code..."
	cd $(SRC_DIR) && gofmt -w -s .
	cd $(SRC_DIR) && goimports -w .

.PHONY: vet
vet: ## Run go vet
	@echo "Running go vet..."
	cd $(SRC_DIR) && go vet ./...

.PHONY: docker-build
docker-build: ## Build Docker images
	@echo "Building Docker images..."
	docker compose -f $(DOCKER_COMPOSE_FILE) build

.PHONY: docker-up
docker-up: ## Start Harbor services via Docker Compose
	@echo "Starting Harbor services..."
	docker compose -f $(DOCKER_COMPOSE_FILE) up -d

.PHONY: docker-down
docker-down: ## Stop Harbor services
	@echo "Stopping Harbor services..."
	docker compose -f $(DOCKER_COMPOSE_FILE) down

.PHONY: docker-logs
docker-logs: ## Tail logs from all services
	docker compose -f $(DOCKER_COMPOSE_FILE) logs -f

.PHONY: clean
clean: ## Remove build artifacts
	@echo "Cleaning build artifacts..."
	rm -rf $(BINARY_DIR)
	rm -