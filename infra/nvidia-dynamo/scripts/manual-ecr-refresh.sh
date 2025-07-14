#!/bin/bash

#---------------------------------------------------------------
# Manual ECR Token Refresh Script
#
# This script manually refreshes ECR tokens for both docker-imagepullsecret
# and dynamo-regcred secrets. Use this for testing or emergency refresh.
#
# Usage:
#   ./manual-ecr-refresh.sh [namespace]
#
# Examples:
#   ./manual-ecr-refresh.sh                    # Uses dynamo-cloud namespace
#   ./manual-ecr-refresh.sh my-namespace       # Uses custom namespace
#---------------------------------------------------------------

set -euo pipefail

# Script directory and environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLUEPRINT_DIR="$(cd "${SCRIPT_DIR}/../../blueprints/inference/nvidia-dynamo" && pwd)"
ENV_FILE="${BLUEPRINT_DIR}/dynamo_env.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Utility functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_banner() {
    local title="$1"
    local width=80
    local line=$(printf '%*s' "$width" | tr ' ' '=')
    
    echo -e "\n${BLUE}${line}${NC}"
    echo -e "${BLUE}$(printf '%*s' $(( (width - ${#title}) / 2 )) '')${title}${NC}"
    echo -e "${BLUE}${line}${NC}\n"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install kubectl if not present
install_kubectl() {
    if ! command_exists kubectl; then
        warn "kubectl not found, attempting to install..."

        # Detect OS and architecture
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        ARCH=$(uname -m)
        case $ARCH in
            x86_64) ARCH="amd64" ;;
            aarch64) ARCH="arm64" ;;
            armv7l) ARCH="arm" ;;
        esac

        # Download and install kubectl
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"

        info "Downloading kubectl ${KUBECTL_VERSION} for ${OS}/${ARCH}..."

        if command_exists curl; then
            curl -LO "${KUBECTL_URL}"
        elif command_exists wget; then
            wget "${KUBECTL_URL}"
        else
            error "Neither curl nor wget found. Cannot download kubectl."
            error "Please install kubectl manually: https://kubernetes.io/docs/tasks/tools/"
            return 1
        fi

        chmod +x kubectl

        # Try to move to system path, fallback to local directory
        if sudo mv kubectl /usr/local/bin/ 2>/dev/null; then
            success "kubectl installed to /usr/local/bin/"
        elif mv kubectl ~/bin/ 2>/dev/null; then
            success "kubectl installed to ~/bin/"
            export PATH="$HOME/bin:$PATH"
        else
            warn "Could not install kubectl to system path. Using local copy."
            export PATH="$(pwd):$PATH"
        fi

        # Verify installation
        if command_exists kubectl; then
            success "kubectl installation successful"
        else
            error "kubectl installation failed"
            return 1
        fi
    fi
}

print_banner "MANUAL ECR TOKEN REFRESH"

# Load environment configuration if available
if [ -f "${ENV_FILE}" ]; then
    source "${ENV_FILE}"
    info "Loaded environment configuration from ${ENV_FILE}"
else
    warn "Environment file not found: ${ENV_FILE}"
    warn "Using default values"
fi

# Set namespace
NAMESPACE="${1:-${NAMESPACE:-dynamo-cloud}}"
info "Using namespace: ${NAMESPACE}"

# Check prerequisites
section "Prerequisites Check"

# Install kubectl if needed
install_kubectl

if ! command_exists aws; then
    error "AWS CLI not found. Please install AWS CLI."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    error "AWS credentials not configured or invalid."
    error "Please configure AWS credentials using 'aws configure' or environment variables."
    exit 1
fi

# Get AWS account and region info
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "us-west-2")

if [ -z "${AWS_ACCOUNT_ID}" ]; then
    error "Could not determine AWS account ID"
    exit 1
fi

info "AWS Account ID: ${AWS_ACCOUNT_ID}"
info "AWS Region: ${AWS_REGION}"

# Check kubectl context
if ! kubectl cluster-info >/dev/null 2>&1; then
    error "kubectl not connected to a cluster"
    error "Please configure kubectl to connect to your EKS cluster"
    exit 1
fi

success "Prerequisites check passed"

# Check if namespace exists
section "Namespace Check"

if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    error "Namespace '${NAMESPACE}' not found"
    error "Available namespaces:"
    kubectl get namespaces --no-headers | awk '{print "  - " $1}'
    exit 1
fi

success "Namespace '${NAMESPACE}' exists"

# Refresh ECR tokens
section "ECR Token Refresh"

ECR_SERVER="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
info "ECR Server: ${ECR_SERVER}"

# Get fresh ECR token
info "Fetching fresh ECR authorization token..."
ECR_TOKEN=$(aws ecr get-login-password --region "${AWS_REGION}")

if [ -z "$ECR_TOKEN" ]; then
    error "Failed to get ECR authorization token"
    exit 1
fi

success "ECR token retrieved successfully"

# Create base64 encoded auth string
AUTH_STRING=$(echo -n "AWS:${ECR_TOKEN}" | base64 -w 0)

# Create docker config JSON
DOCKER_CONFIG_JSON=$(cat <<EOF
{
  "auths": {
    "${ECR_SERVER}": {
      "username": "AWS",
      "password": "${ECR_TOKEN}",
      "auth": "${AUTH_STRING}"
    }
  }
}
EOF
)

# Base64 encode the entire docker config
DOCKER_CONFIG_B64=$(echo -n "$DOCKER_CONFIG_JSON" | base64 -w 0)

# Update docker-imagepullsecret
info "Updating docker-imagepullsecret..."
if kubectl get secret docker-imagepullsecret -n "${NAMESPACE}" >/dev/null 2>&1; then
    kubectl patch secret docker-imagepullsecret -n "${NAMESPACE}" -p "{\"data\":{\".dockerconfigjson\":\"$DOCKER_CONFIG_B64\"}}"
    success "docker-imagepullsecret updated successfully"
else
    warn "docker-imagepullsecret not found in namespace ${NAMESPACE}, skipping"
fi

# Update dynamo-regcred
info "Updating dynamo-regcred..."
if kubectl get secret dynamo-regcred -n "${NAMESPACE}" >/dev/null 2>&1; then
    kubectl patch secret dynamo-regcred -n "${NAMESPACE}" -p "{\"data\":{\".dockerconfigjson\":\"$DOCKER_CONFIG_B64\"}}"
    success "dynamo-regcred updated successfully"
else
    warn "dynamo-regcred not found in namespace ${NAMESPACE}, skipping"
fi

success "ECR token refresh completed successfully!"

# Show secret status
section "Secret Status"

info "Current secrets in namespace ${NAMESPACE}:"
kubectl get secrets -n "${NAMESPACE}" | grep -E "(docker-imagepullsecret|dynamo-regcred)" || echo "  No ECR secrets found"

echo ""
info "Token refresh completed. ECR tokens are now valid for the next 12 hours."
info "The CronJob will automatically refresh them every 6 hours."
