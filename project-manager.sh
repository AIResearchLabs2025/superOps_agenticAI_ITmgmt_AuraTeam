#!/bin/bash
# Project Management Script for SuperOps Agentic AI IT Management - Aura Team
# This script provides convenient commands for managing the full-stack application

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

show_help() {
    echo "SuperOps Agentic AI IT Management - Project Manager"
    echo ""
    echo "Usage: ./project-manager.sh [command]"
    echo ""
    echo "Frontend Commands:"
    echo "  start                 Start the frontend development server"
    echo "  build                 Build the frontend for production"
    echo "  test                  Run frontend tests"
    echo "  lint                  Run frontend linting"
    echo "  install-frontend      Install frontend dependencies"
    echo ""
    echo "Backend Commands:"
    echo "  install-backend       Install backend dependencies"
    echo "  test-backend          Run backend tests"
    echo "  lint-backend          Run backend linting"
    echo ""
    echo "Full Stack Commands:"
    echo "  install-all           Install all dependencies (frontend + backend)"
    echo "  test-all              Run all tests (frontend + backend)"
    echo "  lint-all              Run all linting (frontend + backend)"
    echo "  clean                 Clean all build artifacts and dependencies"
    echo ""
    echo "Docker Commands:"
    echo "  dev-start             Start local development environment with Docker"
    echo "  dev-stop              Stop local development environment"
    echo "  dev-restart           Restart local development environment"
    echo "  dev-logs              Show logs from development environment"
    echo "  dev-clean             Clean Docker containers and volumes"
    echo ""
    echo "Deployment Commands:"
    echo "  deploy-dev            Deploy to AWS development environment"
    echo "  deploy-staging        Deploy to AWS staging environment"
    echo "  deploy-prod           Deploy to AWS production environment"
    echo ""
    echo "Utility Commands:"
    echo "  health                Check health of running services"
    echo "  setup                 Complete setup (install + start dev environment)"
    echo "  env-check             Check environment prerequisites"
    echo "  help                  Show this help message"
}

# Frontend commands
cmd_start() {
    print_header "Starting Frontend Development Server"
    cd aura-frontend && npm start
}

cmd_build() {
    print_header "Building Frontend for Production"
    cd aura-frontend && npm run build
}

cmd_test() {
    print_header "Running Frontend Tests"
    cd aura-frontend && npm test -- --watchAll=false
}

cmd_lint() {
    print_header "Running Frontend Linting"
    cd aura-frontend && npm run lint 2>/dev/null || echo "Lint script not configured in frontend package.json"
}

cmd_install_frontend() {
    print_header "Installing Frontend Dependencies"
    cd aura-frontend && npm install
}

# Backend commands
cmd_install_backend() {
    print_header "Installing Backend Dependencies"
    cd aura-backend
    python -m pip install -r api-gateway/requirements.txt
    python -m pip install -r service-desk-host/requirements.txt
}

cmd_test_backend() {
    print_header "Running Backend Tests"
    cd aura-backend && python -m pytest
}

cmd_lint_backend() {
    print_header "Running Backend Linting"
    cd aura-backend
    flake8 . || print_warning "flake8 not installed or failed"
    black --check . || print_warning "black not installed or failed"
    isort --check-only . || print_warning "isort not installed or failed"
}

# Full stack commands
cmd_install_all() {
    print_header "Installing All Dependencies"
    cmd_install_frontend
    cmd_install_backend
}

cmd_test_all() {
    print_header "Running All Tests"
    cmd_test
    cmd_test_backend
}

cmd_lint_all() {
    print_header "Running All Linting"
    cmd_lint
    cmd_lint_backend
}

cmd_clean() {
    print_header "Cleaning All Build Artifacts"
    print_status "Cleaning frontend..."
    cd aura-frontend && rm -rf node_modules build
    cd ..
    print_status "Cleaning backend..."
    cd aura-backend && find . -type d -name '__pycache__' -delete && find . -name '*.pyc' -delete
    cd ..
    print_status "Cleaning Docker..."
    docker system prune -f && docker volume prune -f
}

# Docker commands
cmd_dev_start() {
    print_header "Starting Local Development Environment"
    docker-compose -f deploy/environments/local/docker-compose.yml up -d
}

cmd_dev_stop() {
    print_header "Stopping Local Development Environment"
    docker-compose -f deploy/environments/local/docker-compose.yml down
}

cmd_dev_restart() {
    print_header "Restarting Local Development Environment"
    cmd_dev_stop
    cmd_dev_start
}

cmd_dev_logs() {
    print_header "Showing Development Environment Logs"
    docker-compose -f deploy/environments/local/docker-compose.yml logs -f
}

cmd_dev_clean() {
    print_header "Cleaning Development Environment"
    docker-compose -f deploy/environments/local/docker-compose.yml down -v
    docker system prune -f
}

# Deployment commands
cmd_deploy_dev() {
    print_header "Deploying to AWS Development Environment"
    ./deploy/scripts/deploy.sh dev aws backend
}

cmd_deploy_staging() {
    print_header "Deploying to AWS Staging Environment"
    ./deploy/scripts/deploy.sh staging aws fullstack
}

cmd_deploy_prod() {
    print_header "Deploying to AWS Production Environment"
    ./deploy/scripts/deploy.sh prod aws fullstack
}

# Utility commands
cmd_health() {
    print_header "Checking Service Health"
    curl -s http://localhost:8000/health && echo ""
    curl -s http://localhost:8001/health && echo ""
}

cmd_setup() {
    print_header "Complete Project Setup"
    cmd_install_all
    cmd_dev_start
}

cmd_env_check() {
    print_header "Checking Environment Prerequisites"
    echo "Node.js version:"
    node --version
    echo "NPM version:"
    npm --version
    echo "Python version:"
    python --version
    echo "Docker version:"
    docker --version
}

# Main command dispatcher
case "${1:-help}" in
    "start")
        cmd_start
        ;;
    "build")
        cmd_build
        ;;
    "test")
        cmd_test
        ;;
    "lint")
        cmd_lint
        ;;
    "install-frontend")
        cmd_install_frontend
        ;;
    "install-backend")
        cmd_install_backend
        ;;
    "test-backend")
        cmd_test_backend
        ;;
    "lint-backend")
        cmd_lint_backend
        ;;
    "install-all")
        cmd_install_all
        ;;
    "test-all")
        cmd_test_all
        ;;
    "lint-all")
        cmd_lint_all
        ;;
    "clean")
        cmd_clean
        ;;
    "dev-start")
        cmd_dev_start
        ;;
    "dev-stop")
        cmd_dev_stop
        ;;
    "dev-restart")
        cmd_dev_restart
        ;;
    "dev-logs")
        cmd_dev_logs
        ;;
    "dev-clean")
        cmd_dev_clean
        ;;
    "deploy-dev")
        cmd_deploy_dev
        ;;
    "deploy-staging")
        cmd_deploy_staging
        ;;
    "deploy-prod")
        cmd_deploy_prod
        ;;
    "health")
        cmd_health
        ;;
    "setup")
        cmd_setup
        ;;
    "env-check")
        cmd_env_check
        ;;
    "help"|*)
        show_help
        ;;
esac
