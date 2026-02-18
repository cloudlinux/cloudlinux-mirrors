# Docker and Docker Compose Setups for CloudLinux Mirroring

This directory contains Docker and Docker Compose configurations for automating CloudLinux and SWNG repository mirroring using `upstream.cloudlinux.com`.

## Available Docker Setups

### 1. Complete SWNG Mirror with RSync
**Directory:** `complete-swng-rsync/`

Complete local mirror of all SWNG repositories using RSync with automated updates via cron.

**Use Case:** When you need the complete SWNG repository mirror in a container.

**Features:**
- Complete SWNG mirror
- RSync-based synchronization
- Cron-based automated updates
- Configurable sync intervals

### 2. Specific SWNG Version Mirror with RSync (Recomended)
**Directory:** `specific-version-rsync/`

Local mirror of a specific CloudLinux version SWNG repositories (10) using RSync.

**Use Case:** When you only need specific CloudLinux versions in containers.

**Features:**
- Version-specific mirroring
- RSync-based synchronization
- Cron-based automated updates
- Supports CloudLinux 10

### 3. SWNG Mirror with yum-reposync
**Directory:** `yum-reposync/`

Local mirror of SWNG repositories using `yum-reposync` (reposync) with automated updates.

**Use Case:** When you need selective repository mirroring with YUM repository configuration in containers.

**Features:**
- Selective repository mirroring
- YUM repository configuration
- Automatic metadata generation
- Cron-based automated updates

### 4. Combined CloudLinux and SWNG Mirror
**Directory:** `combined-mirror/`

Complete local mirror of both CloudLinux and SWNG repositories using RSync.

**Use Case:** When you need both CloudLinux and SWNG mirrors in containers.

**Features:**
- Combined CloudLinux and SWNG mirroring
- RSync-based synchronization
- Two sync modes: combined or separate
- Optional Nginx web server included
- Cron-based automated updates

## Quick Start

### Prerequisites

- Docker or Docker Compose installed
- Sufficient disk space (varies by setup)
- Network access to `upstream.cloudlinux.com` or `rsync.upstream.cloudlinux.com`

### Basic Usage

1. **Choose a setup** based on your needs
2. **Navigate to the directory:**

```bash
cd <setup-directory>
```

3. **Create data directories:**

```bash
mkdir -p mirror-data logs
```

4. **Start with Docker Compose:**

```bash
docker-compose up -d
```

5. **View logs:**

```bash
docker-compose logs -f
```

## Setup Comparison

| Feature | Complete SWNG RSync | Specific Version RSync | yum-reposync | Combined Mirror |
|---------|---------------------|------------------------|--------------|-----------------|
| Repository Type | SWNG only | SWNG (version-specific) | SWNG (selective) | CloudLinux + SWNG |
| Sync Method | RSync | RSync | reposync | RSync |
| Disk Space | ~200-500 GB | ~100-200 GB | Varies | ~500 GB - 1+ TB |
| Sync Speed | Fast | Fast | Moderate | Fast |
| Selectivity | Complete | Version-based | Repository-based | Complete |
| Web Server | No | No | No | Yes (optional) |
| Best For | Complete SWNG | Specific versions | Selective repos | Complete setup |

## Common Operations

### View Logs

```bash
# Container logs
docker-compose logs -f

# Sync log files
tail -f logs/*.log
```

### Manual Sync

```bash
# Execute sync script
docker-compose exec <service-name> /usr/local/bin/sync-script.sh
```

### Stop Containers

```bash
docker-compose down
```

### Restart Containers

```bash
docker-compose restart
```

### Update Configuration

1. Edit configuration files
2. Rebuild: `docker-compose build`
3. Restart: `docker-compose up -d`

## Volume Management

All setups use Docker volumes for persistent storage:

- **Mirror Data**: Stored in `./mirror-data/` (or subdirectories)
- **Logs**: Stored in `./logs/`

### Backup Recommendations

```bash
# Backup mirror data
tar -czf mirror-backup-$(date +%Y%m%d).tar.gz mirror-data/

# Backup logs
tar -czf logs-backup-$(date +%Y%m%d).tar.gz logs/
```

## Resource Requirements

### CPU and Memory

- **Complete SWNG**: 2 CPU, 2 GB RAM
- **Specific Version**: 2 CPU, 2 GB RAM
- **yum-reposync**: 2 CPU, 2 GB RAM
- **Combined Mirror**: 4 CPU, 4 GB RAM

### Disk Space

- **Complete SWNG**: ~500 GB
- **Specific Version**: 100-200 GB per version
- **yum-reposync**: Varies by repositories
- **Combined Mirror**: SWNG (~500 GB) + CloudLinux repository (3+ TB)

**Recommendations:**
- Use a dedicated disk or partition for mirror storage.
- In most cases, sync `repo.cloudlinux.com` only partially (only the repositories you need).

## Network Considerations

### Bandwidth

- Initial syncs can use significant bandwidth
- Consider scheduling during off-peak hours
- Use `--bwlimit` in rsync scripts if needed

### Firewall

Ensure the following are accessible:
- `rsync.upstream.cloudlinux.com` (port 873)
- `upstream.cloudlinux.com` (ports 80, 443)

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs

# Check container status
docker-compose ps

# Check system resources
docker stats
```

### Sync Failing

```bash
# Test connectivity
docker-compose exec <service> rsync rsync://rsync.upstream.cloudlinux.com/

# Check disk space
docker-compose exec <service> df -h

# View detailed logs
docker-compose exec <service> tail -f /var/log/*.log
```

### Disk Space Issues

```bash
# Check disk usage
du -sh mirror-data/
df -h

# Clean up old data if needed
docker system prune -a
```

### Permission Issues

```bash
# Fix permissions
sudo chown -R $(id -u):$(id -g) mirror-data/ logs/
```

## Customization

### Change Sync Schedule

Edit the cron job in the Dockerfile or modify the sync script.

### Add Custom Scripts

Add custom scripts to the container by:
1. Creating the script
2. Adding `COPY` command in Dockerfile
3. Making it executable
4. Rebuilding the image

### Environment Variables

Each setup supports environment variables for configuration. See individual README files for details.

## Serving Mirrors

### Using Included Nginx (Combined Mirror)

The combined mirror setup includes an optional Nginx service. Access mirrors at:
- `http://localhost/cloudlinux/`
- `http://localhost/swng/`

### Custom Web Server

You can add your own web server service to any `docker-compose.yml`:

```yaml
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./mirror-data:/storage:ro
    depends_on:
      - <mirror-service>
```

## Best Practices

1. **Monitor Logs**: Regularly check sync logs for errors
2. **Disk Space**: Monitor disk usage and plan for growth
3. **Backups**: Regularly backup mirror data
4. **Updates**: Keep Docker images updated
5. **Resource Limits**: Set appropriate resource limits
6. **Network**: Use stable, high-bandwidth connections
7. **Security**: Keep containers updated and use proper access controls

## Next Steps

After setting up your mirror:

1. **Verify mirror is accessible** via HTTP/HTTPS
2. **Contact CloudLinux support** to add your mirror to rotation
3. **Monitor sync logs** regularly
4. **Set up alerts** for sync failures

For more information about adding your mirror to CloudLinux rotation, see the main documentation in `../docs/upstream.cloudlinux.com-customer-guide.md`.

## Support

For issues or questions:
- Review the individual setup README files
- Check the main documentation: `../docs/upstream.cloudlinux.com-customer-guide.md`
- Contact CloudLinux support
