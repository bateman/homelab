# *arr Tuning Guide — Trash Guides Best Practices

> Recommended settings for Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, and Cleanuparr

---

## Quick Navigation

| Section | Description |
|---------|-------------|
| [Overview](#overview) | Guide scope, prerequisites, what Recyclarr manages vs manual tuning |
| [Trash Guides Philosophy](#trash-guides-philosophy) | How quality profiles, custom formats, and scoring work |
| [Data Flow](#data-flow-from-indexer-to-library) | Full pipeline diagram and inter-service communication |
| **Per-App Settings** | |
| [Prowlarr](#prowlarr-tuning) | Indexer management and sync settings |
| [Sonarr](#sonarr-tuning) | TV series — media management, quality profiles |
| [Radarr](#radarr-tuning) | Movies — media management, release group tiers |
| [Lidarr](#lidarr-tuning) | Music — quality profiles, metadata, media management |
| [Bazarr](#bazarr-tuning) | Subtitles — providers, languages, performance, scheduling |
| [Cleanuparr](#cleanuparr-tuning) | Queue cleanup — general settings, queue cleaner, strike system |
| **Shared Settings** | |
| [Quality Profiles](#quality-profiles-sonarr--radarr) | Profile selection for Sonarr & Radarr |
| [Custom Formats](#custom-formats-sonarr--radarr) | Scoring system and common CF categories |
| [Download Client Settings](#download-client-settings) | qBittorrent seeding behavior and completed download handling |
| [Recyclarr Deep Dive](#recyclarr-deep-dive) | Adding profiles, score overrides, useful commands |
| [Troubleshooting](#troubleshooting) | Common issues and debugging steps |
| [References](#references) | External links and internal docs |

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
| Cleanuparr | qBittorrent | `gluetun` or `qbittorrent` | 8080 | Monitor/remove torrents |
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

Trash Guides has a [Bazarr setup guide](https://trash-guides.info/Bazarr/Setup-Guide/) with detailed recommendations. The [Bazarr Wiki](https://wiki.bazarr.media/) covers every setting in depth.

### Provider Configuration

Bazarr → Settings → Providers:

**Enabled providers** (in priority order):

| Provider | Notes |
|----------|-------|
| **Gestdown** (Addic7ed proxy) | Proxy for the Addic7ed website — no login or cookies needed. Preferred over using Addic7ed directly |
| **YIFY Subtitles** | Good coverage for popular movies. No account required |
| **TVSubtitles** | TV-focused provider. No account required |
| **Supersubtitles** | Additional coverage for TV and movies. No account required |
| **Podnapisi** | Reliable multi-language provider. No account required |
| **Addic7ed** | Requires Anti-Captcha provider or cookies to bypass rate limiting. Redundant if Gestdown is enabled, but kept as fallback |
| **OpenSubtitles.com** | Largest subtitle database. Account required (free tier available) |

- **Anti-captcha**: Addic7ed requires an anti-captcha service or cookies. [anti-captcha.com](https://anti-captcha.com/) is the recommended provider
- **Provider priority**: Drag providers into preferred order. Bazarr tries them top-to-bottom
- **Why Gestdown over Addic7ed directly?** Gestdown proxies Addic7ed without needing credentials or anti-captcha, making it more reliable for automated use

> [!TIP]
> Test each provider after adding it. Providers with authentication issues or rate limits will silently fail during searches.

### Language Settings

Bazarr → Settings → Languages:

#### Subtitles Language

| Setting | Value | Why |
|---------|-------|-----|
| Single Language | **Disabled** | Keeps language codes in subtitle filenames so Plex/media players identify each language correctly |
| Languages Filter | **English, Italian** | The two languages Bazarr will search for across all providers |

#### Language Equals

No language equivalences configured. Use this to treat two language codes as identical across providers (e.g., Portuguese and Brazilian Portuguese).

#### Embedded Tracks Language

| Setting | Value | Why |
|---------|-------|-----|
| Deep analyze media file | **Disabled** | Avoids CPU-intensive ffprobe scans on every media file to detect audio track languages |

#### Languages Profile

One profile configured — **ITA-EN**:

| ID | Language | Subtitles Type | Search only when... |
|----|----------|---------------|---------------------|
| 1 | **Italian** | Normal or hearing-impaired | Always |
| 2 | **English** | Normal or hearing-impaired | Always |

| Setting | Value | Why |
|---------|-------|-----|
| Cutoff | **Italian (it)** | Bazarr stops searching once an Italian subtitle is found — English is only fetched if Italian is unavailable |
| Must contain | *(empty)* | No keyword filtering on subtitle release info |
| Must not contain | *(empty)* | No keyword exclusion on subtitle release info |
| Use Original Format | **Disabled** | Allows Bazarr to convert subtitle format (e.g., ASS → SRT) for broader player compatibility |

> [!NOTE]
> **Subtitles Type** "Normal or hearing-impaired" accepts both clean and SDH subtitles — Bazarr downloads whichever scores highest. Change to "Normal" to exclude HI/SDH subs, or "Hearing-impaired" for SDH-only.

#### Tag-Based Automatic Language Profile Selection

| Setting | Value |
|---------|-------|
| Series | **Disabled** |
| Movies | **Disabled** |
| Remove Profile Tags | *(empty)* |

When enabled, Bazarr matches Sonarr/Radarr tag names to language profile names and auto-assigns profiles. Useful for multi-language libraries where different content needs different subtitle languages.

#### Default Language Profiles For Newly Added Shows

| Setting | Value | Why |
|---------|-------|-----|
| Series | **Enabled** — Profile: ITA-EN | Auto-applies the ITA-EN profile to all new series added to Sonarr |
| Movies | **Enabled** | Auto-applies profile to all new movies added to Radarr |

This ensures every new addition gets subtitle searches immediately without manual profile assignment.

### Sonarr/Radarr Integration Options

Bazarr → Settings → Sonarr / Radarr → Options:

- **Minimum Score**: The percentage match quality required before Bazarr downloads a subtitle. Raise this if you get out-of-sync or poor subtitles frequently
- The score is based on how well the subtitle matches the release (hash match > name match > partial match)
- **Excluded tags**: Skip series/movies with specific tags (case-sensitive) — useful for excluding anime or foreign content that needs special subtitle handling
- **Excluded series types**: Skip Standard, Anime, or Daily show types from subtitle searches
- **Monitored only**: Only search for subtitles for monitored content (recommended)

### Sync with Sonarr/Radarr

Path mapping is **not needed** — Bazarr mounts `/share/data/media:/data/media` and sees `/data/media`, the same path Sonarr/Radarr see via `/share/data:/data`. Sync interval is configured in Bazarr → Settings → Scheduler (see [Scheduler Tuning](#scheduler-tuning) below).

### Subtitles Settings

Bazarr → Settings → Subtitles:

#### Subtitle File Options

| Setting | Value | Why |
|---------|-------|-----|
| Subtitle Folder | **AlongSide Media File** | Plex/media players find them automatically |
| Hearing-impaired subtitles extension | **hi (Hearing-Impaired)** | Uses `.hi` extension when saving HI subtitle files to disk |
| Encode Subtitles To UTF-8 | **Enabled** | Ensures consistent encoding; prevents garbled characters on non-Latin subtitle files |
| Change Subtitle File Permission After Download (chmod) | **Disabled** | Not needed — container PUID/PGID handles permissions |

#### Embedded Subtitles Handling

| Setting | Value | Why |
|---------|-------|-----|
| Treat Embedded Subtitles as Downloaded | **Enabled** | Prevents Bazarr from searching providers when the media file already has embedded subs |
| Embedded Subtitles video parser | **ffprobe** | Faster than mediainfo and included in Bazarr already |
| Ignore Embedded PGS Subtitles | **Disabled** | PGS (image-based) subs are still recognized as present |
| Ignore Embedded VobSub Subtitles | **Disabled** | VobSub subs are still recognized as present |
| Ignore Embedded ASS Subtitles | **Disabled** | ASS subs are still recognized as present |
| Show Only Desired Languages | **Enabled** | Hides embedded subtitle tracks for languages not in your profile |

#### Upgrading Subtitles

| Setting | Value | Why |
|---------|-------|-----|
| Upgrade Previously Downloaded Subtitles | **Enabled** | Allows Bazarr to replace poor subs when better ones appear |
| Upgrade days | **14** | How many days back to check for upgrades — increased from default 7 for broader upgrade window |
| Upgrade Manually Downloaded or Translated Subtitles | **Enabled** | Bazarr can improve even manually selected subs if a better match appears |

#### Performance / Optimization

| Setting | Value | Why |
|---------|-------|-----|
| Adaptive Searching | **Enabled** | Reduces search frequency over time for files unlikely to have subtitles — prevents hammering providers |
| Adaptive searching delay | **3 weeks** | Time window from first search before adaptive mode kicks in |
| Adaptive searching delta | **1 week** | Once adaptive mode is active, Bazarr skips files searched more recently than this |
| Search Enabled Providers Simultaneously | **Enabled** | Queries all providers at once for faster results. Disable on low-power devices |
| Skip video file hash calculation | **Disabled** | Hash matching gives the most accurate subtitle results; only enable to prevent waking a sleeping HDD |

#### Sub-Zero Subtitle Content Modifications

All post-download content modifications are **disabled**:

| Setting | Value |
|---------|-------|
| Hearing Impaired | Disabled |
| Remove Tags | Disabled |
| Remove Emoji | Disabled |
| OCR Fixes | Disabled |
| Common Fixes | Disabled |
| Fix Uppercase | Disabled |
| Color | *(none)* |
| Reverse RTL | Disabled |

> [!NOTE]
> These modify subtitle content after download (remove HI annotations, strip formatting tags, fix OCR artifacts, etc.). Keeping them all disabled preserves subtitles as-is from the provider. Enable selectively if you encounter issues like `[music playing]` annotations in non-HI subs or garbled OCR text.

#### Audio Synchronization / Alignment

| Setting | Value | Why |
|---------|-------|-----|
| Always use Audio Track as Reference for Syncing | **Disabled** | Only uses audio reference when needed, not for every sync |
| Do Not Fix Framerate Mismatch | **Enabled** | Prevents subsync from altering timing when video/subtitle framerates differ — avoids making sync worse |
| Golden-Section Search | **Enabled** | Uses golden-section search to find the optimal framerate ratio between video and subtitles |
| Max Offset Seconds | **60** | Maximum allowed timing offset per subtitle segment |
| Automatic Subtitles Audio Synchronization | **Disabled** | Avoids massive CPU usage from extracting audio and running speech detection on every file. On a QNAP NAS, this would saturate resources for hours on a large library |

> [!TIP]
> If you need subtitle sync for specific files, use a **post-processing script** instead (see below) — this targets only newly downloaded subs rather than the entire library.

#### Custom Post-Processing

| Setting | Value |
|---------|-------|
| Custom Post-Processing | **Disabled** |

Bazarr can execute custom scripts after downloading a subtitle using template variables like `{{subtitles}}` (subtitle path) and `{{episode}}`/`{{movie}}` (media path). See the [Bazarr Wiki](https://wiki.bazarr.media/) for the full variable list.

**Useful community scripts:**

- **[bazarr-cleansubs](https://github.com/TheCaptain989/bazarr-cleansubs)** — removes scene branding and attribution lines from SRT files (e.g., "Subtitles by YTS" ads)
- **SubSync** — synchronize subtitle timing against the audio track:
  ```
  subsync --cli sync --sub '{{subtitles}}' --ref '{{episode}}' --out '{{subtitles}}' --overwrite
  ```
  This is the targeted alternative to enabling automatic synchronization globally

> [!NOTE]
> Post-processing scripts run inside the Bazarr container. If using a community tool, it must be installed in the container or accessible via a mounted volume.

#### Translating

| Setting | Value | Why |
|---------|-------|-----|
| Score for Translated Episode and Movie Subtitles | **0** | Translated subtitles receive no score bonus — original-language subs are always preferred |
| Translator | **Google Translate** | Used as fallback when no subtitle is available in the desired language |

### Scheduler Tuning

Bazarr → Settings → Scheduler:

| Task | Recommended | Why |
|------|-------------|-----|
| Sonarr/Radarr Sync | **15 minutes** (default) | Picks up new additions reasonably fast |
| Disk Indexing | **Manually** | Disables automatic drive scanning for existing subs — on large libraries (10,000+ files), periodic scanning causes substantial NAS I/O |
| Search and Upgrade Subtitles | **6–12 hours** | Default may be too aggressive. Increase if you see "maximum number of running instances reached" in logs |

### Notifications

Bazarr → Settings → Notifications:

Bazarr supports [Apprise](https://github.com/caronc/apprise)-compatible notification strings for alerting on subtitle downloads and failures:

- **Discord**: `discord://webhook_id/webhook_token`
- **Telegram**: `tgram://bot_token/chat_id`
- **Slack**: `slack://token_a/token_b/token_c/#channel`

Configure notifications for awareness of subtitle activity — especially useful to catch provider failures early. For infrastructure-level monitoring (uptime, container health), see [notifications-setup.md](notifications-setup.md).

---

## Cleanuparr Tuning

### What Cleanuparr Does

[Cleanuparr](https://github.com/flmorg/cleanuperr) monitors your *arr apps' download queues and automatically cleans up problematic downloads:

- **Stalled downloads** — stuck torrents with no seeders
- **Slow downloads** — transfers below a speed threshold or with excessive ETAs
- **Failed downloads** — NZB/torrent errors
- **Metadata-stuck downloads** — stuck in metadata download phase
- **Orphaned files** — files in download folders no longer tracked by any *arr app or without hardlinks
- **Completed seeded downloads** — remove torrents after they've met their seeding goal
- **Malware detection** — flag releases containing suspicious files (e.g., executables, password-protected archives)

### Connections

Access Cleanuparr at `http://192.168.3.10:11011` (or `https://cleanuparr.home.local` via Traefik).

Add connections to each *arr app and your download client:

**Arr apps:**

| App | URL | API Key Source |
|-----|-----|---------------|
| Sonarr | `http://sonarr:8989` | Sonarr → Settings → General |
| Radarr | `http://radarr:7878` | Radarr → Settings → General |
| Lidarr | `http://lidarr:8686` | Lidarr → Settings → General |

**Download clients (torrent only):**

| Client | URL |
|--------|-----|
| qBittorrent | `http://gluetun:8080` or `http://qbittorrent:8080` |

Use the `gluetun` hostname when the VPN profile is active (see [VPN Setup](vpn-setup.md)). Cleanuparr also supports Transmission and Deluge — only qBittorrent is used in this stack.

> [!NOTE]
> Cleanuparr only supports torrent download clients. Usenet clients (NZBGet, SABnzbd) are not supported — failed NZB downloads are handled by the *arr apps' own "Failed Download Handling" settings.

### General Settings

Settings → General in the Cleanuparr UI (`http://192.168.3.10:11011/settings/general`):

#### General

| Setting | Recommended | Why |
|---------|-------------|-----|
| Dry Run Mode | **Off** | When enabled, actions are logged but not executed — useful for testing rules before going live |
| Display Support Banner | **Off** | Hides the support/sponsor banner on the dashboard |
| Status Check | **On** | Periodically checks for new Cleanuparr versions. Disable if your environment has restricted outbound network access |

**Ignored Downloads**: Add patterns (hash, tag, category, label, tracker) to exclude specific downloads from all cleanup actions. Leave empty unless you have downloads that should never be touched by Cleanuparr.

#### Authentication

| Setting | Recommended | Why |
|---------|-------------|-----|
| Disable Authentication for Local Addresses | **On** | Requests from local networks (localhost, 192.168.x.x, 10.x.x.x, 172.16–31.x.x) bypass authentication |
| Trust Forwarded Headers | **Off** | Enable only if Cleanuparr is behind a reverse proxy (Traefik) — trusts `X-Forwarded-For` and `X-Real-IP` headers to determine the client's real IP |

**Additional Trusted Networks**: Add CIDR ranges that should bypass authentication. For this stack:

- `192.168.3.0/24` — Server VLAN (where *arr apps and Cleanuparr run)
- `192.168.4.0/24` — IoT/media VLAN (if accessing from media devices)
- `100.64.0.0/10` — Tailscale CGNAT range (for remote access via Tailscale)

#### HTTP Settings

| Setting | Recommended | Why |
|---------|-------------|-----|
| Max Retries | **0** | Number of retry attempts for failed HTTPS requests to *arr APIs. 0 means no retries — increase if your *arr apps have intermittent connectivity |
| Timeout | **100** seconds | HTTP request timeout for API calls. Default is sufficient for most setups |
| Certificate Validation | **Enabled** | Validates HTTPS certificates. Only disable if using self-signed certs for *arr app connections (not recommended) |

#### Search Settings

| Setting | Recommended | Why |
|---------|-------------|-----|
| Search Enabled | **On** | When a download is removed, Cleanuparr triggers the *arr app to search for an alternative release automatically |
| Search Delay | **120** seconds | Delay between search operations to avoid hammering indexers. Lower values risk rate-limiting from indexers |

#### State Management

| Setting | Recommended | Why |
|---------|-------------|-----|
| Strike Inactivity Window | **24** hours | Strikes for a download are cleared after this many hours without a new strike. As long as new strikes keep occurring, all strikes are retained |

**Purge All Strikes**: Permanently deletes all strike data for every download, resetting strike counts to zero. Use this after changing cleanup rules to start fresh, or if strike data has become stale after a long period of downtime.

> [!TIP]
> **Dry Run Mode** is excellent for initial setup — enable it, let Cleanuparr run for a day, then review the logs to see what *would* have been cleaned up before committing to live cleanup.

### Strike System

Cleanuparr uses a **strike system** to avoid prematurely removing downloads that may recover:

```
Download detected with problem (stalled, slow, etc.)
  → Strike 1 recorded
  → Next check: still problematic?
    → Strike 2 recorded
    → Next check: still problematic?
      → Strike 3 (max) → Remove + blocklist
```

### Queue Cleaner

Settings → Queue Cleaner in the Cleanuparr UI (`http://192.168.3.10:11011/settings/queue-cleaner`). This is where all automatic cleanup rules are configured.

#### General

| Setting | Recommended | Why |
|---------|-------------|-----|
| Enabled | **On** | Activates the queue cleaner on the configured schedule |
| Process downloads with no content ID | **Off** | When enabled, processes queue items not linked to any content in the *arr app. Cleanuparr cannot trigger a replacement search for these, so leave off unless you want orphaned queue entries cleaned up |
| Advanced Scheduling | **Off** | Toggle between simple interval scheduling and advanced cron expressions. Simple scheduling is sufficient for most setups |
| Schedule Unit | **Minutes** | Time unit for the check interval |
| Every | **15** | How often the queue cleaner runs. 15 minutes is frequent enough to catch issues without excessive API calls |

**Ignored Downloads**: Add patterns (hash, tag, category, label, tracker) to exclude specific downloads from all queue cleaner actions. Useful for cross-seed content, private tracker torrents with strict ratio requirements, or manually managed downloads.

> [!TIP]
> If you're using cross-seeding tools alongside qBittorrent, add their category or tag to the ignored downloads list so Cleanuparr doesn't remove cross-seeded content.

#### Failed Import

Settings for handling downloads that the *arr app has flagged as failed imports (e.g., bad file, sample-only release, unpacking errors):

| Setting | Recommended | Why |
|---------|-------------|-----|
| Max Strikes | **3** | Number of strikes before action is taken. Set to 0 to disable failed import handling. Minimum 3 to enable |
| Ignore Private Torrents | **Off** | When enabled, private torrents are excluded from failed import checks. Enable if your private tracker has strict hit-and-run rules |
| Delete Private from Client | **Off** | When disabled, private torrents are removed from the *arr app but kept in the torrent client. Enable only if you want Cleanuparr to also delete the torrent from qBittorrent |
| Skip if Not Found in Client | **On** | Skips failed import checks for torrents not found in any enabled torrent client. Prevents false positives when the torrent was already manually removed |
| Pattern Mode | **Exclude** | Controls how patterns are applied: **Exclude** skips matching downloads (everything else is processed), **Include** only processes matching downloads (everything else is skipped) |
| Excluded/Included Patterns | *(empty)* | Patterns to filter which failed imports are processed, based on the Pattern Mode above |

> [!TIP]
> Start with conservative settings (higher timeouts, more strikes) and tighten over time as you learn your typical download patterns.

#### Downloading Metadata (qBittorrent Only)

Settings for handling torrents stuck in the metadata download phase. This is a common issue with torrents that have few seeders or broken DHT entries. Each section (one per connected *arr app) has its own settings. The structure mirrors the Failed Import section — configure Max Strikes, private torrent handling, and pattern filtering per app.

#### Stalled Download Rules

Rules for detecting and handling stalled downloads (torrents with no transfer activity). Create one or more stall rules — each rule is independently configurable:

| Setting | Recommended | Why |
|---------|-------------|-----|
| Name | *(descriptive name)* | Identifies the rule (e.g., "Default Stall Rule", "Aggressive TV Stall") |
| Enabled | **On** | Toggle individual rules without deleting them |
| Max Strikes | **3** | Number of strikes before action is taken. Higher = more patient |
| Privacy Type | **Both** | Which torrent types the rule applies to: **Public**, **Private**, or **Both** |
| Min Completion % | **0** | Only apply the rule once download progress exceeds this value. 0 means apply from the start (0% and above) |
| Max Completion % | **100** | Only apply the rule to downloads at or below this completion percentage. Use to skip nearly-complete downloads |
| Reset Strikes on Progress | **Off** | When enabled, the strike count resets to zero if the torrent shows any download progress. Useful for torrents with intermittent seeders — prevents premature removal |
| Delete Private from Client | **Off** | When disabled, private torrents are removed from the *arr app but kept in qBittorrent. Enable only if you also want the torrent deleted from the client |

> [!TIP]
> Create multiple stall rules for different scenarios — e.g., a lenient rule for private torrents (`Privacy Type: Private`, higher strikes, `Reset Strikes on Progress: On`) and an aggressive rule for public torrents (`Privacy Type: Public`, fewer strikes). Use `Min/Max Completion %` to treat nearly-complete downloads differently from those stuck at 0%.

#### Slow Download Rules

Rules for detecting and handling downloads that are transferring too slowly. Create one or more slow rules — each rule is independently configurable:

| Setting | Recommended | Why |
|---------|-------------|-----|
| Name | *(descriptive name)* | Identifies the rule (e.g., "Default Slow Rule", "Strict Public Slow") |
| Enabled | **On** | Toggle individual rules without deleting them |
| Max Strikes | **3** | Number of strikes before action is taken |
| Min Speed | **100 KB/s** | Minimum speed threshold — downloads below this receive a strike. Toggle between KB/s and MB/s. Leave empty to disable speed checking |
| Maximum Time (Hours) | **0** (disabled) | Maximum time allowed for slow downloads. Downloads exceeding this duration receive a strike. Set to 0 to disable — useful if you only want speed-based detection |
| Privacy Type | **Both** | Which torrent types the rule applies to: **Public**, **Private**, or **Both** |
| Min Completion % | **0** | Only apply the rule once download progress exceeds this value (0 includes items at 0% and above) |
| Max Completion % | **100** | Only apply the rule to downloads at or below this completion percentage |
| Ignore Above Size | *(empty)* | Skip downloads larger than this size (MB or GB). Useful for tolerating slow speeds on very large releases (e.g., Remux files) that naturally take longer |
| Reset Strikes on Progress | **Off** | When enabled, the strike count resets if the torrent shows download progress |

> [!TIP]
> Combine **Min Speed** and **Maximum Time** for layered detection — e.g., strike anything below 100 KB/s immediately, but also strike anything that has been downloading for over 8 hours regardless of speed. Use **Ignore Above Size** to exempt large Remux or 4K releases that are expected to be slow.

#### Per-App Configuration

Each rule category (Failed Import, Downloading Metadata, Stalled Download Rules, Slow Download Rules) can be configured independently per *arr app:

- **Sonarr (TV)**: More aggressive (lower timeouts, fewer strikes) — episodes are time-sensitive
- **Radarr (Movies)**: More patient (higher timeouts, more strikes) — rare releases may need longer to download
- **Lidarr (Music)**: Default settings — music releases are less time-sensitive

### Orphaned File Detection

Cleanuparr can detect and clean up files that are no longer useful:

- **No *arr reference** — files in the download directory not tracked by any *arr app's queue or history
- **No hardlinks** — files that exist in the download directory but have no hardlinks to the media library (suggesting the import failed or was never completed). Note: only reliable when *arr apps are configured for hardlinking, not copy
- **Cross-seed awareness** — can be configured to avoid removing files that are being cross-seeded

Always review detected orphans in the Cleanuparr UI before enabling automatic removal.

### Notifications

Cleanuparr can notify you when it takes action:

- **On strike** — when a download receives a new strike (useful for monitoring)
- **On removal** — when a download is removed and blocklisted

Configure notification targets in the Cleanuparr UI. Notifications help you spot patterns — if the same indexer or release group keeps getting strikes, investigate the root cause in Prowlarr or Recyclarr.

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

1. **Verify providers** — Settings → Providers → Test each one. Failed providers silently stop returning results
2. **Check score threshold** — lower the minimum score temporarily to see if subs are being found but rejected
3. **Verify Sonarr/Radarr connection** — Settings → Sonarr/Radarr → Test
4. **Check languages** — Language Profiles must be assigned to series/movies. Check Settings → Languages → Default Settings to auto-apply to new content
5. **Check adaptive searching** — if enabled, Bazarr may have deprioritized searches for content that previously had no results. Trigger a manual search to override
6. **Check scheduler** — Settings → Scheduler → verify search frequency isn't set too infrequently
7. **Provider issues** — anti-captcha failures (OpenSubtitles.com) or rate limiting (HTTP 429). Check `docker logs bazarr` for specific errors

### Cleanuparr Not Cleaning Up

1. **Verify API connections** — ensure each *arr app is connected and the API key is valid
2. **Check strike count** — downloads may not have accumulated enough strikes yet. Review strike history in the Cleanuparr UI
3. **Check timeout thresholds** — stalled timeout may be too high for your use case. Reduce from 30 min to 15 min if downloads sit too long
4. **Verify download client connection** — Cleanuparr needs access to qBittorrent to detect stalled/slow torrents
5. **Check exclusion rules** — downloads matching ignore filters (hashes, categories, tags, trackers) are skipped
6. **Review logs** — check `docker logs cleanuparr` for errors, skipped items, or connection failures

### Cleanuparr Too Aggressive

1. **Increase max strikes** — raise from 3 to 5 to give downloads more chances to recover
2. **Increase stalled timeout** — raise to 60 minutes if your indexers have intermittent seeder availability
3. **Disable speed/ETA checks** — set thresholds to 0 if slow downloads are being removed prematurely
4. **Add exclusions** — whitelist specific trackers or categories that are known to be slow but reliable

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
- [Bazarr Wiki](https://wiki.bazarr.media/) — Official Bazarr documentation (all settings, performance tuning, post-processing)
- [Cleanuparr GitHub](https://github.com/flmorg/cleanuperr) — Source repository and documentation
- [Recyclarr Documentation](https://recyclarr.dev/wiki/)
- [Recyclarr YAML Reference](https://recyclarr.dev/wiki/yaml/config-reference/)
- Internal: [NAS Deployment Checklist](nas-setup.md) — Initial *arr setup
- Internal: [VPN Setup](vpn-setup.md) — Gluetun configuration for download clients
- Internal: `docker/recyclarr.yml` — Recyclarr configuration source file
