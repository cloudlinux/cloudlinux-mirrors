# Combined CloudLinux and SWNG Mirror - Docker Setup

This Docker setup creates a containerized mirror of both CloudLinux and SWNG repositories that automatically syncs from `upstream.cloudlinux.com` using RSync.

## Prerequisites

- Docker or Docker Compose
- Sufficient disk space (500 GB - 1+ TB recommended)
- Network access to `rsync.upstream.cloudlinux.com`

## Resource Requirements

Approximate requirements:
- **CPU**: 2-4 cores recommended
- **Memory**: 2-4 GB RAM recommended
- **Disk**: 500 GB - 1+ TB recommended
- **Network**: Stable, high-bandwidth connection

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
mkdir -p mirror-data/cloudlinux mirror-data/swng logs
```

If you want to store data on a separate disk (e.g. `/storage`), create them there and set env vars.

Recommended: put them in a `.env` near with `docker-compose.yml`:

```bash
mkdir -p /storage/mirror-data/cloudlinux /storage/mirror-data/swng /storage/logs
cat > .env <<'EOF'
MIRROR_DATA_ROOT=/storage/mirror-data
LOGS_ROOT=/storage/logs
EOF
```
2. **Start the containers:**

```bash
DOCKER_BUILDKIT=1 docker build --network=host -t combined-mirror .
docker compose up -d --no-build
```

3. **View logs:**

```bash
docker-compose logs -f combined-mirror
```

### Using Docker

1. **Build the image:**

```bash
docker build -t combined-mirror .
```

2. **Run the container:**

```bash
docker run -d \
  --name combined-mirror \
  --restart unless-stopped \
  -v $(pwd)/mirror-data/cloudlinux:/var/www/mirrors/cloudlinux \
  -v $(pwd)/mirror-data/swng:/var/www/mirrors/swng \
  -v $(pwd)/logs:/var/log \
  -e SYNC_MODE=combined \
  -e INITIAL_SYNC=true \
  combined-mirror
```

## Configuration

### Sync Modes

#### Combined Mode (Default)

Both CloudLinux and SWNG sync together in a single operation.

**Advantages:**
- Simpler management
- Synchronized sync times
- Single log file

**Set in docker-compose.yml:**
```yaml
environment:
  - SYNC_MODE=combined
```

#### Separate Mode

CloudLinux and SWNG sync independently with separate schedules.

**Advantages:**
- Independent sync schedules
- Failure isolation
- Separate log files

**Set in docker-compose.yml:**
```yaml
environment:
  - SYNC_MODE=separate
```

### Environment Variables

- `SYNC_MODE`: Sync mode - `combined` or `separate` (default: `combined`)
- `CLOUDLINUX_RSYNC_SOURCE`: CloudLinux RSync source
- `SWNG_RSYNC_SOURCE`: SWNG RSync source
- `CLOUDLINUX_MIRROR_PATH`: CloudLinux mirror path
- `SWNG_MIRROR_PATH`: SWNG mirror path
- `INITIAL_SYNC`: Run initial sync on startup (default: `true`)
- `SYNC_INTERVAL_HOURS`: Sync interval in hours (default: `4`)

### Volume Mounts

- `./mirror-data/cloudlinux` - CloudLinux mirror data (persistent)
- `./mirror-data/swng` - SWNG mirror data (persistent)
- `./logs` - Log files (persistent)

## Usage

### View Sync Status

```bash
# View container logs
docker-compose logs -f combined-mirror

# View sync logs
tail -f logs/combined-mirror.log
# or for separate mode
tail -f logs/cloudlinux-mirror.log
tail -f logs/swng-mirror.log

# Check mirror data
ls -lh mirror-data/cloudlinux/
ls -lh mirror-data/swng/
```

### Manual Sync Trigger

```bash
# Combined mode
docker-compose exec combined-mirror /usr/local/bin/sync-combined.sh

# Separate mode
docker-compose exec combined-mirror /usr/local/bin/sync-cloudlinux.sh
docker-compose exec combined-mirror /usr/local/bin/sync-swng.sh
```

### Access via Web Server

The included Nginx container serves the mirrors on port 80:

```bash
# Access CloudLinux repositories
curl http://localhost/cloudlinux/

# Access SWNG repositories
curl http://localhost/swng/
```

### Stop Containers

```bash
docker-compose down
```

## Web Server Configuration

The `docker-compose.yml` includes an optional Nginx service to serve the mirrors. To disable it, comment out the `nginx` service.

### Custom Nginx Configuration

Edit `nginx.conf` to customize the web server configuration.

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
docker-compose logs combined-mirror

# Check container status
docker-compose ps
```

### Sync Failing

```bash
# Test RSync connectivity
docker-compose exec combined-mirror rsync rsync://rsync.upstream.cloudlinux.com/SWNG/
docker-compose exec combined-mirror rsync rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/

# Check disk space
docker-compose exec combined-mirror df -h

# View detailed sync log
docker-compose exec combined-mirror tail -f /var/log/combined-mirror.log
```

### Disk Space Issues

Monitor disk usage:

```bash
du -sh mirror-data/cloudlinux/
du -sh mirror-data/swng/
df -h
```

## Notes

- Initial sync may take several hours or even days for complete mirrors
- The container runs cron internally for scheduled syncs
- Mirror data persists in the `mirror-data` directory
- Logs are stored in the `logs` directory
- In combined mode, CloudLinux syncs first, then SWNG
- In separate mode, syncs run independently
