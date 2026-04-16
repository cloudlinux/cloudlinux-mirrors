# Ansible Playbooks for CloudLinux Mirror Setup

This directory contains Ansible playbooks for automating the setup of CloudLinux and SWNG repository mirrors using `upstream.cloudlinux.com`.

## Available Playbooks

### 1. Complete SWNG Mirror with RSync
**Directory:** `complete-swng-rsync/`

Sets up a complete local mirror of all SWNG repositories using RSync with automated updates via systemd timers.

**Use Case:** When you need the complete SWNG repository mirror.

**Features:**
- Complete SWNG mirror
- RSync-based synchronization
- Systemd timer for automated updates
- Configurable sync intervals

### 2. Specific SWNG Version Mirror with RSync (Recomended)
**Directory:** `specific-version-rsync/`

Sets up a local mirror of a specific CloudLinux version's SWNG repositories (e.g., only CloudLinux 8 or CloudLinux 9).

**Use Case:** When you only need specific CloudLinux versions.

**Features:**
- Version-specific mirroring
- RSync-based synchronization
- Systemd timer for automated updates
- Supports CloudLinux 10

### 3. SWNG Mirror with yum-reposync
**Directory:** `yum-reposync/`

Sets up a local mirror of SWNG repositories using `yum-reposync` (reposync) with automated updates.

**Use Case:** When you need selective repository mirroring with YUM repository configuration.

**Features:**
- Selective repository mirroring
- YUM repository configuration
- Automatic metadata generation
- Systemd timer for automated updates

### 4. Combined CloudLinux and SWNG Mirror
**Directory:** `combined-mirror/`

Sets up a complete local mirror of both CloudLinux and SWNG repositories using RSync.

**Use Case:** When you need both CloudLinux and SWNG mirrors.

**Features:**
- Combined CloudLinux and SWNG mirroring
- RSync-based synchronization
- Two sync modes: combined or separate timers
- Systemd timer(s) for automated updates

## Quick Start

1. **Choose a playbook** based on your needs
2. **Edit the inventory file** (`inventory.ini`) in the chosen directory
3. **Review and customize variables** (`defaults/main.yml`) if needed
4. **Run the playbook:**

```bash
cd <playbook-directory>
ansible-playbook -i inventory.ini playbook.yml
```

## Prerequisites

- Ansible 2.9 or later
- Target server(s) with:
  - OS almalinux 9 or 10
  - Sufficient disk space (varies by playbook)
  - Root or sudo access
  - Network access to `upstream.cloudlinux.com` or `rsync.upstream.cloudlinux.com`
  - Systemd support

**Storage recommendation:**
- Use a dedicated disk or partition for mirror storage.
- SWNG is ~500 GB; the full `repo.cloudlinux.com` repository is 3+ TB.
- In most cases, sync `repo.cloudlinux.com` only partially (only the repositories you need).

## Common Variables

Most playbooks support these common variables:

- `mirror_base_path`: Base path for mirrors (default: `/var/www/mirrors`)
- `sync_interval_hours`: Sync interval in hours (default: `4` or `6`)
- `timer_schedule`: Systemd timer schedule (Cron format)

## Playbook Comparison

| Feature | Complete SWNG RSync | Specific Version RSync | yum-reposync | Combined Mirror |
|---------|---------------------|------------------------|--------------|-----------------|
| Repository Type | SWNG only | SWNG (version-specific) | SWNG (selective) | CloudLinux + SWNG |
| Sync Method | RSync | RSync | reposync | RSync |
| Disk Space | ~200-500 GB | ~100-200 GB | Varies | ~500 GB - 2+ TB |
| Sync Speed | Fast | Fast | Moderate | Fast |
| Selectivity | Complete | Version-based | Repository-based | Complete |
| Best For | Complete SWNG | Specific versions | Selective repos | Complete setup |

## Customization

Each playbook directory contains:
- `playbook.yml` - Main playbook file
- `defaults/main.yml` - Vars file
- `inventory.ini` - Inventory file (edit this)
- `README.md` - Detailed documentation
- Template files (`.j2`) - Systemd service/timer templates

## Examples

### Example: Mirror 

```bash
cd /chosen directory
ansible-playbook -i inventory.ini playbook.yml
```

## Verification

After running any playbook, verify the setup:

```bash
# Check timer status
systemctl list-timers

# Check sync logs
tail -f /var/log/*-mirror.log

# Verify mirror directories
ls -lh /var/www/mirrors/
```

## Troubleshooting

### Common Issues

1. **Insufficient disk space**
   - Check available space: `df -h`
   - Clean up old data if needed

2. **Network connectivity**
   - Test RSync: `rsync rsync://rsync.upstream.cloudlinux.com/`
   - Test HTTP: `curl https://upstream.cloudlinux.com/`

3. **Timer not running**
   - Check status: `systemctl status <timer-name>`
   - Check logs: `journalctl -u <service-name>`

4. **Sync failures**
   - Check log files in `/var/log/`
   - Verify network connectivity
   - Check disk space

## Next Steps

After setting up your mirror:

1. **Verify mirror is accessible** via HTTP/HTTPS
2. **Contact CloudLinux support** to add your mirror to rotation
3. **Monitor sync logs** regularly
4. **Set up alerts** for sync failures

For more information about adding your mirror to CloudLinux rotation, see the main `../README.md`.

## Support

For issues or questions:
- Review the individual playbook README files
- Check the main documentation: `../README.md`
- Contact CloudLinux support
