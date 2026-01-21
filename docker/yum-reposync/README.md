# SWNG Mirror with yum-reposync - Docker Setup

This Docker setup creates a containerized SWNG repository mirror using `yum-reposync` (reposync) that automatically syncs from `upstream.cloudlinux.com`.

## Prerequisites

- Docker or Docker Compose
- Sufficient disk space (varies by repositories selected)
- Network access to `upstream.cloudlinux.com`
- CloudLinux or RHEL/CentOS base image

## Quick Start

### Using Docker Compose (Recommended)

1. **Create directories for data and logs:**

```bash
mkdir -p mirror-data logs
```

2. **Start the container:**

```bash
docker-compose up -d
```

3. **View logs:**

```bash
docker-compose logs -f swng-reposync
```

### Using Docker

1. **Build the image:**

```bash
docker build -t swng-reposync .
```

2. **Run the container:**

```bash
docker run -d \
  --name swng-reposync \
  --restart unless-stopped \
  -v $(pwd)/mirror-data:/var/www/mirrors/swng \
  -v $(pwd)/logs:/var/log \
  -e REPOS="SWNG-9-x86_64 SWNG-8-x86_64" \
  -e INITIAL_SYNC=true \
  swng-reposync
```

## Configuration

### Environment Variables

- `MIRROR_PATH`: Mirror destination path (default: `/var/www/mirrors/swng`)
- `LOG_FILE`: Log file path (default: `/var/log/swng-reposync.log`)
- `REPOS`: Space-separated list of repositories to sync (default: `SWNG-9-x86_64 SWNG-8-x86_64`)
- `INITIAL_SYNC`: Run initial sync on startup (default: `true`)
- `SYNC_INTERVAL_HOURS`: Sync interval in hours (default: `6`)

### Repository Configuration

Edit `swng-upstream.repo` to add or modify repositories. Available repositories:

- `SWNG-9-x86_64` - CloudLinux 9 SWNG x86_64
- `SWNG-8-x86_64` - CloudLinux 8 SWNG x86_64
- `SWNG-9-aarch64` - CloudLinux 9 SWNG aarch64 (if available)
- `SWNG-8-aarch64` - CloudLinux 8 SWNG aarch64 (if available)

### Sync Only Specific Repositories

Edit `docker-compose.yml`:

```yaml
environment:
  - REPOS=SWNG-9-x86_64  # Only sync CloudLinux 9
```

Or for multiple:

```yaml
environment:
  - REPOS=SWNG-9-x86_64 SWNG-9-aarch64
```

## Usage

### View Sync Status

```bash
# View container logs
docker-compose logs -f swng-reposync

# View sync log
tail -f logs/swng-reposync.log

# Check mirror data
ls -lh mirror-data/
```

### Manual Sync Trigger

```bash
# Execute sync script manually
docker-compose exec swng-reposync /usr/local/bin/sync-script.sh
```

### Update Repository Configuration

1. Edit `swng-upstream.repo` to add/modify repositories
2. Rebuild the image: `docker-compose build`
3. Restart: `docker-compose up -d`

## Differences from RSync Method

- **yum-reposync**: Uses YUM repository configuration, better for selective repository mirroring
- **RSync**: More efficient for complete mirroring, better for bandwidth usage
- Choose based on your needs: selective repos (yum-reposync) vs complete mirror (RSync)

## Notes

- Initial sync may take several hours
- The container runs cron internally for scheduled syncs
- Repository metadata is automatically regenerated after each sync
- Mirror data persists in the `mirror-data` directory
- Logs are stored in the `logs` directory
- Only repositories listed in `REPOS` environment variable will be synced
