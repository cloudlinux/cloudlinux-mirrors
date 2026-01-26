# Complete SWNG Mirror - Docker Setup

This Docker setup creates a containerized SWNG repository mirror that automatically syncs from `upstream.cloudlinux.com` using RSync.

## Prerequisites

- Docker or Docker Compose
- Sufficient disk space (several hundred GB recommended)
- Network access to `rsync.upstream.cloudlinux.com`

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
docker-compose logs -f
```

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

## Configuration

### Environment Variables

Edit `docker-compose.yml` or pass as environment variables:

- `RSYNC_SOURCE`: RSync source URL (default: `rsync://rsync.upstream.cloudlinux.com/SWNG/`)
- `MIRROR_PATH`: Mirror destination path (default: `/var/www/mirrors/swng`)
- `LOG_FILE`: Log file path (default: `/var/log/swng-mirror.log`)
- `INITIAL_SYNC`: Run initial sync on startup (default: `true`)
- `SYNC_INTERVAL_HOURS`: Sync interval in hours (default: `4`)

### Sync Schedule

The sync runs every 4 hours by default. To change the schedule, edit the cron job in the Dockerfile or modify `sync-script.sh`.

### Volume Mounts

- `./mirror-data` - Mirror repository data (persistent)
- `./logs` - Log files (persistent)

## Usage

### View Sync Status

```bash
# View container logs
docker-compose logs -f swng-mirror

# View sync log
tail -f logs/swng-mirror.log

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
