#!/bin/bash
# =============================================================================
# generate-certs.sh — Generate self-signed certificates for Traefik
#
# Creates a wildcard certificate for *.home.local used by Traefik
# to enable HTTPS on internal services.
#
# Usage:
#   ./scripts/generate-certs.sh
#   ./scripts/generate-certs.sh --dry-run
# =============================================================================

set -euo pipefail

# Configuration
CERT_DIR="./docker/config/traefik/certs"
DOMAIN="home.local"
DAYS_VALID=3650  # 10 years
KEY_SIZE=4096

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}[DRY-RUN] No changes will be made${NC}"
fi

echo "=============================================="
echo " Self-signed certificate generation"
echo " Domain: *.${DOMAIN}"
echo "=============================================="
echo

# Verify openssl
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}[ERROR] openssl not found. Install it before continuing.${NC}"
    exit 1
fi

# Create directory if it doesn't exist
if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$CERT_DIR"
    echo -e "${GREEN}[OK]${NC} Directory $CERT_DIR created/verified"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would create directory $CERT_DIR"
fi

# Certificate files
KEY_FILE="$CERT_DIR/${DOMAIN}.key"
CERT_FILE="$CERT_DIR/${DOMAIN}.crt"

# Check if they already exist
if [[ -f "$KEY_FILE" && -f "$CERT_FILE" ]]; then
    echo -e "${YELLOW}[WARN]${NC} Certificates already exist:"
    echo "       $KEY_FILE"
    echo "       $CERT_FILE"

    # Show expiration
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
    echo "       Expires: $EXPIRY"
    echo
    read -p "Do you want to regenerate them? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# OpenSSL configuration for SAN (Subject Alternative Names)
OPENSSL_CNF=$(mktemp)
cat > "$OPENSSL_CNF" << EOF
[req]
default_bits = ${KEY_SIZE}
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_ext

[dn]
C = IT
ST = Italia
L = Home
O = Homelab
OU = Infrastructure
CN = *.${DOMAIN}

[v3_ext]
authorityKeyIdentifier = keyid,issuer
basicConstraints = CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${DOMAIN}
DNS.2 = ${DOMAIN}
EOF

echo "Generating private key (${KEY_SIZE} bit)..."
if [[ "$DRY_RUN" == false ]]; then
    openssl genrsa -out "$KEY_FILE" "$KEY_SIZE" 2>/dev/null
    chmod 600 "$KEY_FILE"
    echo -e "${GREEN}[OK]${NC} Private key: $KEY_FILE"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would generate private key: $KEY_FILE"
fi

echo "Generating certificate (valid for ${DAYS_VALID} days)..."
if [[ "$DRY_RUN" == false ]]; then
    openssl req -new -x509 \
        -key "$KEY_FILE" \
        -out "$CERT_FILE" \
        -days "$DAYS_VALID" \
        -config "$OPENSSL_CNF" \
        2>/dev/null
    chmod 644 "$CERT_FILE"
    echo -e "${GREEN}[OK]${NC} Certificate: $CERT_FILE"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would generate certificate: $CERT_FILE"
fi

# Cleanup
rm -f "$OPENSSL_CNF"

echo
echo "=============================================="
echo -e "${GREEN} Certificates generated successfully!${NC}"
echo "=============================================="
echo
echo "Generated files:"
echo "  - $KEY_FILE (private key)"
echo "  - $CERT_FILE (certificate)"
echo
echo "Next steps:"
echo "  1. Restart Traefik: make restart"
echo "  2. Access services via HTTPS (e.g., https://sonarr.home.local)"
echo "  3. Accept the self-signed certificate in your browser (one time)"
echo
echo -e "${YELLOW}NOTE:${NC} Browsers will show a warning because the certificate"
echo "      is self-signed. This is normal and safe for internal use."
echo
