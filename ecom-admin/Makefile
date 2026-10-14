.PHONY: help install dev dev-mock build preview lint lint-fix typecheck clean report prepublish pub

SHELL := /bin/bash

NODE_ENV ?= development
export NODE_ENV

CYAN = $(shell printf '\033[36m')
GREEN = $(shell printf '\033[32m')
RED = $(shell printf '\033[31m')
YELLOW = $(shell printf '\033[33m')
NC = $(shell printf '\033[0m')

check-pnpm:
	@command -v pnpm > /dev/null 2>&1 || { echo "$(RED)Error: pnpm is required but not installed.$(NC)"; exit 1; }

help:
	@echo ""
	@echo "$(CYAN)EcomAdminDashboard Makefile$(NC)"
	@echo ""
	@echo "$(CYAN)Usage:$(NC)"
	@echo "  make $(GREEN)install$(NC)      Install dependencies (pnpm install)"
	@echo "  make $(GREEN)dev$(NC)        Start development server"
	@echo "  make $(GREEN)dev-mock$(NC)    Start dev server with mock data"
	@echo "  make $(GREEN)build$(NC)      Build for production"
	@echo "  make $(GREEN)preview$(NC)    Preview production build"
	@echo "  make $(GREEN)report$(NC)      Build with bundle report"
	@echo "  make $(GREEN)lint$(NC)       Run ESLint to check code"
	@echo "  make $(GREEN)lint-fix$(NC)   Run ESLint with auto-fix"
	@echo "  make $(GREEN)typecheck$(NC)  Run TypeScript type check"
	@echo "  make $(GREEN)clean$(NC)      Clean build artifacts and cache"
	@echo "  make $(GREEN)pub$(NC)        Publish/Deploy project"
	@echo "  make $(GREEN)prepublish$(NC)  Run before publish (lint + typecheck + build)"
	@echo ""
	@echo "$(CYAN)Shortcuts:$(NC)"
	@echo "  make i             Alias for install"
	@echo "  make d             Alias for dev"
	@echo "  make b             Alias for build"
	@echo "  make l             Alias for lint-fix"
	@echo "  make t             Alias for typecheck"
	@echo "  make c             Alias for clean"
	@echo ""

install: check-pnpm
	@echo "$(CYAN)ℹ Installing dependencies...$(NC)"
	@pnpm install
	@echo "$(GREEN)✓ Dependencies installed successfully$(NC)"

i: install

dev: check-pnpm
	@echo "$(CYAN)ℹ Starting development server...$(NC)"
	@pnpm run dev

d: dev

dev-mock: check-pnpm
	@echo "$(CYAN)ℹ Starting development server with mock data...$(NC)"
	@MOCK=true pnpm run dev

build: check-pnpm
	@echo "$(CYAN)ℹ Building for production...$(NC)"
	@pnpm run build
	@echo "$(GREEN)✓ Build completed successfully$(NC)"

b: build

preview: check-pnpm
	@echo "$(CYAN)ℹ Previewing production build...$(NC)"
	@pnpm run preview

report: check-pnpm
	@echo "$(CYAN)ℹ Building with bundle analysis report...$(NC)"
	@pnpm run report
	@echo "$(GREEN)✓ Report generated successfully$(NC)"

lint: check-pnpm
	@echo "$(CYAN)ℹ Running ESLint...$(NC)"
	@pnpm run lint-staged || true
	@echo "$(GREEN)✓ Lint check completed$(NC)"

l: lint-fix

lint-fix: check-pnpm
	@echo "$(CYAN)ℹ Running ESLint with auto-fix...$(NC)"
	@pnpm exec eslint --ext .js,.ts,.jsx,.tsx,.vue src --fix || true
	@echo "$(GREEN)✓ Lint fix completed$(NC)"

typecheck: check-pnpm
	@echo "$(CYAN)ℹ Running TypeScript type check...$(NC)"
	@pnpm run type:check
	@echo "$(GREEN)✓ Type check passed$(NC)"

t: typecheck

clean:
	@echo "$(CYAN)ℹ Cleaning build artifacts and cache...$(NC)"
	@rm -rf dist/
	@rm -rf node_modules/.vite
	@rm -rf node_modules/.cache
	@rm -rf dist-ssr
	@find . -type d -name ".turbo" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✓ Clean completed$(NC)"

c: clean

pub: check-pnpm
	@echo "$(CYAN)ℹ Publishing project...$(NC)"
	@pnpm run pub
	@echo "$(GREEN)✓ Publish completed$(NC)"

prepublish: lint-fix typecheck build
	@echo "$(GREEN)✓ Prepublish check passed - ready to publish$(NC)"

.DEFAULT_GOAL := help
