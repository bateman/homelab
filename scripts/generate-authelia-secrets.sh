#!/usr/bin/env bash
# =============================================================================
# Generate Authelia Secrets
# =============================================================================
# Creates cryptographically secure secrets for Authelia:
#   - JWT_SECRET: For password reset tokens
#   - SESSION_SECRET: For session encryption
#   - STORAGE_ENCRYPTION_KEY: For database encryption
#
# Usage:
#   ./scripts/generate-authelia-secrets.sh
#   ./scripts/generate-authelia-secrets.sh --force  # Overwrite existing
# =============================================================================

set -euo pipefail

# Script directory (for relative paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_DIR="${SCRIPT_DIR}/../docker/secrets/authelia"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse command line arguments
FORCE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Generate Authelia secrets for JWT, session, and storage encryption."
            echo ""
            echo "OPTIONS:"
            echo "    -f, --force    Overwrite existing secrets"
            echo "    -h, --help     Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create secrets directory if it doesn't exist
if [[ ! -d "$SECRETS_DIR" ]]; then
    log_info "Creating secrets directory: $SECRETS_DIR"
    mkdir -p "$SECRETS_DIR"
fi

# Function to generate a secret
generate_secret() {
    local name=$1
    local file="${SECRETS_DIR}/${name}"
    local length=${2:-64}

    if [[ -f "$file" && "$FORCE" != true ]]; then
        log_warn "$name already exists. Use --force to overwrite."
        return 0
    fi

    log_info "Generating $name..."
    openssl rand -base64 "$length" | tr -d '\n' > "$file"
    chmod 600 "$file"
    log_info "Created: $file"
}

echo "=== Generating Authelia Secrets ==="
echo ""

# Generate all required secrets
generate_secret "JWT_SECRET" 64
generate_secret "SESSION_SECRET" 64
generate_secret "STORAGE_ENCRYPTION_KEY" 64

echo ""
log_info "=== Secrets generated successfully ==="
echo ""

# Set permissions
chmod 700 "$SECRETS_DIR"
log_info "Set directory permissions to 700 (owner only)"

echo ""
echo "============================================================================="
echo "                              NEXT STEPS"
echo "============================================================================="
echo ""
echo "1. EDIT YOUR USER in docker/config/authelia/users_database.yml"
echo "   -----------------------------------------------------------------------------"
echo "   Generate a password hash:"
echo "     docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'YOUR_PASSWORD'"
echo ""
echo "   Replace the default 'admin' user with your details."
echo ""
echo "2. ADD DNS RECORD in Pi-hole"
echo "   -----------------------------------------------------------------------------"
echo "   Local DNS -> DNS Records:"
echo "     auth.home.local -> 192.168.3.10"
echo ""
echo "3. START THE STACK"
echo "   -----------------------------------------------------------------------------"
echo "   make up"
echo ""
echo "4. REGISTER YOUR PASSKEY"
echo "   -----------------------------------------------------------------------------"
echo "   - Access https://auth.home.local"
echo "   - Login with your username and password"
echo "   - Go to Settings -> Security Keys"
echo "   - Click 'Add' and follow the prompts to register your passkey"
echo ""
echo "============================================================================="
