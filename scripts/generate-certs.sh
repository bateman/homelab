#!/bin/bash
# =============================================================================
# generate-certs.sh — Generate CA-signed certificates for Traefik
#
# Creates a private Root CA and uses it to sign a wildcard certificate
# for *.home.local. Devices only need to trust the CA once — server
# certificates can be rotated freely without re-importing.
#
# Also generates an Apple .mobileconfig profile for one-tap CA import
# on iOS, iPadOS, and macOS.
#
# Usage:
#   ./scripts/generate-certs.sh              # Generate CA (if missing) + server cert
#   ./scripts/generate-certs.sh --dry-run    # Preview without changes
#   ./scripts/generate-certs.sh --force-ca   # Regenerate CA (devices must re-trust)
# =============================================================================

set -euo pipefail

# Configuration
CERT_DIR="./docker/config/traefik/certs"
CERT_PAGE_DIR="./docker/config/cert-page"
DOMAIN="home.local"
CA_DAYS=3650       # 10 years for CA
SERVER_DAYS=825    # ~2 years for server cert (Apple max)
KEY_SIZE=4096

# Output colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
DRY_RUN=false
FORCE_CA=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
        --force-ca) FORCE_CA=true ;;
        -h|--help)
            echo "Usage: $(basename "$0") [--dry-run] [--force-ca]"
            echo ""
            echo "  --dry-run    Preview without making changes"
            echo "  --force-ca   Regenerate the Root CA (devices must re-trust)"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY-RUN] No changes will be made${NC}"
fi

echo "=============================================="
echo " CA-signed certificate generation"
echo " Domain: *.${DOMAIN}"
echo "=============================================="
echo

# Verify openssl
if ! command -v openssl >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] openssl not found. Install it before continuing.${NC}"
    exit 1
fi

# Create directories
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$CERT_DIR"
    mkdir -p "$CERT_PAGE_DIR"
    # Verify the directory is writable
    if ! touch "$CERT_DIR/.write_test" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Cannot write to $CERT_DIR"
        echo "       Fix with: sudo chown -R \$(whoami) $CERT_DIR"
        exit 1
    fi
    rm -f "$CERT_DIR/.write_test"
    echo -e "${GREEN}[OK]${NC} Directories created/verified"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would create directories $CERT_DIR and $CERT_PAGE_DIR"
fi

# File paths
CA_KEY="$CERT_DIR/ca.key"
CA_CERT="$CERT_DIR/ca.crt"
SERVER_KEY="$CERT_DIR/${DOMAIN}.key"
SERVER_CERT="$CERT_DIR/${DOMAIN}.crt"
SERVER_CSR="$CERT_DIR/${DOMAIN}.csr"
MOBILECONFIG="$CERT_PAGE_DIR/homelab.mobileconfig"

# =========================================================================
# Step 1: Root CA
# =========================================================================

GENERATE_CA=false
if [ "$FORCE_CA" = true ]; then
    echo -e "${YELLOW}[WARN]${NC} --force-ca: CA will be regenerated. All devices must re-trust it."
    GENERATE_CA=true
elif [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CERT" ]; then
    echo "No existing CA found. Generating new Root CA..."
    GENERATE_CA=true
elif ! openssl x509 -noout -in "$CA_CERT" 2>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} Existing CA certificate is invalid. Regenerating..."
    GENERATE_CA=true
else
    echo -e "${GREEN}[OK]${NC} Existing Root CA is valid (not regenerating)"
    EXPIRY=$(openssl x509 -enddate -noout -in "$CA_CERT" 2>/dev/null | cut -d= -f2)
    echo "       Expires: $EXPIRY"
fi

if [ "$GENERATE_CA" = true ]; then
    if [ "$DRY_RUN" = false ]; then
        echo "Generating Root CA private key (${KEY_SIZE} bit)..."
        openssl genrsa -out "$CA_KEY" "$KEY_SIZE" 2>/dev/null
        chmod 600 "$CA_KEY"
        echo -e "${GREEN}[OK]${NC} CA key: $CA_KEY"

        echo "Generating Root CA certificate (valid for ${CA_DAYS} days)..."

        # Use a config file for CA extensions (compatible with OpenSSL 1.0.x+)
        CA_CNF=$(mktemp)
        cat > "$CA_CNF" << EOF
[req]
default_bits = ${KEY_SIZE}
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_ca

[dn]
C = IT
ST = Italia
L = Home
O = Homelab
OU = Infrastructure
CN = Homelab Root CA

[v3_ca]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
EOF

        openssl req -new -x509 \
            -key "$CA_KEY" \
            -out "$CA_CERT" \
            -days "$CA_DAYS" \
            -config "$CA_CNF" \
            2>/dev/null
        rm -f "$CA_CNF"
        chmod 644 "$CA_CERT"
        echo -e "${GREEN}[OK]${NC} CA cert: $CA_CERT"
    else
        echo -e "${YELLOW}[DRY-RUN]${NC} Would generate Root CA key and certificate"
    fi
fi

echo

# =========================================================================
# Step 2: Server certificate (signed by CA)
# =========================================================================

echo "Generating server certificate for *.${DOMAIN}..."

# OpenSSL config for server cert extensions
OPENSSL_EXT=$(mktemp)
cat > "$OPENSSL_EXT" << EOF
[v3_ext]
authorityKeyIdentifier = keyid,issuer
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.${DOMAIN}
DNS.2 = ${DOMAIN}
EOF

if [ "$DRY_RUN" = false ]; then
    # Generate server key
    openssl genrsa -out "$SERVER_KEY" "$KEY_SIZE" 2>/dev/null
    chmod 600 "$SERVER_KEY"
    echo -e "${GREEN}[OK]${NC} Server key: $SERVER_KEY"

    # Generate CSR
    openssl req -new \
        -key "$SERVER_KEY" \
        -out "$SERVER_CSR" \
        -subj "/C=IT/ST=Italia/L=Home/O=Homelab/OU=Infrastructure/CN=*.${DOMAIN}" \
        2>/dev/null

    # Sign with CA
    openssl x509 -req \
        -in "$SERVER_CSR" \
        -CA "$CA_CERT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -out "$SERVER_CERT" \
        -days "$SERVER_DAYS" \
        -extfile "$OPENSSL_EXT" \
        -extensions v3_ext \
        2>/dev/null
    chmod 644 "$SERVER_CERT"
    echo -e "${GREEN}[OK]${NC} Server cert: $SERVER_CERT (signed by CA)"

    # Cleanup temporary files
    rm -f "$SERVER_CSR" "$CERT_DIR/ca.srl"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would generate server key, CSR, and CA-signed certificate"
fi

rm -f "$OPENSSL_EXT"

echo

# =========================================================================
# Step 3: Verify certificate chain
# =========================================================================

if [ "$DRY_RUN" = false ]; then
    echo "Verifying certificate chain..."
    if openssl verify -CAfile "$CA_CERT" "$SERVER_CERT" >/dev/null 2>&1; then
        echo -e "${GREEN}[OK]${NC} Certificate chain is valid"
    else
        echo -e "${RED}[ERROR]${NC} Certificate chain verification failed!"
        exit 1
    fi

    EXPIRY=$(openssl x509 -enddate -noout -in "$SERVER_CERT" 2>/dev/null | cut -d= -f2)
    echo "       Server cert expires: $EXPIRY"
fi

echo

# =========================================================================
# Step 4: Apple .mobileconfig profile
# =========================================================================

echo "Generating Apple configuration profile..."

if [ "$DRY_RUN" = false ]; then
    # Read CA cert as base64 (strip PEM headers)
    CA_CERT_B64=$(sed '/-----/d' "$CA_CERT" | tr -d '\n')

    # Generate stable UUIDs from CA cert fingerprint (deterministic)
    FINGERPRINT=$(openssl x509 -fingerprint -noout -sha256 -in "$CA_CERT" 2>/dev/null | cut -d= -f2 | tr -d ':')
    # Use parts of the fingerprint to create UUID-like strings
    UUID_PAYLOAD=$(echo "$FINGERPRINT" | cut -c1-8)-$(echo "$FINGERPRINT" | cut -c9-12)-4$(echo "$FINGERPRINT" | cut -c14-16)-a$(echo "$FINGERPRINT" | cut -c18-20)-$(echo "$FINGERPRINT" | cut -c21-32)
    UUID_ROOT=$(echo "$FINGERPRINT" | cut -c33-40)-$(echo "$FINGERPRINT" | cut -c41-44)-4$(echo "$FINGERPRINT" | cut -c45-47)-b$(echo "$FINGERPRINT" | cut -c48-50)-$(echo "$FINGERPRINT" | cut -c51-62)

    cat > "$MOBILECONFIG" << XMLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadCertificateFileName</key>
            <string>Homelab Root CA</string>
            <key>PayloadContent</key>
            <data>${CA_CERT_B64}</data>
            <key>PayloadDescription</key>
            <string>Adds the Homelab Root CA to enable trusted HTTPS for *.home.local services.</string>
            <key>PayloadDisplayName</key>
            <string>Homelab Root CA</string>
            <key>PayloadIdentifier</key>
            <string>com.homelab.ca.cert</string>
            <key>PayloadType</key>
            <string>com.apple.security.root</string>
            <key>PayloadUUID</key>
            <string>${UUID_PAYLOAD}</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
    </array>
    <key>PayloadDescription</key>
    <string>Installs the Homelab Root CA so your device trusts all *.home.local services without certificate warnings.</string>
    <key>PayloadDisplayName</key>
    <string>Homelab CA Certificate</string>
    <key>PayloadIdentifier</key>
    <string>com.homelab.ca</string>
    <key>PayloadOrganization</key>
    <string>Homelab</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>${UUID_ROOT}</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
    <key>ConsentText</key>
    <dict>
        <key>default</key>
        <string>This profile installs the Homelab Root CA certificate. After installation, go to Settings → General → About → Certificate Trust Settings and enable full trust for the Homelab Root CA.</string>
    </dict>
</dict>
</plist>
XMLEOF
    chmod 644 "$MOBILECONFIG"
    echo -e "${GREEN}[OK]${NC} Apple profile: $MOBILECONFIG"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would generate Apple .mobileconfig profile"
fi

echo

# =========================================================================
# Step 5: Copy CA cert to download page directory
# =========================================================================

if [ "$DRY_RUN" = false ]; then
    cp "$CA_CERT" "$CERT_PAGE_DIR/ca.crt"
    echo -e "${GREEN}[OK]${NC} CA cert copied to $CERT_PAGE_DIR/ca.crt"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Would copy CA cert to $CERT_PAGE_DIR/ca.crt"
fi

echo
echo "=============================================="
echo -e "${GREEN} Certificates generated successfully!${NC}"
echo "=============================================="
echo
echo "Generated files:"
echo "  CA (import on devices):"
echo "    - $CA_KEY (private key — keep secure!)"
echo "    - $CA_CERT (distribute to devices)"
echo "  Server (used by Traefik):"
echo "    - $SERVER_KEY (private key)"
echo "    - $SERVER_CERT (certificate)"
echo "  Apple profile:"
echo "    - $MOBILECONFIG (for iOS/iPadOS/macOS)"
echo
echo "Next steps:"
echo "  1. Restart Traefik: make restart s=traefik"
echo "  2. Add DNS record: certs.home.local → 192.168.3.10"
echo "  3. Open https://certs.home.local on each device to install the CA"
echo
echo -e "${YELLOW}NOTE:${NC} The first visit to certs.home.local will show a warning."
echo "      Click through it once, install the CA, and all warnings disappear."
echo
