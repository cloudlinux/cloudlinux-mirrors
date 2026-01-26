# Combined CloudLinux and SWNG Mirror - Ansible Playbook

This Ansible playbook sets up a complete local mirror of both CloudLinux and SWNG repositories using RSync with automated updates via systemd timers.

## Prerequisites

- Ansible 2.9 or later
- Target server(s) with:
  - Sufficient disk space (several hundred GB to 1+ TB recommended)
  - Root or sudo access
  - Network access to `rsync.upstream.cloudlinux.com`
  - Systemd support

## Inventory Configuration

Edit `inventory.ini` to specify your mirror server(s):

```ini
[mirror_servers]
mirror-server-01 ansible_host=192.168.1.100
mirror-server-02 ansible_host=192.168.1.101

[mirror_servers:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

## Variables

Key variables you can customize:

- `mirror_base_path`: Base path for mirrors (default: `/var/www/mirrors`)
- `cloudlinux_mirror_path`: CloudLinux mirror directory (default: `/var/www/mirrors/cloudlinux`)
- `swng_mirror_path`: SWNG mirror directory (default: `/var/www/mirrors/swng`)
- `cloudlinux_rsync_source`: CloudLinux RSync source (default: `rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/`)
- `swng_rsync_source`: SWNG RSync source (default: `rsync://rsync.upstream.cloudlinux.com/SWNG/`)
- `sync_interval_hours`: Sync interval in hours (default: `4`)
- `timer_schedule`: Systemd timer schedule (default: `*-*-* 00,04,08,12,16,20:00:00`)
- `sync_mode`: Sync mode - `combined` (single timer) or `separate` (default: `combined`)

## Sync Modes

### Combined Mode (Default)

Both CloudLinux and SWNG sync in a single systemd service/timer. Both repositories sync together.

**Advantages:**
- Simpler management (one timer)
- Synchronized sync times
- Single log file

**Disadvantages:**
- If one fails, both are affected
- Longer sync time (both run sequentially)

### Separate Mode

CloudLinux and SWNG have separate systemd services/timers. They can sync independently.

**Advantages:**
- Independent sync schedules
- Failure isolation
- Separate log files

**Disadvantages:**
- More complex management
- More systemd units

## Usage

### Basic Usage (Combined Mode)

```bash
ansible-playbook -i inventory.ini playbook.yml
```

### Separate Mode

```bash
ansible-playbook -i inventory.ini playbook.yml -e "sync_mode=separate"
```

### With Custom Variables

```bash
ansible-playbook -i inventory.ini playbook.yml \
  -e "mirror_base_path=/opt/mirrors" \
  -e "sync_interval_hours=6" \
  -e "sync_mode=separate"
```

### Using a Variables File

Create `vars.yml`:

```yaml
mirror_base_path: /opt/mirrors
sync_interval_hours: 6
timer_schedule: "*-*-* 00,06,12,18:00:00"
sync_mode: separate
```

Run with:

```bash
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

## What the Playbook Does

1. Checks available disk space
2. Creates mirror directories for both CloudLinux and SWNG
3. Installs rsync if needed
4. Performs initial sync for both repositories (runs asynchronously)
5. Creates systemd service(s) for automated syncing
6. Creates systemd timer(s) for scheduled updates
7. Enables and starts the timer(s)
8. Installs and configures Nginx web server
9. Enables and starts Nginx to serve both mirrors

## Verification

After running the playbook, verify the setup:

### Combined Mode

```bash
# Check timer status
systemctl status cloudlinux-complete-mirror.timer

# List active timers
systemctl list-timers cloudlinux-complete-mirror.timer

# Check sync log
tail -f /var/log/cloudlinux-complete-mirror.log

# Verify mirror directories
ls -lh /var/www/mirrors/cloudlinux/
ls -lh /var/www/mirrors/swng/
```

### Separate Mode

```bash
# Check timer status
systemctl status cloudlinux-mirror.timer swng-mirror.timer

# List active timers
systemctl list-timers cloudlinux-mirror.timer swng-mirror.timer

# Check sync logs
tail -f /var/log/cloudlinux-mirror.log
tail -f /var/log/swng-mirror.log

# Verify mirror directories
ls -lh /var/www/mirrors/cloudlinux/
ls -lh /var/www/mirrors/swng/

# Check Nginx status
systemctl status nginx

# Test web access
curl http://localhost/cloudlinux/
curl http://localhost/swng/
```

## Accessing the Mirrors via Web

The playbook configures Nginx to serve both mirrors on port 80. You can access them via:

- **CloudLinux**: `http://localhost/cloudlinux/` or `http://<server-ip>/cloudlinux/`
- **SWNG**: `http://localhost/swng/` or `http://<server-ip>/swng/`

The Nginx configuration enables directory browsing, so you can navigate the repository structure through a web browser.

## Notes

- The initial sync runs asynchronously and may take several hours (or even days for complete mirrors)
- Monitor the log file(s) to track sync progress
- Ensure sufficient disk space before running (1+ TB recommended for complete mirrors)
- The timer will automatically sync every 4 hours by default
- In combined mode, CloudLinux syncs first, then SWNG
- In separate mode, timers can be configured with different schedules if needed

## Disk Space Requirements

Approximate disk space requirements:

- **CloudLinux only**: 200-500 GB
- **SWNG only**: 200-500 GB
- **Combined**: 500 GB - 1+ TB

These are rough estimates and will vary based on:
- CloudLinux versions included
- Architecture (x86_64, aarch64, etc.)
- Repository components (BaseOS, AppStream, Extras, etc.)

## Best Practices

1. **Initial Sync**: Run initial sync manually or during off-peak hours
2. **Monitoring**: Set up log monitoring and alerts
3. **Backup**: Consider backing up repository metadata
4. **Bandwidth**: Use `--bwlimit` in rsync if needed to limit bandwidth
5. **Storage**: Use fast storage (SSD) for better performance
6. **Network**: Ensure stable network connection for syncs
