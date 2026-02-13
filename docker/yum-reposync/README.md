# SWNG Mirror with yum-reposync - Docker Setup

This Docker setup creates a containerized SWNG repository mirror using `yum-reposync` (reposync) that automatically syncs from `upstream.cloudlinux.com`.

## Prerequisites

- Docker or Docker Compose
- Sufficient disk space (varies by repositories selected)
- Network access to `upstream.cloudlinux.com`
- CloudLinux or RHEL/CentOS base image

## Resource Requirements

Approximate requirements:
- **CPU**: 2-4 cores recommended
- **Memory**: 2-4 GB RAM recommended
- **Disk**: 500 GB - 1+ TB recommended
- **Network**: Stable, high-bandwidth connection

### Environment Variables

- `MIRROR_PATH`: Mirror destination path (default: `/var/www/mirrors/swng`)
- `LOG_FILE`: Log file path (default: `/var/log/swng-reposync.log`)
- `REPOS`: Space-separated list of repositories to sync (default: `SWNG-9-x86_64 SWNG-8-x86_64`)
- `INITIAL_SYNC`: Run initial sync on startup (default: `true`)
- `SYNC_INTERVAL_HOURS`: Sync interval in hours (default: `6`)

## Quick Start

### Using Docker Compose (Recommended)
**Check that docker/compose installed**
```bash
docker --version
docker compose version || docker-compose --version
```
**If docker/compose not installed**
```bash
dnf -y install dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
```

1. **Create directories for data and logs:**

```bash
mkdir -p mirror-data logs
```

If you want to store data on a separate disk (e.g. `/storage`), create them there and set env vars.

Recommended: put them in a `.env` near with `docker-compose.yml`:

```bash
cat > .env <<'EOF'
MIRROR_DATA_ROOT=/storage/mirror-data
LOGS_ROOT=/storage/logs
EOF
```
2. **Start the container:**

```bash
DOCKER_BUILDKIT=1 docker build --network=host -t swng-reposync .
docker compose up -d --no-build
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

## Accessing the Mirror via Web

The Docker Compose setup includes an Nginx service that automatically serves the mirror. The mirror is accessible via:

- **Local access**: `http://localhost/swng/`
- **Network access**: `http://<server-ip>/swng/`

The Nginx configuration enables directory browsing, so you can navigate the repository structure through a web browser.

### Nginx Service

The `docker-compose.yml` includes a pre-configured Nginx service that:
- Serves the mirror data from the `mirror-data` directory
- Enables directory browsing
- Runs on port 80
- Automatically starts with the mirror container

## Notes

- Initial sync may take several hours
- The container runs cron internally for scheduled syncs
- Repository metadata is automatically regenerated after each sync
- Mirror data persists in the `mirror-data` directory
- Logs are stored in the `logs` directory
- Only repositories listed in `REPOS` environment variable will be synced
- Nginx automatically serves the mirrors via HTTP
