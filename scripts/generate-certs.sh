#!/bin/bash
# =============================================================================
# generate-certs.sh — Genera certificati self-signed per Traefik
#
# Crea un certificato wildcard per *.home.local usato da Traefik
# per abilitare HTTPS sui servizi interni.
#
# Usage:
#   ./scripts/generate-certs.sh
#   ./scripts/generate-certs.sh --dry-run
# =============================================================================

set -euo pipefail

# Configurazione
CERT_DIR="./docker/config/traefik/certs"
DOMAIN="home.local"
DAYS_VALID=3650  # 10 anni
KEY_SIZE=4096

# Colori output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parsing argomenti
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}[DRY-RUN] Nessuna modifica verrà effettuata${NC}"
fi

echo "=============================================="
echo " Generazione certificati self-signed"
echo " Dominio: *.${DOMAIN}"
echo "=============================================="
echo

# Verifica openssl
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}[ERRORE] openssl non trovato. Installalo prima di continuare.${NC}"
    exit 1
fi

# Crea directory se non esiste
if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$CERT_DIR"
    echo -e "${GREEN}[OK]${NC} Directory $CERT_DIR creata/verificata"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Creerei directory $CERT_DIR"
fi

# File certificati
KEY_FILE="$CERT_DIR/${DOMAIN}.key"
CERT_FILE="$CERT_DIR/${DOMAIN}.crt"

# Verifica se esistono già
if [[ -f "$KEY_FILE" && -f "$CERT_FILE" ]]; then
    echo -e "${YELLOW}[WARN]${NC} Certificati già esistenti:"
    echo "       $KEY_FILE"
    echo "       $CERT_FILE"

    # Mostra scadenza
    EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
    echo "       Scadenza: $EXPIRY"
    echo
    read -p "Vuoi rigenerarli? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operazione annullata."
        exit 0
    fi
fi

# Configurazione OpenSSL per SAN (Subject Alternative Names)
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

echo "Generazione chiave privata (${KEY_SIZE} bit)..."
if [[ "$DRY_RUN" == false ]]; then
    openssl genrsa -out "$KEY_FILE" "$KEY_SIZE" 2>/dev/null
    chmod 600 "$KEY_FILE"
    echo -e "${GREEN}[OK]${NC} Chiave privata: $KEY_FILE"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Genererei chiave privata: $KEY_FILE"
fi

echo "Generazione certificato (valido ${DAYS_VALID} giorni)..."
if [[ "$DRY_RUN" == false ]]; then
    openssl req -new -x509 \
        -key "$KEY_FILE" \
        -out "$CERT_FILE" \
        -days "$DAYS_VALID" \
        -config "$OPENSSL_CNF" \
        2>/dev/null
    chmod 644 "$CERT_FILE"
    echo -e "${GREEN}[OK]${NC} Certificato: $CERT_FILE"
else
    echo -e "${YELLOW}[DRY-RUN]${NC} Genererei certificato: $CERT_FILE"
fi

# Cleanup
rm -f "$OPENSSL_CNF"

echo
echo "=============================================="
echo -e "${GREEN} Certificati generati con successo!${NC}"
echo "=============================================="
echo
echo "File generati:"
echo "  - $KEY_FILE (chiave privata)"
echo "  - $CERT_FILE (certificato)"
echo
echo "Prossimi passi:"
echo "  1. Riavvia Traefik: make restart"
echo "  2. Accedi ai servizi via HTTPS (es. https://sonarr.home.local)"
echo "  3. Accetta il certificato self-signed nel browser (una tantum)"
echo
echo -e "${YELLOW}NOTA:${NC} I browser mostreranno un warning perché il certificato"
echo "      è self-signed. È normale e sicuro per uso interno."
echo
