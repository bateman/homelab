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

### Default Login (Initial Setup Only)

> [!IMPORTANT]
> **Username:** `admin`
> **Password:** `changeme`
>
> Use these to log in for the first time, then replace with your own account below.

### Create Your Own Account

```bash
# Generate password hash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YOUR_SECURE_PASSWORD'

# Copy the output hash (starts with $argon2id$...)
```

Copy and edit the users database:

```bash
cp docker/config/authelia/users_database.yml.example docker/config/authelia/users_database.yml
```

Edit `docker/config/authelia/users_database.yml`:

```yaml
users:
  yourname:                                          # <-- this is your LOGIN username
    disabled: false
    displayname: "Your Name"                         # display only, NOT for login
    password: "$argon2id$v=19$m=65536,t=3,p=4$..."   # Paste hash here
    email: you@example.com
    groups:
      - admins
      - users
```

> [!CAUTION]
> The **YAML key** (e.g., `yourname`) is what you type at the login screen. The `displayname` field is cosmetic only — you cannot log in with it.

> [!WARNING]
> Delete or disable the default `admin` account after creating your own.

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

## Phase 6: Enable SSO for *arr Apps (Eliminate Double Login)

By default, *arr apps (Radarr, Sonarr, etc.) still show their own login form after Authelia authentication. This means you log in twice — once at Authelia, once at the app. To fix this, configure each app to trust Authelia's `Remote-User` header.

### Configure Each App

For **Radarr, Sonarr, Lidarr, Prowlarr, Bazarr** — repeat these steps in each app's WebUI:

1. Go to **Settings → General**
2. Scroll to the **Security** section
3. Change **Authentication Method** from `Forms (Login Page)` to `External`
4. Click **Save Changes**

> [!CAUTION]
> With "External" authentication, direct port access (e.g., `http://192.168.3.10:7878`) has **no authentication at all**. This is acceptable in a homelab where:
> - The NAS is on a trusted VLAN
> - Firewall rules block access from untrusted networks
> - All normal access goes through Traefik (`https://radarr.home.local`)
>
> If you need direct port access to remain protected, keep the app's auth set to `Forms` and accept the double login.

### Verify SSO Works

1. Clear your browser cookies for `home.local` (or open an incognito window)
2. Navigate to `https://radarr.home.local`
3. You should be redirected to Authelia login
4. After authenticating, you should land **directly** in Radarr — no second login

### Apps That Should NOT Use External Auth

| App | Reason |
|-----|--------|
| **Portainer** | Has its own user/role system; requires two-factor via Authelia anyway |
| **Pi-hole** | Simple admin password; not an *arr app |
| **Home Assistant** | Has its own robust auth system; not behind Authelia middleware |

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

### Bypass (No Auth)

| Pattern | Reason |
|---------|--------|
| `pihole.home.local` | Has built-in password |
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

### "User not found" on login

The most common cause is a mismatch between your login username and the YAML key in `users_database.yml`. Authelia uses the **YAML key** as the username, not the `displayname`:

```yaml
users:
  fabio:                    # <-- you must log in as "fabio"
    displayname: "Fabio"    # <-- this is NOT used for login
```

Other causes:
- **User is `disabled: true`** — check the `disabled` field
- **YAML indentation error** — use spaces, not tabs
- **File not mounted** — run `docker exec authelia cat /config/users_database.yml` to verify

### "Access Denied" after login

```bash
# Check Authelia logs
docker logs authelia --tail 50

# Common causes:
# - Domain mismatch (check session.cookies.domain in config)
# - User not in correct group
# - Policy misconfiguration
```

### Blank page after passkey authentication

After authenticating with a passkey, the browser may show a blank page instead of redirecting to the requested service. This is a known behavior with Authelia's WebAuthn flow — the JavaScript redirect sometimes fails to fire after the passkey ceremony completes.

**Workaround:** Refresh the page (F5). The session cookie is already set, so the refresh will complete the redirect to the original service.

This happens most often with:
- Passkey/WebAuthn authentication (less common with password login)
- First access after session expiry

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

- **Direct port access** (e.g., `http://192.168.3.10:8989`) — requests go straight to the container, never touching Traefik or Authelia. If you configured *arr apps with "External" auth (see [Phase 6](#phase-6-enable-sso-for-arr-apps-eliminate-double-login)), direct port access has **no authentication**. If you kept "Forms" auth, the app's own login protects direct access as a fallback.
- **API endpoints** (`/api/*`, `/ping`, `/health`, `/jsonrpc`, `/xmlrpc`) — intentionally bypassed so *arr services and NZBGet can communicate with each other and with mobile apps.
- **Home Assistant** — has its own robust auth; Authelia middleware is not applied to its Traefik route.
- **Cert Page** (`certs.home.local`) — intentionally unprotected so devices can download the CA certificate before authenticating.

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
| `docker/config/authelia/users_database.yml.example` | User accounts template (copy to `users_database.yml`) |
| `docker/config/authelia/users_database.yml` | Your user accounts and passwords (gitignored) |
| `docker/secrets/authelia/JWT_SECRET` | JWT signing key |
| `docker/secrets/authelia/SESSION_SECRET` | Session encryption key |
| `docker/secrets/authelia/STORAGE_ENCRYPTION_KEY` | Database encryption key |
| `scripts/generate-authelia-secrets.sh` | Secret generation script |

---

## Related Documentation

- [Reverse Proxy Setup](reverse-proxy-setup.md) - Traefik configuration
- [VPN Setup](vpn-setup.md) - Gluetun for download clients
- [Authelia Official Docs](https://www.authelia.com/configuration/)
