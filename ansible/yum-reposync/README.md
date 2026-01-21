# SWNG Mirror with yum-reposync - Ansible Playbook

This Ansible playbook sets up a local mirror of SWNG repositories using `yum-reposync` (reposync) with automated updates via systemd timers.

## Prerequisites

- Ansible 2.9 or later
- Target server(s) with:
  - CloudLinux or RHEL/CentOS 7/8/9
  - Sufficient disk space (varies by repositories selected)
  - Root or sudo access
  - Network access to `upstream.cloudlinux.com`
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
- `swng_mirror_path`: SWNG mirror directory (default: `/var/www/mirrors/swng`)
- `sync_log_file`: Log file path (default: `/var/log/swng-reposync.log`)
- `sync_interval_hours`: Sync interval in hours (default: `6`)
- `timer_schedule`: Systemd timer schedule (default: `*-*-* 00,06,12,18:00:00`)
- `swng_repos`: List of repositories to sync (see example below)

## Repository Configuration

The `swng_repos` variable defines which repositories to sync. Default configuration:

```yaml
swng_repos:
  - name: SWNG-9-x86_64
    baseurl: https://upstream.cloudlinux.com/swng/9/x86_64/
    enabled: true
  - name: SWNG-8-x86_64
    baseurl: https://upstream.cloudlinux.com/swng/8/x86_64/
    enabled: true
```

## Usage

### Basic Usage (Default Repositories)

```bash
ansible-playbook -i inventory.ini playbook.yml
```

### With Custom Variables

```bash
ansible-playbook -i inventory.ini playbook.yml \
  -e "mirror_base_path=/opt/mirrors" \
  -e "sync_interval_hours=4"
```

### Sync Only CloudLinux 9 SWNG

Create `vars.yml`:

```yaml
swng_repos:
  - name: SWNG-9-x86_64
    baseurl: https://upstream.cloudlinux.com/swng/9/x86_64/
    enabled: true
```

Run with:

```bash
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

### Sync Only CloudLinux 8 SWNG

Create `vars.yml`:

```yaml
swng_repos:
  - name: SWNG-8-x86_64
    baseurl: https://upstream.cloudlinux.com/swng/8/x86_64/
    enabled: true
```

Run with:

```bash
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

### Custom Repository List

Create `vars.yml` with multiple repositories:

```yaml
swng_repos:
  - name: SWNG-9-x86_64
    baseurl: https://upstream.cloudlinux.com/swng/9/x86_64/
    enabled: true
  - name: SWNG-8-x86_64
    baseurl: https://upstream.cloudlinux.com/swng/8/x86_64/
    enabled: true
  - name: SWNG-9-aarch64
    baseurl: https://upstream.cloudlinux.com/swng/9/aarch64/
    enabled: true
sync_interval_hours: 4
timer_schedule: "*-*-* 00,04,08,12,16,20:00:00"
```

Run with:

```bash
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

## What the Playbook Does

1. Checks available disk space
2. Installs `yum-utils` and `createrepo` packages
3. Creates mirror directory structure
4. Creates YUM repository configuration file (`/etc/yum.repos.d/swng-upstream.repo`)
5. Imports CloudLinux GPG key
6. Performs initial repository sync using `reposync`
7. Updates repository metadata using `createrepo`
8. Creates systemd service for automated syncing
9. Creates systemd timer for scheduled updates
10. Enables and starts the timer

## Verification

After running the playbook, verify the setup:

```bash
# Check timer status
systemctl status swng-reposync.timer

# List active timers
systemctl list-timers swng-reposync.timer

# Check sync log
tail -f /var/log/swng-reposync.log

# Verify repository configuration
cat /etc/yum.repos.d/swng-upstream.repo

# Verify synced repositories
ls -lh /var/www/mirrors/swng/
```

## Notes

- The initial sync runs asynchronously and may take several hours
- Monitor the log file to track sync progress
- Ensure sufficient disk space before running
- The timer will automatically sync every 6 hours by default
- Repository metadata is automatically regenerated after each sync
- Only repositories with `enabled: true` will be synced

## Differences from RSync Method

- **yum-reposync**: Uses YUM repository configuration, better for selective repository mirroring
- **RSync**: More efficient for complete mirroring, better for bandwidth usage
- Choose based on your needs: selective repos (yum-reposync) vs complete mirror (RSync)
