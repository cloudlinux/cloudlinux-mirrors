# Specific SWNG Version Mirror with RSync - Ansible Playbook

### This is the recommended type of installation
This Ansible playbook sets up a local mirror of a specific CloudLinux version's SWNG repositories using RSync with automated updates via systemd timers.

## Prerequisites

- Ansible 2.9 or later
- Target server(s) with:
  - OS almalinux 9 or 10
  - Sufficient disk space (varies by version, typically 100-200 GB)
  - Root or sudo access
  - Network access to `rsync.upstream.cloudlinux.com`
  - Systemd support

## Variables

Default variables are defined in `defaults/main.yml`. You can customize the playbook by overriding variables:

- `cloudlinux_version`: CloudLinux version to mirror (default: `10`)
- `mirror_base_path`: Base path for mirrors (default: `/var/www/mirrors`)
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
5. Performs initial repository sync (runs asynchronously)
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

CloudLinux 10 is supported now. CloudLinux 8/9 support is coming soon.
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
