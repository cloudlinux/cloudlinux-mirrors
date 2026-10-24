# Specific SWNG Version Mirror with RSync - Ansible Playbook

> **Not eligible for the public CloudLinux mirror service.** This variant serves one
> version under `/swng/<version>/` (for example `/swng/10/`), while the mirror service
> checks every channel under `/swng/<channel-name>/` (`cloudlinux-x86_64-server-10`,
> `cloudlinux-x86_64-server-9.8`, ...) and drops a mirror at the first missing one. Use
> it for your own servers with a fixed `baseurl`; to be listed in the mirror service,
> deploy [complete-swng-rsync](../complete-swng-rsync/) instead.

This Ansible playbook sets up a local mirror of a specific CloudLinux version's SWNG repositories using RSync with automated updates via systemd timers.

## Prerequisites

- Ansible 2.9 or later
- Target server(s) with:
  - OS almalinux 9 or 10
  - Sufficient disk space: the CloudLinux 10 channel is ~8 GB today (2026-10) and grows over the release lifetime (CL9 reached ~50 GB, CL8 ~100 GB); plan 100-200 GB
  - Root or sudo access
  - Network access to `rsync.upstream.cloudlinux.com`
  - Systemd support

## Variables

Default variables are defined in `defaults/main.yml`. You can customize the playbook by overriding variables:

- `cloudlinux_version`: CloudLinux version to mirror (default: `10`)
- `mirror_base_path`: Base path for mirrors (default: `/var/www/mirrors`); a directory on the root filesystem or a dedicated disk mounted anywhere, your choice
- `mirror_min_free_gb`: minimum free space on the filesystem holding `mirror_base_path` (default: `20`; the CL10 channel is ~8 GB today, plan 100-200 GB long term)
- `swng_mirror_path`: SWNG mirror directory (auto-generated based on version)
- `rsync_source`: RSync source URL (auto-generated based on version)
- `sync_log_file`: Log file path (auto-generated based on version)
- `sync_interval_hours`: Sync interval in hours (default: `6`)
- `timer_schedule`: Systemd timer schedule (default: `*-*-* 00,06,12,18:00:00`)

## What the Playbook Does

1. Validates the CloudLinux version (must be 10)
2. Checks available disk space
3. Creates mirror directory structure for the specific version
4. Installs rsync if needed
5. Starts the initial repository sync in the background through the systemd service (so `/healthcheck.json` turns OK when it finishes)
6. Creates systemd service for automated syncing
7. Creates systemd timer for scheduled updates
8. Enables and starts the timer
9. Installs and configures Nginx web server
10. Enables and starts Nginx to serve the mirror

## Usage

### Mirror CloudLinux 10 SWNG (Default)

```bash
ansible-playbook -i inventory.ini playbook.yml
```

### Version Support

CloudLinux 10 only (enforced by the playbook); to serve CloudLinux OS 7-9 clients use complete SWNG rsync. Client-side requirements for CloudLinux OS 7, 8, 9 and 10 are listed in the [main README](../../README.md).
## How to Install
Edit `inventory.ini` to specify your mirror server(s):

```ini
[mirror_servers]
mirror-server-01 ansible_host=192.168.1.100
mirror-server-02 ansible_host=192.168.1.101

[mirror_servers:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_rsa
```
Edit the `defaults/main.yml` if necessary
```yaml
# Default variables for Specific SWNG Version Mirror Playbook

# Mirror paths
mirror_base_path: /var/www/mirrors
cloudlinux_version: 10
swng_mirror_path: "{{ mirror_base_path }}/swng/{{ cloudlinux_version }}"

# RSync configuration
rsync_source: "rsync://rsync.upstream.cloudlinux.com/SWNG/{{ cloudlinux_version }}/"
sync_log_file: "/var/log/swng-{{ cloudlinux_version }}-mirror.log"

# Sync schedule
sync_interval_hours: 6
timer_schedule: "*-*-* 00,06,12,18:00:00"
service_name: "swng-{{ cloudlinux_version }}-mirror"

# SSL/Certbot configuration
mirror_domain: "{{ inventory_hostname }}"
certbot_email: "admin@{{ mirror_domain }}"
certbot_authenticator: webroot  # Options: standalone, webroot
certbot_webroot: "{{ mirror_base_path }}/acme"
certbot_enabled: true
certbot_cron_enabled: true
certbot_cron_schedule:
  minute: 0
  hour: 3
```
Run with:
```bash
ansible-playbook -i inventory.ini playbook.yml
```
After playbook run for verification
```bash
ansible-playbook -i inventory.ini verify.yml
```
## Manual Verification

After running the playbook, verify the setup:

```bash
# Check timer status
systemctl status swng-10-mirror.timer

# List active timers
systemctl list-timers swng-10-mirror.timer

# Check sync log
tail -f /var/log/swng-10-mirror.log

# Verify mirror directory
ls -lh /var/www/mirrors/swng/10/

# Check Nginx status
systemctl status nginx

# Test web access
curl http://localhost/swng/10/
```

## Accessing the Mirror via Web

The playbook configures Nginx to serve the mirror on port 80. You can access it via:

- **Local access**: `http://localhost/swng/10/`
- **Network access**: `http://<server-ip>/swng/10/`

The Nginx configuration enables directory browsing, so you can navigate the repository structure through a web browser.

## Notes

- The initial sync runs asynchronously and may take several hours
- Monitor the log file to track sync progress
- Ensure sufficient disk space before running
- The timer will automatically sync every 6 hours by default
