# Complete SWNG Mirror with RSync - Ansible Playbook

This Ansible playbook sets up a complete local mirror of all SWNG repositories using RSync with automated updates via systemd timers.

## Prerequisites

- Ansible 2.9 or later
- Target server(s) with:
  - OS almalinux 9 or 10
  - Sufficient disk space (several hundred GB recommended)
  - Root or sudo access
  - Network access to `rsync.upstream.cloudlinux.com`
  - Systemd support

## Variables

Default variables are defined in `defaults/main.yml`. You can customize the playbook by overriding variables:

- `mirror_base_path`: Base path for mirrors (default: `/var/www/mirrors`)
- `swng_mirror_path`: SWNG mirror directory (default: `/var/www/mirrors/swng`)
- `rsync_source`: RSync source URL (default: `rsync://rsync.upstream.cloudlinux.com/SWNG/`)
- `sync_log_file`: Log file path (default: `/var/log/swng-mirror.log`)
- `sync_interval_hours`: Sync interval in hours (default: `4`)
- `timer_schedule`: Systemd timer schedule (default: `*-*-* 00,04,08,12,16,20:00:00`)
- `mirror_domain`: Domain name for SSL certificate (default: `{{ inventory_hostname }}`)
- `certbot_email`: Email for Let's Encrypt certificate (default: `admin@{{ mirror_domain }}`)
- `certbot_enabled`: Enable SSL certificate setup (default: `true`)
- `certbot_authenticator`: Certbot authentication method (default: `standalone`, options: `standalone`, `webroot`)

## What the Playbook Does

1. Checks available disk space
2. Creates mirror directory structure
3. Installs rsync if needed
4. Performs initial repository sync (runs asynchronously)
5. Creates systemd service for automated syncing
6. Creates systemd timer for scheduled updates
7. Enables and starts the timer
8. Installs and configures Nginx web server
9. Enables and starts Nginx to serve the mirror

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

## How to install
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
# Default variables for Complete SWNG Mirror Playbook

# Mirror paths
mirror_base_path: /var/www/mirrors
swng_mirror_path: "{{ mirror_base_path }}/swng"

# RSync configuration
rsync_source: rsync://rsync.upstream.cloudlinux.com/SWNG/
sync_log_file: /var/log/swng-mirror.log

# Sync schedule
sync_interval_hours: 4
timer_schedule: "*-*-* 00,04,08,12,16,20:00:00"

# SSL/Certbot configuration
mirror_domain: "{{ inventory_hostname }}"
certbot_email: "admin@{{ mirror_domain }}"
certbot_authenticator: standalone  # Options: standalone, webroot
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

##  Manual Verification

After running the playbook, verify the setup:

```bash
# Check timer status
systemctl status swng-mirror.timer

# List active timers
systemctl list-timers swng-mirror.timer

# Check sync log
tail -f /var/log/swng-mirror.log

# Verify mirror directory
ls -lh /swng_mirror_path/swng/

# Check Nginx status
systemctl status nginx

# Test web access
curl -I http://<mirror-domain>/swng/
curl -I https://<mirror-domain>/swng/
```

## Accessing the Mirror via Web

The playbook configures Nginx to serve the mirror on port 80. You can access it via:

- **Local access**: `http://localhost/swng/`
- **Network access**: `http://<server-ip>/swng/`

The Nginx configuration enables directory browsing, so you can navigate the repository structure through a web browser.

## Notes

- The initial sync runs asynchronously and may take several hours
- Monitor the log file to track sync progress
- Ensure sufficient disk space before running
- The timer will automatically sync every 4 hours by default
