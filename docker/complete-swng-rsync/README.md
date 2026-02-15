# Complete SWNG Mirror - Docker Setup

This Docker setup creates a containerized SWNG repository mirror that automatically syncs from `upstream.cloudlinux.com` using RSync.

## Prerequisites

- Docker or Docker Compose
- Sufficient disk space (several hundred GB recommended)
- Network access to `rsync.upstream.cloudlinux.com`

## Resource Requirements

Approximate requirements:
- **CPU**: 2-4 cores recommended
- **Memory**: 2-4 GB RAM recommended
- **Disk**: 500 GB - 1+ TB recommended
- **Network**: Stable, high-bandwidth connection

### Environment Variables

Edit `docker-compose.yml` or pass as environment variables:

- `RSYNC_SOURCE`: RSync source URL (default: `rsync://rsync.upstream.cloudlinux.com/SWNG/`)
- `MIRROR_PATH`: Mirror destination path (default: `/var/www/mirrors/swng`)
- `LOG_FILE`: Log file path (default: `/var/log/swng-mirror.log`)
- `INITIAL_SYNC`: Run initial sync on startup (default: `true`)
- `SYNC_INTERVAL_HOURS`: Sync interval in hours (default: `4`)
- `CERTBOT_EMAIL`: Email for Let's Encrypt registration (default: `admin@example.com`)
- `CERTBOT_DOMAIN`: Public domain for the mirror (default: `mirror.example.com`)

### Volume Mounts

- `./mirror-data` - Mirror repository data (persistent)
- `./logs` - Log files (persistent)
- `certbot-etc` - Let's Encrypt certificates (persistent volume)
- `certbot-www` - ACME webroot (persistent volume)

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
mkdir -p /storage/mirror-data/cloudlinux /storage/mirror-data/swng /storage/logs
cat > .env <<'EOF'
MIRROR_DATA_ROOT=/storage/mirror-data-swng
LOGS_ROOT=/storage/logs-swng
CERTBOT_EMAIL=admin@example.com
CERTBOT_DOMAIN=mirror.example.com
EOF
```
Make sure `CERTBOT_DOMAIN` points to this server (DNS A/AAAA record).
2. **Open ports 80/443** and ensure the domain resolves to this host.
3. **Start the container:**

```bash
DOCKER_BUILDKIT=1 docker build --network=host -t swng-mirror .
docker compose up -d --no-build
```

4. **View logs:**

```bash
docker-compose logs -f
```

On first run, Nginx starts in HTTP-only mode for ACME. Once the certificate is issued,
it will automatically reload and enable HTTPS.

### Using Docker

1. **Build the image:**

```bash
docker build -t swng-mirror .
```

2. **Run the container:**

```bash
docker run -d \
  --name swng-mirror \
  --restart unless-stopped \
  -v $(pwd)/mirror-data:/var/www/mirrors/swng \
  -v $(pwd)/logs:/var/log \
  -e INITIAL_SYNC=true \
  swng-mirror
```

## Usage

### View Sync Status

```bash
# View container logs
docker-compose logs -f swng-mirror

# View sync log
tail -f logs/swng-mirror.log
or
docker compose exec swng-mirror tail -n 20 /var/log/swng-mirror.log

# Check mirror data
ls -lh mirror-data/
```

### Manual Sync Trigger

```bash
# Execute sync script manually
docker-compose exec swng-mirror /usr/local/bin/sync-script.sh
```

### Stop Container

```bash
docker-compose down
```

### Update Sync Schedule

1. Edit the Dockerfile to change the cron schedule
2. Rebuild the image: `docker-compose build`
3. Restart: `docker-compose up -d`

## Accessing the Mirror via Web

The Docker Compose setup includes an Nginx service that automatically serves the mirror. The mirror is accessible via:

- **Local access**: `http://localhost/swng/`
- **Network access**: `http://<server-ip>/swng/`
- **HTTPS access**: `https://<your-domain>/swng/` (Let's Encrypt via certbot)

The Nginx configuration enables directory browsing, so you can navigate the repository structure through a web browser.

### Nginx Service

The `docker-compose.yml` includes a pre-configured Nginx service that:
- Serves the mirror data from the `mirror-data` directory
- Enables directory browsing
- Runs on port 80
- Automatically starts with the mirror container

## Troubleshooting

### Container Won't Start

```bash
# Check container logs
docker-compose logs swng-mirror

# Check container status
docker-compose ps
```

### Let's Encrypt Issues

```bash
# Check certbot logs
docker-compose logs certbot

# Ensure the ACME challenge is reachable
curl -I http://<your-domain>/.well-known/acme-challenge/test
```

### Sync Failing

```bash
# Test RSync connectivity
docker-compose exec swng-mirror rsync rsync://rsync.upstream.cloudlinux.com/

# Check disk space
docker-compose exec swng-mirror df -h

# View detailed sync log
docker-compose exec swng-mirror tail -f /var/log/swng-mirror.log
```

### Disk Space Issues

Monitor disk usage:

```bash
du -sh mirror-data/
df -h
```

## Notes

- Initial sync may take several hours
- The container runs cron internally for scheduled syncs
- Mirror data persists in the `mirror-data` directory
- Logs are stored in the `logs` directory
