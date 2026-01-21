# Complete SWNG Mirror with RSync - Ansible Playbook

This Ansible playbook sets up a complete local mirror of all SWNG repositories using RSync with automated updates via systemd timers.

## Prerequisites

- Ansible 2.9 or later
- Target server(s) with:
  - Sufficient disk space (several hundred GB recommended)
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

You can customize the playbook by overriding variables:

- `mirror_base_path`: Base path for mirrors (default: `/var/www/mirrors`)
- `swng_mirror_path`: SWNG mirror directory (default: `/var/www/mirrors/swng`)
- `rsync_source`: RSync source URL (default: `rsync://rsync.upstream.cloudlinux.com/SWNG/`)
- `sync_log_file`: Log file path (default: `/var/log/swng-mirror.log`)
- `sync_interval_hours`: Sync interval in hours (default: `4`)
- `timer_schedule`: Systemd timer schedule (default: `*-*-* 00,04,08,12,16,20:00:00`)

## Usage

### Basic Usage

```bash
ansible-playbook -i inventory.ini playbook.yml
```

### With Custom Variables

```bash
ansible-playbook -i inventory.ini playbook.yml \
  -e "mirror_base_path=/opt/mirrors" \
  -e "sync_interval_hours=6"
```

### Using a Variables File

Create `vars.yml`:

```yaml
mirror_base_path: /opt/mirrors
swng_mirror_path: /opt/mirrors/swng
sync_interval_hours: 6
timer_schedule: "*-*-* 00,06,12,18:00:00"
```

Run with:

```bash
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

## What the Playbook Does

1. Checks available disk space
2. Creates mirror directory structure
3. Installs rsync if needed
4. Performs initial repository sync (runs asynchronously)
5. Creates systemd service for automated syncing
6. Creates systemd timer for scheduled updates
7. Enables and starts the timer

## Verification

After running the playbook, verify the setup:

```bash
# Check timer status
systemctl status swng-mirror.timer

# List active timers
systemctl list-timers swng-mirror.timer

# Check sync log
tail -f /var/log/swng-mirror.log

# Verify mirror directory
ls -lh /var/www/mirrors/swng/
```

## Notes

- The initial sync runs asynchronously and may take several hours
- Monitor the log file to track sync progress
- Ensure sufficient disk space before running
- The timer will automatically sync every 4 hours by default
