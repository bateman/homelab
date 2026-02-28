# Authelia Setup - SSO with Passkey/WebAuthn

> Single Sign-On authentication for all homelab services with passkey support

---

## Overview

Authelia provides centralized authentication for all services behind Traefik. Instead of managing separate logins for each application, you authenticate once and access everything.

### Key Features

| Feature | Description |
|---------|-------------|
| **Passkey/WebAuthn** | Login with Touch ID, Face ID, Windows Hello, or hardware keys |
| **Single Sign-On** | One login for all services |
| **Generous Sessions** | 7-day expiration, 3-day inactivity timeout |
| **Two-Factor** | TOTP backup for critical services (Portainer, Traefik) |
| **API Bypass** | *arr apps inter-service communication works without auth |

### How It Works

```
User Request                      Protected Service
     │                                   │
     ▼                                   │
┌─────────┐    ┌──────────────┐         │
│ Traefik │───►│   Authelia   │         │
└─────────┘    │  (verify)    │         │
     │         └──────┬───────┘         │
     │                │                  │
     │         ┌──────▼───────┐         │
     │         │ Authenticated?│         │
     │         └──────┬───────┘         │
     │                │                  │
     │           YES  │  NO              │
     │                │   │              │
     │                ▼   ▼              │
     │           ┌─────────────┐        │
     │           │ Login Portal│        │
     │           │ + Passkey   │        │
     │           └─────────────┘        │
     │                │                  │
     └────────────────┴──────────────────┘
```

---

## Prerequisites

- [ ] Docker stack running (`make up` works)
- [ ] Traefik configured and accessible
- [ ] Pi-hole DNS working

---

## Phase 1: Generate Secrets

Authelia requires cryptographic secrets for JWT, sessions, and storage encryption. `make setup` generates these automatically, but you can also run the script manually:

```bash
# Generate all required secrets (already done by make setup)
./scripts/generate-authelia-secrets.sh

# Verify secrets were created
ls -la docker/secrets/authelia/
# Should show: JWT_SECRET, SESSION_SECRET, STORAGE_ENCRYPTION_KEY
```

---

## Phase 2: Create Your User

Edit the users database to add your account:

```bash
# Generate password hash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YOUR_SECURE_PASSWORD'

# Copy the output hash (starts with $argon2id$...)
```

Edit `docker/config/authelia/users_database.yml`:

```yaml
users:
  yourname:
    disabled: false
    displayname: "Your Name"
    password: "$argon2id$v=19$m=65536,t=3,p=4$..."  # Paste hash here
    email: you@example.com
    groups:
      - admins
      - users
```

> [!WARNING]
> The default user `admin` with password `changeme` is for initial setup only.
> Delete or disable it after creating your own account.

---

## Phase 3: Add DNS Record

In Pi-hole (http://192.168.3.10:8081):

**Local DNS → DNS Records**, add:

| Domain | IP |
|--------|-----|
| `auth.home.local` | 192.168.3.10 |

---

## Phase 4: Start Services

```bash
# Recreate stack with Authelia
make down && make up

# Verify Authelia is running
docker logs authelia

# Check health
docker ps | grep authelia
# Should show: healthy
```

---

## Phase 5: Register Your Passkey

1. Access https://auth.home.local
2. Login with your username and password
3. You'll see the Authelia dashboard
4. Go to **Settings** (gear icon) → **Security Keys**
5. Click **Add**
6. Follow the browser prompt to register your passkey:
   - **Mac**: Touch ID or Apple Watch
   - **Windows**: Windows Hello (fingerprint, face, PIN)
   - **Mobile**: Fingerprint or Face ID
   - **Hardware Key**: YubiKey, etc.

> [!TIP]
> Register multiple passkeys (e.g., laptop + phone + hardware key) for redundancy.

---

## Access Control Policies

Services are protected with different security levels:

### Two-Factor Required (Password + TOTP/Passkey)

| Service | Reason |
|---------|--------|
| `portainer.home.local` | Full Docker control |
| `traefik.home.local` | Infrastructure access |

### One-Factor Required (Password OR Passkey)

| Service | Notes |
|---------|-------|
| All *arr apps | Sonarr, Radarr, Lidarr, etc. |
| qBittorrent, NZBGet | Download clients |
| Duplicati | Backup management |
| Uptime Kuma | Monitoring |
| Pi-hole | DNS admin |

### Bypass (No Auth)

| Pattern | Reason |
|---------|--------|
| `/api/*` | Inter-service API calls |
| `/ping`, `/health` | Health checks |

---

## Session Configuration

Sessions are configured for homelab convenience:

| Setting | Value | Description |
|---------|-------|-------------|
| Expiration | 7 days | Max session lifetime |
| Inactivity | 3 days | Logout after inactivity |
| Remember Me | 30 days | When checkbox is selected |

To adjust these values, edit `docker/config/authelia/configuration.yml`:

```yaml
session:
  expiration: 7d      # Change to 1d for stricter security
  inactivity: 3d      # Change to 1h for stricter security
  remember_me: 30d    # Change to 7d for stricter security
```

After editing, restart Authelia:

```bash
docker restart authelia
```

---

## Adding TOTP as Backup

If your passkey is unavailable, you can use TOTP (Google Authenticator, etc.):

1. Access https://auth.home.local
2. Login with password
3. Go to **Settings** → **One-Time Password**
4. Click **Add**
5. Scan QR code with your authenticator app

---

## Troubleshooting

### "Access Denied" after login

```bash
# Check Authelia logs
docker logs authelia --tail 50

# Common causes:
# - Domain mismatch (check session.cookies.domain in config)
# - User not in correct group
# - Policy misconfiguration
```

### Passkey not working

```bash
# Verify WebAuthn is enabled
grep -A 5 "webauthn:" docker/config/authelia/configuration.yml

# Check browser console for errors
# Common causes:
# - Not using HTTPS
# - Domain mismatch
# - Browser doesn't support WebAuthn
```

### Services not protected

```bash
# Verify middleware is applied
docker logs traefik | grep authelia

# Check service labels include:
# traefik.http.routers.<service>.middlewares=authelia@docker
```

### API calls failing

The configuration includes bypass rules for API endpoints. If an app's API isn't working:

```yaml
# In configuration.yml, add to access_control.rules:
- domain: "*.home.local"
  policy: bypass
  resources:
    - "^/api/.*$"
    - "^/your-app-specific-endpoint.*$"
```

### Reset user password

```bash
# Generate new hash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'NEW_PASSWORD'

# Update users_database.yml with new hash
# Restart Authelia
docker restart authelia
```

---

## Security Considerations

### What's Protected

- All WebUI access **via Traefik** (e.g., `https://sonarr.home.local`) requires authentication
- Passkeys provide phishing-resistant 2FA
- Sessions are encrypted and time-limited

### What's NOT Protected

Authelia is a Traefik middleware — it only sees requests that go through Traefik. Anything that bypasses Traefik bypasses Authelia:

- **Direct port access** (e.g., `http://192.168.3.10:8989`) — requests go straight to the container, never touching Traefik or Authelia. This is why each *arr app still needs its own username/password as a fallback.
- **API endpoints** (`/api/*`, `/ping`, `/health`) — intentionally bypassed so *arr services can communicate with each other.
- **Home Assistant** — has its own robust auth; Authelia middleware is not applied to its Traefik route.

### Recommendations

1. **Use passkeys** instead of passwords when possible
2. **Register multiple passkeys** for redundancy
3. **Set up TOTP** as backup for passkey
4. **Review access logs** periodically in Authelia dashboard
5. **Keep sessions short** if accessing from shared devices

---

## File Reference

| File | Purpose |
|------|---------|
| `docker/config/authelia/configuration.yml` | Main Authelia config |
| `docker/config/authelia/users_database.yml` | User accounts and passwords |
| `docker/secrets/authelia/JWT_SECRET` | JWT signing key |
| `docker/secrets/authelia/SESSION_SECRET` | Session encryption key |
| `docker/secrets/authelia/STORAGE_ENCRYPTION_KEY` | Database encryption key |
| `scripts/generate-authelia-secrets.sh` | Secret generation script |

---

## Related Documentation

- [Reverse Proxy Setup](reverse-proxy-setup.md) - Traefik configuration
- [VPN Setup](vpn-setup.md) - Gluetun for download clients
- [Authelia Official Docs](https://www.authelia.com/configuration/)
