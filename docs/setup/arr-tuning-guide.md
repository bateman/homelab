# *arr Tuning Guide — Trash Guides Best Practices

> Recommended settings for Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, and Cleanuparr

---

## Overview

This guide goes beyond the initial setup checklist in [nas-setup.md](nas-setup.md#arr-services-configuration) and explains **how and why** to tune each *arr app for optimal quality, automation, and maintenance.

It covers:

- **Trash Guides philosophy** — how quality profiles and custom formats work
- **Per-app recommended settings** — Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, Cleanuparr
- **Recyclarr customization** — adding profiles, overriding scores, useful commands
- **Troubleshooting** — common issues and how to debug them

> [!NOTE]
> **Prerequisites:** Complete the [NAS Deployment Checklist](nas-setup.md) first, including the initial *arr service configuration and at least one `make recyclarr-sync` run.

### What Recyclarr Manages vs Manual Tuning

| Managed by Recyclarr | Requires Manual Tuning |
|-----------------------|------------------------|
| Sonarr quality profiles & custom formats | Prowlarr indexer setup |
| Radarr quality profiles & custom formats | Lidarr quality & metadata |
| Media naming (Sonarr & Radarr) | Bazarr subtitle providers |
| Quality definitions (file sizes) | Cleanuparr cleanup rules |

---

## Trash Guides Philosophy

### Why Trash Guides?

[Trash Guides](https://trash-guides.info/) is the community standard for *arr app configuration. Instead of manually creating quality profiles and scoring rules, Trash Guides provides battle-tested presets maintained by the community and synced via [Recyclarr](https://recyclarr.dev/).

Key principles:

- **Custom formats** replaced the old "preferred words" system — they're more powerful and flexible
- **Scoring** determines which release wins when multiple are available
- **Automation** via Recyclarr keeps your profiles in sync with upstream changes

### How It Works

When a release appears on an indexer, the *arr app evaluates it:

```
Release appears on indexer
  → Quality check: is it within the profile's accepted qualities?
  → Custom Format matching: which patterns match the release name?
  → Score calculation: sum all matched custom format scores
  → Decision: highest-scoring release within acceptable quality wins
  → Upgrade check: is the new score higher than what's already in the library?
```

### Key Terminology

| Term | Meaning |
|------|---------|
| **Quality Profile** | Ordered list of acceptable qualities (e.g., WEB-DL 1080p, Bluray 1080p) with a cutoff |
| **Quality Definition** | Min/max/preferred file sizes per quality level |
| **Custom Format** | Pattern-matching rule applied to release names (e.g., "contains AMZN" → streaming service) |
| **Trash ID** | Unique identifier for a Trash Guides preset (quality profile or custom format) |
| **Score** | Points assigned when a custom format matches. Positive = preferred, negative = penalized, -10000 = rejected |
| **Cutoff** | The quality level at which the app stops looking for upgrades (unless CF scores push higher) |
| **Upgrade Until** | Maximum custom format score threshold — upgrades stop when this score is reached |

---

## Data Flow: From Indexer to Library

### The Full Pipeline

```
Prowlarr (indexer manager)
  │
  ├─ syncs indexers to ──→ Sonarr (TV)     ──→ qBittorrent/NZBGet ──→ import + hardlink to /data/media/tv
  ├─ syncs indexers to ──→ Radarr (Movies)  ──→ qBittorrent/NZBGet ──→ import + hardlink to /data/media/movies
  └─ syncs indexers to ──→ Lidarr (Music)   ──→ qBittorrent/NZBGet ──→ import + hardlink to /data/media/music

Bazarr ──→ monitors Sonarr & Radarr for missing subtitles ──→ downloads from providers

Cleanuparr ──→ monitors Sonarr, Radarr & Lidarr for stalled/orphaned/failed downloads ──→ auto-cleanup

Recyclarr ──→ syncs Trash Guides profiles/CFs to Sonarr & Radarr (scheduled or manual)
```

### Inter-Service Communication

| From | To | Hostname | Port | Purpose |
|------|----|----------|------|---------|
| Prowlarr | Sonarr | `sonarr` | 8989 | Sync indexers |
| Prowlarr | Radarr | `radarr` | 7878 | Sync indexers |
| Prowlarr | Lidarr | `lidarr` | 8686 | Sync indexers |
| Sonarr | qBittorrent | `gluetun` or `qbittorrent` | 8080 | Send downloads |
| Sonarr | NZBGet | `gluetun` or `nzbget` | 6789 | Send downloads |
| Radarr | qBittorrent | `gluetun` or `qbittorrent` | 8080 | Send downloads |
| Radarr | NZBGet | `gluetun` or `nzbget` | 6789 | Send downloads |
| Lidarr | qBittorrent | `gluetun` or `qbittorrent` | 8080 | Send downloads |
| Lidarr | NZBGet | `gluetun` or `nzbget` | 6789 | Send downloads |
| Bazarr | Sonarr | `sonarr` | 8989 | Get series/episodes |
| Bazarr | Radarr | `radarr` | 7878 | Get movies |
| Cleanuparr | Sonarr | `sonarr` | 8989 | Monitor queue |
| Cleanuparr | Radarr | `radarr` | 7878 | Monitor queue |
| Cleanuparr | Lidarr | `lidarr` | 8686 | Monitor queue |
| Recyclarr | Sonarr | `sonarr` | 8989 | Push profiles/CFs |
| Recyclarr | Radarr | `radarr` | 7878 | Push profiles/CFs |

> [!IMPORTANT]
> **VPN Profile:** When using `COMPOSE_PROFILES=vpn`, download clients run inside Gluetun's network. Use `gluetun` as the hostname, not `qbittorrent` or `nzbget`. See [VPN Setup](vpn-setup.md).

---

## Prowlarr Tuning

### Indexer Management

- Add indexers via Settings → Indexers → Add Indexer
- Use **tags** to assign indexers to specific apps (e.g., tag `tv` for Sonarr-only indexers, `movies` for Radarr-only)
- Test each indexer after adding to verify connectivity

### Sync Settings

Configure in Settings → Apps for each connected *arr app:

| Setting | Recommended | Why |
|---------|-------------|-----|
| Sync Level | **Full Sync** | Keeps indexers consistent — adds new ones, removes deleted ones |
| Sync Categories | Match the app type | TV categories for Sonarr, Movie for Radarr, Audio for Lidarr |

### Recommended Settings

| Setting | Location | Recommended |
|---------|----------|-------------|
| RSS Sync Interval | Settings → Indexers | **60 minutes** (default; lower taxes indexers) |
| Minimum Seeders | Per indexer → Advanced | **1** (avoid dead torrents) |
| Multi Languages | Per indexer | Configure only if you search for non-English content |

> [!TIP]
> Prowlarr is a **set-and-forget** app. Once indexers are configured and synced, it requires minimal ongoing attention.

---

## Quality Profiles (Sonarr & Radarr)

### What Is a Quality Profile?

A quality profile defines:

1. **Which qualities are acceptable** — an ordered list (e.g., WEB-DL 1080p, Bluray 1080p)
2. **Cutoff** — the quality at which the app considers itself "satisfied" (but CF scores can still trigger upgrades)
3. **Custom format scores** — bonus/penalty points per matched pattern
4. **Upgrade Until** — the maximum CF score; upgrades stop when reached

### Choosing a Profile: Decision Matrix

#### Sonarr (TV Series)

| Profile | Best For | Typical Episode Size | Notes |
|---------|----------|---------------------|-------|
| **WEB-1080p** | Most users | 2–5 GB | Default in this repo. Best for streaming content |
| **HD - 720p/1080p** | Flexibility | 1–5 GB | Active in this repo. Accepts 720p–1080p (HDTV/Bluray/WEB), cutoff WEB 1080p |
| WEB-2160p | 4K display + storage | 5–15 GB | Requires 4K-capable playback device |

#### Radarr (Movies)

| Profile | Best For | Typical Movie Size | Notes |
|---------|----------|-------------------|-------|
| **HD Bluray + WEB** | Most users | 6–15 GB | Default in this repo. Mix of Bluray encodes and WEB-DL |
| **UHD Bluray + WEB** | 4K enthusiasts | 20–60 GB | Active in this repo. 4K with 1080p fallback. Requires 4K display and HDR support |
| **HD - 720p/1080p** | Flexibility | 4–15 GB | Active in this repo. Accepts 720p–1080p (HDTV/Bluray/WEB/Remux), cutoff WEB 1080p |
| Remux + WEB 1080p | Quality enthusiasts | 20–40 GB | Near-lossless, large files |
| Remux + WEB 2160p | Maximum quality | 40–100 GB | Highest storage cost |

> [!TIP]
> **Start with the defaults** (WEB-1080p for Sonarr, HD Bluray + WEB for Radarr). You can always add a second profile later for specific content. See [Multiple Profiles Strategy](#multiple-profiles-strategy).

### Multiple Profiles Strategy

You can assign **different profiles to different content**:

- **4K profile** for favorite movies/shows you want at maximum quality
- **1080p profile** for everything else to save storage

To add a second profile, uncomment the relevant block in `docker/recyclarr.yml` and run `make recyclarr-sync`. See [Adding a Second Quality Profile](#adding-a-second-quality-profile) in the Recyclarr section.

### Upgrade Behavior

| Concept | Meaning |
|---------|---------|
| **Cutoff** | Quality level where the app stops searching. Set automatically by Trash Guides profiles |
| **Upgrade Until CF Score** | Maximum custom format score. Set to **10000** by Trash Guides — effectively "always upgrade if better" |
| **`reset_unmatched_scores: true`** | CFs not in your config get score 0. Prevents stale scores from old configs affecting decisions |

---

## Custom Formats (Sonarr & Radarr)

### What Are Custom Formats?

Custom formats are pattern-matching rules applied to release names. Each matched format adds its score to the release's total. The release with the highest total score (within acceptable quality) wins.

### How Scoring Works

Example — Radarr evaluates a release:

```
Release: "Movie.Name.2024.1080p.AMZN.WEB-DL.DDP5.1.H.264-GroupName"

Matched Custom Formats:
  ✓ AMZN (streaming service)     → +100
  ✓ WEB-DL (source)              → +1750
  ✓ GroupName (Tier 02 group)    → +1750
  ✗ BR-DISK                      → not matched
  ✗ LQ                           → not matched

Total Score: 3600 → compared against other available releases
```

### Common Custom Format Categories

| Category | Examples | Score Range | Purpose |
|----------|----------|-------------|---------|
| **Unwanted** | BR-DISK, LQ, LQ (Release Title), 3D, Extras | **-10000** | Block unplayable/low-quality releases |
| **Source tier** | WEB-DL, Bluray, Remux | +1600 to +1800 | Rank quality of the source |
| **Streaming service** | AMZN, NF, DSNP, ATVP, MAX | +75 to +100 | Prefer specific services |
| **Release group tier** | Tier 01, Tier 02, Tier 03 | +1800 / +1750 / +1700 | Prefer known quality groups |
| **Audio** | Atmos, DTS-HD MA, TrueHD | Varies | Audio quality preference (Remux profiles) |
| **HDR** | DV, HDR10+, HDR10 | Varies | HDR format preference (4K profiles) |

### When to Override Default Scores

Trash Guides defaults (synced via Recyclarr) cover **95% of use cases**. Only override when you have a specific need:

- **Boost streaming services** — if you prefer Amazon/Netflix quality for WEB-DL content
- **Penalize x265 (HD)** — if your playback devices can't direct-play HEVC at 1080p
- **Boost HQ release groups** — for Radarr, Tier 01/02 groups produce consistently excellent encodes

See [Custom Format Score Overrides](#custom-format-score-overrides) for how to configure this.

---

## Sonarr Tuning

### Recommended UI Settings

Settings → Media Management:

| Setting | Recommended | Why |
|---------|-------------|-----|
| Rename Episodes | **Yes** | Consistent naming for Plex |
| Standard Episode Format | Set via Recyclarr (`default`) | Trash Guides / Plex-optimized |
| Use Hardlinks instead of Copy | **Yes** | Saves disk space, instant "copy" |
| Analyse video files | **No** | Avoid unnecessary NAS I/O |
| Propers and Repacks | **Do not Prefer** | Let custom format scores handle this instead |
| Root Folder | `/data/media/tv` | Standard path for hardlinking |

> [!WARNING]
> **Indexers:** Do not add indexers directly in Sonarr. Prowlarr syncs them automatically. Adding them manually causes duplicates.

### Quality → Profiles (UI View)

After running `make recyclarr-sync`, you'll see the Trash Guides profile(s) in Settings → Profiles. Key settings managed by Recyclarr:

- **Cutoff** — set automatically based on the profile
- **Upgrade Until Custom Format Score** — set to 10000 (always upgrade if better is available)
- **Custom format scores** — all scores pre-configured per Trash Guides recommendations

> [!NOTE]
> You can view these in the UI for verification, but **always make changes via `recyclarr.yml`** and re-sync. Manual UI changes will be overwritten on next sync.

### Quality → Definitions (UI View)

Quality definitions control min/max/preferred file sizes per quality level. Recyclarr sets these via the `quality_definition` section. The `preferred_ratio` setting (0.0 = minimum sizes, 1.0 = maximum sizes) defaults to the Trash Guides recommendation.

---

## Radarr Tuning

### Recommended UI Settings

Settings → Media Management:

| Setting | Recommended | Why |
|---------|-------------|-----|
| Rename Movies | **Yes** | Consistent naming for Plex |
| Movie Folder Format | Set via Recyclarr (`plex-tmdb`) | Includes TMDb ID for Plex matching |
| Use Hardlinks instead of Copy | **Yes** | Saves disk space |
| Analyse video files | **No** | Avoid NAS I/O overhead |
| Propers and Repacks | **Do not Prefer** | Custom format scores handle this |
| Root Folder | `/data/media/movies` | Standard path for hardlinking |

### Release Group Tiers (Radarr-Specific)

For movie encodes, release group quality matters significantly. Trash Guides organizes groups into tiers:

| Tier | Score | Description |
|------|-------|-------------|
| Tier 01 | +1800 | Top-quality encoders (golden standard) |
| Tier 02 | +1750 | Excellent quality, very consistent |
| Tier 03 | +1700 | Good quality, generally reliable |

These are automatically configured by the Trash Guides quality profiles via Recyclarr.

---

## Lidarr Tuning

> [!NOTE]
> Recyclarr does **not** support Lidarr. All settings must be configured manually in the UI.

### Quality Profiles

Lidarr → Settings → Profiles:

| Profile Choice | Best For | File Size per Album |
|----------------|----------|---------------------|
| **Lossless (FLAC)** | Audiophiles, good speakers/headphones | 300–600 MB |
| Standard (MP3 320 + FLAC) | Most users, mixed devices | 100–600 MB |
| Any | Just want the music, don't care about quality | 50–600 MB |

> [!TIP]
> If you have the storage, go **Lossless (FLAC)**. It's the archival standard and can be transcoded later if needed. Plex can transcode FLAC to MP3/AAC on-the-fly for bandwidth-constrained clients.

### Metadata Providers

Lidarr → Settings → Metadata:

- **MusicBrainz** is the default and recommended metadata source
- MusicBrainz rate limits API calls — keep the default delay settings to avoid being blocked
- If you see metadata mismatches, check the release on [MusicBrainz](https://musicbrainz.org/) — community-maintained, you can submit corrections

### Artist Images (fanart.tv)

> [!WARNING]
> Without a personal fanart.tv API key, many artist images will be missing. Lidarr's metadata server proxies fanart.tv but can get rate-limited or blocked (HTTP 403).

**Setup:**

1. Create a free account at [fanart.tv](https://fanart.tv/get-an-api-key/)
2. Copy your **Personal API Key** from your profile
3. In Lidarr → **Settings → Metadata → Fanart.tv**, paste the API key
4. Run **System → Tasks → Refresh All Artist Metadata** to re-download images

**Troubleshooting missing images:**

- Verify connectivity from the container:
  ```bash
  docker exec lidarr curl -s -o /dev/null -w "%{http_code}" https://api.fanart.tv
  ```
  A `403` response confirms the API key is missing or invalid.
- For individual artists: select the artist → Edit (wrench icon) → Refresh Metadata
- Some lesser-known artists may genuinely have no image on fanart.tv — this is expected

### Media Management

| Setting | Recommended | Why |
|---------|-------------|-----|
| Rename Tracks | **Yes** | Consistent naming |
| Use Hardlinks instead of Copy | **Yes** | Same filesystem requirement as Sonarr/Radarr |
| Standard Track Format | `{track:00} - {Track Title}` | Clean, numbered tracks |
| Artist Folder | `{Artist Name}` | One folder per artist |
| Album Folder | `{Album Title} ({Release Year})` | Sortable by year |
| Propers and Repacks | **Do not Prefer** | Consistent with the rest of the stack |
| Root Folder | `/data/media/music` | Standard path for hardlinking |

### Download Client Categories

Ensure the download client category matches what's configured in qBittorrent/NZBGet:

- qBittorrent category: `music` → Save path: `music`
- NZBGet category: `music` → DestDir: `music`

---

## Download Client Settings

### qBittorrent Seeding Behavior

> [!CAUTION]
> **Never set qBittorrent to "Remove torrent" when the seeding goal is reached.** This deletes torrent data before the *arr app can import it, causing failed imports. Even after import, removal breaks hardlinks — the underlying data is deleted from disk.

Per [Trash Guides](https://trash-guides.info/Downloaders/qBittorrent/Basic-Setup/), configure seeding limits in qBittorrent → Options → BitTorrent:

| Setting | Recommended | Why |
|---------|-------------|-----|
| When ratio reaches | **1** | Seed back what you downloaded (good citizen default) |
| When total seeding time reaches | **1440** min (24h) | Secondary limit to stop seeding stalled torrents |
| When seeding goal is reached | **Pause torrent** | Lets *arr apps handle removal via Completed Download Handling |

### *arr Completed Download Handling

Each *arr app can automatically remove completed downloads from qBittorrent after successful import:

Sonarr/Radarr/Lidarr → Settings → Download Clients → Completed Download Handling:

| Setting | Recommended | Why |
|---------|-------------|-----|
| Remove Completed | **Yes** | *arr removes the torrent from qBittorrent after successful import |

This ensures the correct lifecycle:

```
qBittorrent downloads → seeds to ratio → pauses
  ↓
*arr app detects completion → imports (hardlinks) → removes torrent from qBittorrent
```

> [!NOTE]
> With hardlinks enabled, removing the torrent after import is safe — the media file in your library is an independent hardlink to the same data on disk. Space is only reclaimed when *both* the torrent file and the library file are deleted.

---

## Bazarr Tuning

> [!NOTE]
> Trash Guides has a [Bazarr setup guide](https://trash-guides.info/Bazarr/Setup-Guide/) with detailed recommendations. This section summarizes the key settings.

### Provider Configuration

Bazarr → Settings → Providers:

- **Add multiple providers** for better subtitle coverage. Recommended:
  - OpenSubtitles.com (account required, free tier available)
  - Subscene
  - Podnapisi
  - Addic7ed (account required)
- **Anti-captcha**: Some providers require an anti-captcha service. [anti-captcha.com](https://anti-captcha.com/) is the recommended provider
- **Provider priority**: Drag providers into preferred order. Bazarr tries them top-to-bottom

### Language Profiles

Bazarr → Settings → Languages:

- Create language profiles with your preferred subtitle languages in priority order
- **Forced subtitles**: Enable if you want forced subs (foreign language dialogue only) — typically for movies with partial non-English dialogue
- **Hearing Impaired (HI)**: Enable "Also search for Hearing Impaired" if you want SDH subtitles, or exclude them if you prefer clean subtitles

> [!TIP]
> Configure a **cutoff** in the language profile so Bazarr stops searching once your primary language subtitle is found.

### Subtitle Score Threshold

Bazarr → Settings → Subtitles:

- **Minimum Score**: Raise this if you get out-of-sync or poor subtitles frequently. A higher threshold means fewer but better-matched subtitles
- The score is based on how well the subtitle matches the release (hash match > name match > partial match)

### Sync with Sonarr/Radarr

| Setting | Recommended |
|---------|-------------|
| Sync interval | Default (every few hours is fine) |
| Path mapping | **Not needed** if Bazarr uses the same Docker volume mounts as Sonarr/Radarr |

> [!NOTE]
> Bazarr mounts `/share/data/media:/data/media` (only the media folder, not the full `/share/data` tree). Inside the container, Bazarr sees `/data/media` — the same path that Sonarr/Radarr see (they mount `/share/data:/data`). No path mapping is required.

### Post-Processing

| Setting | Recommended | Why |
|---------|-------------|-----|
| Subtitle storage | **Alongside media file** | Plex/media players find them automatically |
| Subtitle format | **SRT** preferred | Most compatible across players |
| Upgrade subtitles | **Yes** | Allows Bazarr to replace poor subs when better ones appear |
| Upgrade frequency | Default | How often to check for subtitle upgrades |

---

## Cleanuparr Tuning

### What Cleanuparr Does

[Cleanuparr](https://github.com/cleanuparr/cleanuparr) monitors your *arr apps' download queues and automatically cleans up problematic downloads:

- **Stalled downloads** — stuck torrents with no seeders
- **Failed downloads** — NZB/torrent errors
- **Orphaned downloads** — files no longer tracked by any *arr app

### Recommended Settings

Access Cleanuparr at `http://192.168.3.10:11011` (or `https://cleanuparr.home.local` via Traefik).

#### Connections

Add connections to each *arr app:

| App | URL | API Key Source |
|-----|-----|---------------|
| Sonarr | `http://sonarr:8989` | Sonarr → Settings → General |
| Radarr | `http://radarr:7878` | Radarr → Settings → General |
| Lidarr | `http://lidarr:8686` | Lidarr → Settings → General |

#### Cleanup Rules

| Setting | Recommended | Why |
|---------|-------------|-----|
| Stalled timeout | **30 minutes** | Long enough to survive temporary issues |
| Failed download action | **Remove and blocklist** | Prevents re-downloading the same broken release |
| Strike count | **3** | Number of failures before blocklisting |

### Monitoring Schedule

| Setting | Recommended |
|---------|-------------|
| Check interval | **10–15 minutes** | Frequent enough to catch issues quickly |
| Enabled by default | **Yes** | Set and forget |

> [!TIP]
> Cleanuparr is most valuable when combined with Recyclarr's quality profiles. Failed downloads from low-quality sources get cleaned up and the *arr app automatically searches for a better alternative.

---

## Recyclarr Deep Dive

### How Recyclarr Works

Recyclarr pulls quality profile and custom format definitions from the [Trash Guides GitHub repository](https://github.com/TRaSH-Guides/Guides) and pushes them to Sonarr/Radarr via their APIs.

```
Trash Guides GitHub ──→ Recyclarr ──→ Sonarr API (quality profiles, CFs, naming)
                                  ──→ Radarr API (quality profiles, CFs, naming)
```

> [!IMPORTANT]
> Recyclarr only supports **Sonarr and Radarr**. Lidarr, Prowlarr, and Bazarr must be configured manually.

Configuration lives in `docker/recyclarr.yml` (source file, committed to git) and is copied to the container at `./config/recyclarr/recyclarr.yml`.

### Adding a Second Quality Profile

Both 1080p and 4K profiles are already active in `docker/recyclarr.yml`:

```yaml
quality_profiles:
  # HD Bluray + WEB (1080p) - already active
  - trash_id: d1d67249d3890e49bc12e275d989a7e9
    reset_unmatched_scores:
      enabled: true

  # UHD Bluray + WEB (4K) - already active, 4K with 1080p fallback
  - trash_id: 64fb5f9858489bdac2af690e27c8f42f
    reset_unmatched_scores:
      enabled: true
```

**Sonarr example** — add a WEB-2160p profile:

```yaml
quality_profiles:
  # WEB-1080p - already active
  - trash_id: 72dae194fc92bf828f32cde7744e51a1
    reset_unmatched_scores:
      enabled: true

  # WEB-2160p - add for 4K content
  - trash_id: <WEB-2160p trash_id from Trash Guides>
    reset_unmatched_scores:
      enabled: true
```

Then sync:

```bash
# Copy updated config to container
make recyclarr-config

# Preview changes (dry run)
docker exec recyclarr recyclarr sync --preview

# Apply
make recyclarr-sync

# If the profile already exists in Sonarr/Radarr (created manually via UI),
# use adopt=true to let Recyclarr take ownership before syncing:
make recyclarr-sync adopt=true
```

Verify in the Sonarr/Radarr UI: Settings → Profiles — you should see the new profile.

### Custom Format Score Overrides

The quality profiles include Trash Guides' recommended CFs and scores. To **override** specific scores, add a `custom_formats:` block under the instance in `docker/recyclarr.yml`.

**Example: Penalize unwanted formats** (Sonarr):

```yaml
custom_formats:
  - trash_ids:
      - 85c61753df5da1fb2aab6f2a47426b09  # BR-DISK
      - 9c11cd3f07101cdba90a2d81cf0e56b4  # LQ
      - e2315f990da2e2cbfc9fa5b7a6c62170  # LQ (Release Title)
      - 47435ece6b99a0b477caf360e79ba0bb  # x265 (HD)
    assign_scores_to:
      - name: WEB-1080p
        score: -10000
```

**Example: Boost streaming services** (Sonarr):

```yaml
custom_formats:
  - trash_ids:
      - d660701077794679fd59e8bdf4ce3a29  # AMZN
      - f67c9ca88f463a48346062e8ad07713f  # ATVP
      - 89358767a60cc28783cdc3d0be9388a4  # DSNP
      - 81d1fbf600e2540cee87f3a23f9d3c1c  # MAX
      - d34870697c9db575f17700212167be23  # NF
    assign_scores_to:
      - name: WEB-1080p
        score: 100
```

**Example: Boost HQ release groups** (Radarr):

```yaml
custom_formats:
  - trash_ids:
      - ed27ebfef2f323e964fb1f61f37d2d1f  # Tier 01
      - c20c8647f2746a1f4c4262b0fbbeeeae  # Tier 02
    assign_scores_to:
      - name: HD Bluray + WEB
        score: 1750
```

> [!NOTE]
> These examples are already present as commented blocks in `docker/recyclarr.yml`. Uncomment and modify as needed.

### Quality Definition Tuning

The `preferred_ratio` setting controls the target file size within the quality definition range:

| Value | Meaning | Use Case |
|-------|---------|----------|
| 0.0 | Prefer minimum file sizes | Bandwidth-constrained, save storage |
| 0.5 | Middle ground | Balanced |
| 1.0 | Prefer maximum file sizes | Storage-rich, want highest quality |
| *(omitted)* | Use Trash Guides default | **Recommended** — let the community decide |

### Useful Recyclarr Commands

```bash
# List available quality definition types
docker exec recyclarr recyclarr list qualities

# List available custom formats (with trash_ids)
docker exec recyclarr recyclarr list custom-formats sonarr
docker exec recyclarr recyclarr list custom-formats radarr

# List media naming format keys
docker exec recyclarr recyclarr list naming sonarr
docker exec recyclarr recyclarr list naming radarr

# Sync (dry run — preview without applying)
docker exec recyclarr recyclarr sync --preview

# Sync (apply changes)
make recyclarr-sync

# Sync with adopt (when profiles already exist in the UI)
make recyclarr-sync adopt=true

# Sync only Sonarr or Radarr
docker exec recyclarr recyclarr sync sonarr
docker exec recyclarr recyclarr sync radarr
```

### Propers and Repacks

Both Sonarr and Radarr have a built-in "Propers and Repacks" setting. Trash Guides recommends setting this to **"Do not Prefer"** because:

1. Custom formats include proper/repack patterns with appropriate scores
2. This gives more control — the CF score is weighed against other factors
3. The built-in setting is binary (prefer or don't), while CF scores are granular

This is already configured in `docker/recyclarr.yml` under `media_management.propers_and_repacks: do_not_prefer`.

---

## Troubleshooting

### Releases Not Being Grabbed

1. **Check the quality profile is assigned** — Series/Movie → Edit → Quality Profile must be set
2. **Check indexers are synced** — Settings → Indexers should show Prowlarr-synced indexers
3. **Check Activity → Queue** — look for "Rejected" entries and the reason
4. **Use Interactive Search** — on a series/movie, click the search icon to see all available releases with their scores and rejection reasons

### Quality Upgrades Not Happening

1. **Cutoff already met** — if the current file meets the cutoff quality, no upgrade is searched
2. **CF score already at Upgrade Until** — the existing file's CF score meets or exceeds the threshold
3. **Check "Propers and Repacks" setting** — must be "Do not Prefer" per Trash Guides (Settings → Media Management)
4. **Use Interactive Search** — check if available releases score higher than the current file

### Import Failures (Download Completes but Not Imported)

1. **Path mismatch** — download client category save path must align with *arr root folder. Both must be under `/data/`
2. **Hardlink failure** — source and destination must be on the same filesystem. See [Hardlinking Verification](nas-setup.md#hardlinking-verification)
3. **Permission issues** — PUID/PGID in `.env` must match the file owner. Check with `ls -ln /share/data`
4. **Torrent removed before import** — if qBittorrent is set to "Remove torrent" when the seeding goal is reached, files are deleted before import. Change to **"Pause torrent"** in Options → BitTorrent. See [Download Client Settings](#download-client-settings)
5. **Check Activity → Queue** — hover over the warning icon for the specific error message

### Custom Format Not Matching

1. **Check Activity → History** — click a grabbed release, review the "Custom Formats" section to see which CFs matched
2. **Recyclarr sync issue** — run `make recyclarr-sync` and verify CFs appear in Settings → Custom Formats
3. **Release name doesn't match** — CFs are regex patterns on the release name. Check the exact release name against the pattern

### Recyclarr Sync Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Unauthorized` | Invalid API key | Verify `SONARR_API_KEY`/`RADARR_API_KEY` in `docker/.env.secrets` |
| `Connection refused` | App not running | Check container status with `docker ps` |
| `No guide data found` | Invalid trash_id | Verify trash_id against [Trash Guides](https://trash-guides.info/) |
| `profile ... already exists` | Profile was created manually in the UI before Recyclarr managed it | Run `docker exec recyclarr recyclarr state repair --adopt` to let Recyclarr adopt the existing profile, then re-sync |

Always preview before applying:

```bash
docker exec recyclarr recyclarr sync --preview
```

### Bazarr Not Finding Subtitles

1. **Verify providers** — Settings → Providers → Test each one
2. **Check score threshold** — lower the minimum score temporarily to see if subs are being found but rejected
3. **Verify Sonarr/Radarr connection** — Settings → Sonarr/Radarr → Test
4. **Check languages** — Language Profiles must be assigned to series/movies

### Cleanuparr Not Cleaning Up

1. **Verify API connections** — ensure each *arr app is connected and the API key is valid
2. **Check timeout thresholds** — stalled timeout may be too high for your use case
3. **Review logs** — check `docker logs cleanuparr` for errors or skipped items

### Debugging Custom Format Scores

Step-by-step walkthrough:

- [ ] Go to Activity → History in Sonarr or Radarr
- [ ] Click on a grabbed release
- [ ] Review the "Custom Formats" section — shows which CFs matched and their scores
- [ ] Compare the total score against the "Upgrade Until" threshold
- [ ] Use **Interactive Search** on any series/movie to see all candidates with their scores side-by-side
- [ ] If a CF isn't appearing, check Settings → Custom Formats to verify it exists (Recyclarr may need re-sync)

---

## References

- [Trash Guides](https://trash-guides.info/) — Community *arr configuration standard
- [Trash Guides — Sonarr Quality Profiles](https://trash-guides.info/Sonarr/sonarr-setup-quality-profiles/)
- [Trash Guides — Radarr Quality Profiles](https://trash-guides.info/Radarr/radarr-setup-quality-profiles/)
- [Trash Guides — Bazarr Setup Guide](https://trash-guides.info/Bazarr/Setup-Guide/)
- [Recyclarr Documentation](https://recyclarr.dev/wiki/)
- [Recyclarr YAML Reference](https://recyclarr.dev/wiki/yaml/config-reference/)
- Internal: [NAS Deployment Checklist](nas-setup.md) — Initial *arr setup
- Internal: [VPN Setup](vpn-setup.md) — Gluetun configuration for download clients
- Internal: `docker/recyclarr.yml` — Recyclarr configuration source file
