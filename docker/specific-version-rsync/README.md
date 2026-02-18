# Specific SWNG Version Mirror - Docker Setup

### This is recomended type of instalation
This Docker setup creates a containerized SWNG repository mirror for CloudLinux 10 that automatically syncs from `upstream.cloudlinux.com` using RSync.

## Prerequisites

- Docker or Docker Compose
- Sufficient disk space (100-200 GB per version recommended)
- Network access to `rsync.upstream.cloudlinux.com`

## Resource Requirements

Approximate requirements:
- **CPU**: 2-4 cores recommended
- **Memory**: 2-4 GB RAM recommended
- **Disk**: 500 GB - 1+ TB recommended
- **Network**: Stable, high-bandwidth connection

### Environment Variables

- `CLOUDLINUX_VERSION`: CloudLinux version to mirror (required: `10`)
- `RSYNC_SOURCE`: RSync source URL (auto-generated based on version)
- `MIRROR_PATH`: Mirror destination path (auto-generated based on version)
- `LOG_FILE`: Log file path (auto-generated based on version)
- `INITIAL_SYNC`: Run initial sync on startup (default: `true`)
- `SYNC_INTERVAL_HOURS`: Sync interval in hours (default: `6`)
- `CERTBOT_EMAIL`: Email for Let's Encrypt registration (default: `admin@example.com`)
- `CERTBOT_DOMAIN`: Public domain for the mirror (default: `mirror.example.com`)

### Volume Mounts

- `./mirror-data/10` - Mirror repository data for CloudLinux 10 (persistent)
- `./mirror-data/8` - Mirror repository data for CloudLinux 8 (persistent)
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
mkdir -p mirror-data/10 logs
#for both versions
mkdir -p /storage/mirror-data/10 /storage/logs
```

If you want to store data on a separate disk (e.g. `/storage`), create them there and set env vars.

Recommended: put them in a `.env` near with `docker-compose.yml`:

```bash
cat > .env <<'EOF'
MIRROR_DATA_ROOT=/storage/mirror-data
LOGS_ROOT=/storage/logs
CERTBOT_EMAIL=admin@example.com
CERTBOT_DOMAIN=mirror.example.com
EOF
```
Make sure `CERTBOT_DOMAIN` points to this server (DNS A/AAAA record) and ports 80/443 are open.

2. **Start the container:**

```bash
DOCKER_BUILDKIT=1 docker build --network=host -t swng-version-mirror .
docker compose up -d --no-build
```

3. **View logs:**

```bash
docker-compose logs -f swng-10-mirror
```
On first run, Nginx starts in HTTP-only mode for ACME. Once the certificate is issued,
it will automatically reload and enable HTTPS.

### Using Docker

1. **Build the image:**

```bash
docker build -t swng-version-mirror .
```

2. **Run the container for CloudLinux 10:**

```bash
docker run -d \
  --name swng-10-mirror \
  --restart unless-stopped \
  -v $(pwd)/mirror-data/10:/var/www/mirrors/swng/10 \
  -v $(pwd)/logs:/var/log \
  -e CLOUDLINUX_VERSION=10 \
  -e INITIAL_SYNC=true \
  swng-version-mirror
```

## Usage

### View Sync Status

```bash
# View container logs
docker-compose logs -f swng-10-mirror

# View sync log
tail -f logs/swng-10-mirror.log

# Check mirror data
ls -lh mirror-data/10/
```

### Manual Sync Trigger

```bash
# Execute sync script manually
docker-compose exec swng-10-mirror /usr/local/bin/sync-script.sh
```

## Accessing the Mirror via Web

The Docker Compose setup includes an Nginx service that automatically serves the mirrors. The mirrors are accessible via:

- **CloudLinux 10**: `http://localhost/swng/10/`
- **CloudLinux 8**: `http://localhost/swng/8/` (Temporary unavalible)
- **Network access**: `http://<server-ip>/swng/<version>/`
 - **HTTPS**: `https://<your-domain>/swng/<version>/`

The Nginx configuration enables directory browsing, so you can navigate the repository structure through a web browser.

### Nginx Service

The `docker-compose.yml` includes a pre-configured Nginx service that:
- Serves the mirror data from the `mirror-data` directory
- Enables directory browsing for each version
- Runs on ports 80/443
- Automatically starts with the mirror containers

## Notes

- Each version requires its own container
- Initial sync may take several hours per version
- The container runs cron internally for scheduled syncs
- Mirror data persists in the `mirror-data` directory
- Logs are stored in the `logs` directory
- Nginx automatically serves the mirrors via HTTP/HTTPS
