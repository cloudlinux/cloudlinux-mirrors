# Manual Installations (Step-by-step Guide)

This document contains **manual, step-by-step installation instructions** for setting up CloudLinux mirrors.
It mirrors what the Ansible playbooks in this repository do, but in a copy/paste friendly format.

**Current support:** CloudLinux **10** is supported now. Support for older versions (9/8/...) will be enabled gradually.

If you prefer automation, use the corresponding playbooks:
- `ansible/combined-mirror/`
- `ansible/complete-swng-rsync/`
- `ansible/specific-version-rsync(Recomended)/`
- `ansible/yum-reposync/`

## Table of Contents

- [Prepare Storage](#prepare-storage)
- [1. Combined-mirror: Mirroring SWNG + CloudLinux with RSync](#1-combined-mirror-mirroring-swng--cloudlinux-with-rsync)
- [2. Complete-swng-rsync: Mirroring the Complete SWNG Repository with RSync](#2-complete-swng-rsync-mirroring-the-complete-swng-repository-with-rsync)
- [3. Specific-version-rsync: Mirroring Specific SWNG Versions with RSync (Recommended)](#3-specific-version-rsync-mirroring-specific-swng-versions-with-rsync-recommended)
- [yum-reposync: Mirroring SWNG repositories with `reposync`](#yum-reposync-mirroring-swng-repositories-with-reposync)
- [Adding /healthcheck to Existing Manual Installations](#adding-healthcheck-to-existing-manual-installations)
- [Advanced Options](#advanced-options)

## Prepare Storage

Short, direct examples. Adjust paths as needed.

Ensure you have sufficient disk space. Repository mirrors can require several hundred gigabytes to multiple terabytes depending on what you mirror.

**Storage recommendation:** Use a dedicated disk or partition for mirror storage to avoid filling the root filesystem and to improve I/O performance.

**Sizing guidance:**
- SWNG mirror size is approximately **500 GB**
- The full `repo.cloudlinux.com` (CloudLinux repository) is **3+ TB**
- In most cases, **sync `repo.cloudlinux.com` only partially** (only the repositories you actually need)

**Recommendation:** For most production environments, prioritize mirroring **SWNG** (the main operational repository) as it contains all packages needed for operational systems.


## 1. Combined-mirror: Mirroring SWNG + CloudLinux with RSync

This manual example mirrors what `ansible/combined-mirror` does in its **default** ("combined") mode:
- Mirror paths under `/var/www/mirrors/`
- RSync sources `SWNG/` and `CLOUDLINUX/`
- A single systemd timer/service named `cloudlinux-complete-mirror`
- Nginx serving `/cloudlinux/` and `/swng/` (with optional Let's Encrypt HTTPS)

#### Step 1: Prepare Storage and Initial Sync

Check available disk space (combined mirrors may require hundreds of GB to 1+ TB).

```bash
df -h
```

Create mirror directories and run the initial sync (this may take hours).

```bash
mkdir -p /var/www/mirrors/swng /var/www/mirrors/cloudlinux

# Initial CloudLinux sync
rsync -av --delete \
  --progress \
  --log-file=/var/log/cloudlinux-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/

# Initial SWNG sync
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ \
  /var/www/mirrors/swng/
```

#### Step 2: Create systemd service + timer (combined mode)

Create `/etc/systemd/system/cloudlinux-complete-mirror.service`:

```bash
[Unit]
Description=Sync Complete CloudLinux and SWNG Mirrors
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /var/www/mirrors/cloudlinux/ && /usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/SWNG/ /var/www/mirrors/swng/'
StandardOutput=append:/var/log/cloudlinux-complete-mirror.log
StandardError=append:/var/log/cloudlinux-complete-mirror.log
```

Create `/etc/systemd/system/cloudlinux-complete-mirror.timer`:

```bash
[Unit]
Description=Run Complete CloudLinux and SWNG Mirror Sync Every 4 Hours
Requires=cloudlinux-complete-mirror.service

[Timer]
OnCalendar=*-*-* 00,04,08,12,16,20:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start the timer:

```bash
systemctl daemon-reload
systemctl enable cloudlinux-complete-mirror.timer
systemctl start cloudlinux-complete-mirror.timer

# Check timer status
systemctl status cloudlinux-complete-mirror.timer
systemctl list-timers cloudlinux-complete-mirror.timer
```

#### Step 3: Serve the mirror via Nginx (same paths as the playbook)

Install Nginx with your OS package manager, then create an HTTP config at `/etc/nginx/conf.d/combined-mirror.conf` and start Nginx:

```bash
systemctl enable --now nginx
systemctl status nginx

# Test local HTTP access (works if you use the non-HTTPS config below)
curl -I http://localhost/cloudlinux/ || true
curl -I http://localhost/swng/ || true
```

**Option A (no HTTPS): serve over HTTP only**

Create `/etc/nginx/conf.d/combined-mirror.conf`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/mirrors;
    index index.html;

    # Enable directory listing
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    access_log /var/log/nginx/combined-mirror-access.log;
    error_log /var/log/nginx/combined-mirror-error.log;

    location /cloudlinux/ {
        alias /var/www/mirrors/cloudlinux/;
        autoindex on;
    }

    location /swng/ {
        alias /var/www/mirrors/swng/;
        autoindex on;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    client_max_body_size 0;
}
```

Reload Nginx:

```bash
nginx -t && systemctl reload nginx
```

**Option B (playbook default): Let's Encrypt HTTPS + HTTP→HTTPS redirect**

Requirements:
- `mirror.example.com` must resolve to the mirror server
- inbound TCP `80` must be reachable during certificate issuance

Obtain a certificate (standalone method, like the playbook default):

```bash
# Install certbot packages (package names may vary by distro)
dnf install -y certbot python3-certbot-nginx

# Stop nginx temporarily for standalone auth
systemctl stop nginx || true

certbot certonly --standalone --preferred-challenges http \
  --non-interactive --agree-tos \
  --email admin@mirror.example.com \
  -d mirror.example.com

systemctl start nginx
```

Create `/etc/nginx/conf.d/combined-mirror.conf` (HTTP→HTTPS redirect + ACME location):

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name mirror.example.com;

    location /.well-known/acme-challenge/ {
        root /var/www/mirrors/acme;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}
```

Create `/etc/nginx/conf.d/combined-mirror-https.conf`:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name mirror.example.com;

    root /var/www/mirrors;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/mirror.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mirror.example.com/privkey.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Enable directory listing
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    access_log /var/log/nginx/combined-mirror-https-access.log;
    error_log /var/log/nginx/combined-mirror-https-error.log;

    location /cloudlinux/ {
        alias /var/www/mirrors/cloudlinux/;
        autoindex on;
    }

    location /swng/ {
        alias /var/www/mirrors/swng/;
        autoindex on;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    client_max_body_size 0;
}
```

Reload Nginx and verify:

```bash
nginx -t && systemctl reload nginx
curl -I https://mirror.example.com/cloudlinux/ || true
curl -I https://mirror.example.com/swng/ || true
```

For the full automation (including optional separate timers, Nginx templating, and certbot renewal), see `ansible/combined-mirror/README.md`.


## 2. Complete-swng-rsync: Mirroring the Complete SWNG Repository with RSync

This manual example mirrors what `ansible/complete-swng-rsync` does in its **default** mode:
- Mirror path: `/var/www/mirrors/swng`
- RSync source: `rsync://rsync.upstream.cloudlinux.com/SWNG/`
- systemd units: `swng-mirror.service` + `swng-mirror.timer`
- Nginx serving the mirror under `/swng/` (with optional Let's Encrypt HTTPS)

#### Step 1: Prepare Storage and Initial Sync

Check available disk space.

```bash
df -h
```

Create mirror directory and run the initial sync (this may take hours).

```bash
mkdir -p /var/www/mirrors/swng

rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ \
  /var/www/mirrors/swng/
```

#### Step 2: Create systemd service + timer for automated updates

Create `/etc/systemd/system/swng-mirror.service`:

```bash
[Unit]
Description=Sync Complete SWNG Repository Mirror
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/SWNG/ /var/www/mirrors/swng/
StandardOutput=append:/var/log/swng-mirror.log
StandardError=append:/var/log/swng-mirror.log
```

Create `/etc/systemd/system/swng-mirror.timer`:

```bash
[Unit]
Description=Run Complete SWNG Mirror Sync Every 4 Hours
Requires=swng-mirror.service

[Timer]
OnCalendar=*-*-* 00,04,08,12,16,20:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start the timer:

```bash
systemctl daemon-reload
systemctl enable swng-mirror.timer
systemctl start swng-mirror.timer

# Check timer status
systemctl status swng-mirror.timer
systemctl list-timers swng-mirror.timer
```

#### Step 3: Serve the mirror via Nginx (same paths as the playbook)

Install Nginx with your OS package manager.

```bash
systemctl enable --now nginx
systemctl status nginx
```

**Option A (no HTTPS): serve over HTTP only**

Create `/etc/nginx/conf.d/swng-mirror.conf`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name mirror.example.com;
    root /var/www/mirrors/swng;
    index index.html;

    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    access_log /var/log/nginx/swng-mirror-access.log;
    error_log /var/log/nginx/swng-mirror-error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    # Optional SWNG prefix for mixed setups
    location = /swng {
        return 301 /swng/;
    }

    location /swng/ {
        alias /var/www/mirrors/swng/;
        autoindex on;
    }

    client_max_body_size 0;
}
```

Reload Nginx and verify:

```bash
nginx -t && systemctl reload nginx
curl -I http://localhost/swng/ || true
```

**Option B (playbook default): Let's Encrypt HTTPS + HTTP→HTTPS redirect**

Requirements:
- `mirror.example.com` must resolve to the mirror server
- inbound TCP `80` must be reachable during certificate issuance

Obtain a certificate (standalone method, like the playbook default):

```bash
dnf install -y certbot python3-certbot-nginx

systemctl stop nginx || true

certbot certonly --standalone --preferred-challenges http \
  --non-interactive --agree-tos \
  --email admin@mirror.example.com \
  -d mirror.example.com

systemctl start nginx
```

Create `/etc/nginx/conf.d/swng-mirror.conf` (HTTP→HTTPS redirect + ACME location):

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name mirror.example.com;

    location /.well-known/acme-challenge/ {
        root /var/www/mirrors/acme;
    }

    # Normalize SWNG path (no trailing slash)
    location = /swng {
        return 301 https://$server_name/swng/;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}
```

Create `/etc/nginx/conf.d/swng-mirror-https.conf`:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name mirror.example.com;
    root /var/www/mirrors/swng;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/mirror.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mirror.example.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    access_log /var/log/nginx/swng-mirror-https-access.log;
    error_log /var/log/nginx/swng-mirror-https-error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    location = /swng {
        return 301 /swng/;
    }

    location /swng/ {
        alias /var/www/mirrors/swng/;
        autoindex on;
    }

    client_max_body_size 0;
}
```

Reload Nginx and verify:

```bash
nginx -t && systemctl reload nginx
curl -I https://mirror.example.com/swng/ || true
```

For automation (systemd timers, Nginx templating, and certbot renewal), see `ansible/complete-swng-rsync/README.md`.


## 3. Specific-version-rsync: Mirroring Specific SWNG Versions with RSync (Recommended)

This manual example mirrors what `ansible/specific-version-rsync(Recomended)` does in its **default** mode:
- CloudLinux version mirrored: **10** (8/9 support is coming soon)
- Mirror path: `/var/www/mirrors/swng/10`
- RSync source: `rsync://rsync.upstream.cloudlinux.com/SWNG/10/`
- systemd units: `swng-10-mirror.service` + `swng-10-mirror.timer` (every 6 hours)
- Nginx serving the mirror under `/swng/` so that version content is available at `/swng/10/` (with optional Let's Encrypt HTTPS)

#### Step 1: Prepare Storage and Initial Sync

```bash
df -h
mkdir -p /var/www/mirrors/swng/10

rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-10-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/10/ \
  /var/www/mirrors/swng/10/
```

#### Step 2: Create systemd service + timer for automated updates

Create `/etc/systemd/system/swng-10-mirror.service`:

```bash
[Unit]
Description=Sync CloudLinux 10 SWNG Repository Mirror
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/SWNG/10/ /var/www/mirrors/swng/10/
StandardOutput=append:/var/log/swng-10-mirror.log
StandardError=append:/var/log/swng-10-mirror.log
```

Create `/etc/systemd/system/swng-10-mirror.timer`:

```bash
[Unit]
Description=Run CloudLinux 10 SWNG Mirror Sync Every 6 Hours
Requires=swng-10-mirror.service

[Timer]
OnCalendar=*-*-* 00,06,12,18:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start the timer:

```bash
systemctl daemon-reload
systemctl enable swng-10-mirror.timer
systemctl start swng-10-mirror.timer

systemctl status swng-10-mirror.timer
systemctl list-timers swng-10-mirror.timer
```

#### Step 3: Serve the mirror via Nginx (same paths as the playbook)

Install and start Nginx:

```bash
systemctl enable --now nginx
systemctl status nginx
```

**Option A (no HTTPS): serve over HTTP only**

Create `/etc/nginx/conf.d/swng-mirror.conf`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name _;
    root /var/www/mirrors;
    index index.html;

    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    access_log /var/log/nginx/swng-10-mirror-access.log;
    error_log /var/log/nginx/swng-10-mirror-error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    # Optional SWNG prefix for mixed setups
    location = /swng {
        return 301 /swng/;
    }

    location /swng/ {
        alias /var/www/mirrors/swng/;
        autoindex on;
    }

    client_max_body_size 0;
}
```

Reload Nginx and verify:

```bash
nginx -t && systemctl reload nginx
curl -I http://localhost/swng/10/ || true
```

**Option B (playbook default): Let's Encrypt HTTPS + HTTP→HTTPS redirect**

Requirements:
- `mirror.example.com` must resolve to the mirror server
- inbound TCP `80` must be reachable during certificate issuance

```bash
dnf install -y certbot python3-certbot-nginx
systemctl stop nginx || true

certbot certonly --standalone --preferred-challenges http \
  --non-interactive --agree-tos \
  --email admin@mirror.example.com \
  -d mirror.example.com

systemctl start nginx
```

Create `/etc/nginx/conf.d/swng-mirror.conf` (HTTP→HTTPS redirect + ACME location):

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name mirror.example.com;

    location /.well-known/acme-challenge/ {
        root /var/www/mirrors/acme;
    }

    # Normalize SWNG path (no trailing slash)
    location = /swng {
        return 301 https://$server_name/swng/;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}
```

Create `/etc/nginx/conf.d/swng-mirror-https.conf`:

```nginx
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name mirror.example.com;
    root /var/www/mirrors;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/mirror.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mirror.example.com/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    access_log /var/log/nginx/swng-10-mirror-https-access.log;
    error_log /var/log/nginx/swng-10-mirror-https-error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    location = /swng {
        return 301 /swng/;
    }

    location /swng/ {
        alias /var/www/mirrors/swng/;
        autoindex on;
    }

    client_max_body_size 0;
}
```

Reload Nginx and verify:

```bash
nginx -t && systemctl reload nginx
curl -I https://mirror.example.com/swng/10/ || true
```

For automation (systemd timers, Nginx templating, and certbot renewal), see `ansible/specific-version-rsync(Recomended)/README.md`.


## yum-reposync: Mirroring SWNG repositories with `reposync`

This manual example mirrors what `ansible/yum-reposync` does:
- Mirrors **selected SWNG repositories** using `reposync` (yum-utils)
- Generates metadata with `createrepo`
- Uses a systemd service/timer named `swng-reposync`
- Serves the mirror via Nginx (and optionally Let's Encrypt HTTPS)

### Step 1: Install required tools

The playbook installs `yum-utils` and `createrepo` (package names may vary by distro).

```bash
dnf -y install yum-utils createrepo || yum -y install yum-utils createrepo
```

### Step 2: Create SWNG upstream repo config

Create `/etc/yum.repos.d/swng-upstream.repo`:

```ini
# SWNG Repository Configuration for upstream.cloudlinux.com
# Source: https://upstream.cloudlinux.com/swng/

[SWNG-10-x86_64]
name=SWNG-10-x86_64
baseurl=https://upstream.cloudlinux.com/swng/10/x86_64/
enabled=1
skip_if_unavailable=1
gpgcheck=0
```

Notes:
- The playbook disables GPG checks by default (`gpgcheck=0`). If you want to enable GPG verification, set `gpgcheck=1` and configure the appropriate key.
- For modular content, `reposync` may require `module_platform_id` (the playbook uses `--setopt=module_platform_id=...` when configured).

### Step 3: Create destination directory and run initial sync

```bash
mkdir -p /var/www/mirrors/swng

# Initial sync of enabled repos
reposync -p /var/www/mirrors/swng/ --repo SWNG-10-x86_64 --setopt=module_platform_id=platform:el10

# Generate metadata (required)
createrepo /var/www/mirrors/swng/SWNG-10-x86_64/
```

### Step 4: Create systemd service + timer

Create `/etc/systemd/system/swng-reposync.service`:

```ini
[Unit]
Description=Sync SWNG Repositories with reposync
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reposync -p /var/www/mirrors/swng/ --repo SWNG-10-x86_64 --setopt=module_platform_id=platform:el10
ExecStartPost=/usr/bin/createrepo /var/www/mirrors/swng/SWNG-10-x86_64/
StandardOutput=append:/var/log/swng-reposync.log
StandardError=append:/var/log/swng-reposync.log
```

Create `/etc/systemd/system/swng-reposync.timer`:

```ini
[Unit]
Description=Run SWNG reposync Every 6 Hours
Requires=swng-reposync.service

[Timer]
OnCalendar=*-*-* 00,06,12,18:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl daemon-reload
systemctl enable swng-reposync.timer
systemctl start swng-reposync.timer
systemctl status swng-reposync.timer
systemctl list-timers swng-reposync.timer
```

### Step 5: Serve the mirror via Nginx (same paths as the playbook)

Install and start Nginx:

```bash
systemctl enable --now nginx
systemctl status nginx
```

Create `/etc/nginx/conf.d/swng-reposync-mirror.conf`:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name mirror.example.com;
    root /var/www/mirrors/swng;
    index index.html;

    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    access_log /var/log/nginx/swng-reposync-mirror-access.log;
    error_log /var/log/nginx/swng-reposync-mirror-error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    # Optional SWNG prefix for mixed setups
    location /swng/ {
        alias /var/www/mirrors/swng/;
        autoindex on;
    }

    location = /swng {
        return 301 /swng/;
    }

    client_max_body_size 0;
}
```

Reload Nginx and verify:

```bash
nginx -t && systemctl reload nginx
curl -I http://localhost/swng/ || true
```

Optional HTTPS (playbook default):
- The playbook can obtain a Let's Encrypt certificate using certbot and add `swng-reposync-mirror-https.conf`.
- For the full automation (including certbot and renewal), see `ansible/yum-reposync/README.md`.

## Adding /healthcheck to Existing Manual Installations

If you set up your mirror manually **before** the `/healthcheck` endpoint contract was required, follow these steps to add it to an existing installation. Paths below assume the defaults from sections 1-4 — adjust if you customized your layout.

### Step 1 — Install dependencies

```bash
# RedHat-family (CloudLinux, AlmaLinux, RHEL, Rocky)
dnf install -y epel-release
dnf install -y python3-dotenv

# Optional but recommended on EL with enforcing SELinux (see Step 6)
dnf install -y policycoreutils-python-utils

# Debian/Ubuntu
apt update && apt install -y python3-dotenv
```

### Step 2 — Install the healthcheck tool

```bash
mkdir -p /opt/healthcheck /var/www

curl -fsSL https://raw.githubusercontent.com/cloudlinux/cloudlinux-mirrors/main/ansible/healthcheck/healthcheck_update.py \
  -o /opt/healthcheck/healthcheck_update.py
chmod 0755 /opt/healthcheck/healthcheck_update.py

cat > /opt/healthcheck/.env <<'EOF'
HEALTHCHECK_JSON=/var/www/healthcheck.json
HEALTHCHECK_HTML=/var/www/healthcheck.html
EOF
```

### Step 3 — Generate initial PENDING file

This makes `/healthcheck.json` reachable immediately, before your first post-migration sync:

```bash
/usr/bin/python3 /opt/healthcheck/healthcheck_update.py \
  --service sync --field repo --value swng.cloudlinux.com --status PENDING

cat /var/www/healthcheck.json
```

### Step 4 — Add nginx locations

Edit your nginx vhost(s) — typically `/etc/nginx/conf.d/swng-mirror.conf` and/or `swng-mirror-https.conf` — and add inside **each** `server { ... }` block:

```nginx
    # Health-check for cl-mirrors mirrorservice
    location = /healthcheck {
        alias /var/www/healthcheck.html;
        default_type text/html;
    }

    location = /healthcheck.json {
        alias /var/www/healthcheck.json;
        default_type application/json;
        add_header Cache-Control "no-store";
    }
```

Validate and reload:

```bash
nginx -t && systemctl reload nginx
```

### Step 5 — Wire ExecStartPost in your sync service

Edit your systemd sync unit (the one that runs `rsync` or `reposync`) and add the `ExecStartPost=` line to the `[Service]` block. The exact unit file depends on your setup:

| Setup | Unit file |
|---|---|
| Combined mirror (one service) | `/etc/systemd/system/cloudlinux-complete-mirror.service` |
| Separate SWNG service | `/etc/systemd/system/swng-mirror.service` |
| Per-version SWNG | `/etc/systemd/system/swng-<VERSION>-mirror.service` |
| reposync | `/etc/systemd/system/swng-reposync.service` |

Add to `[Service]`:

```ini
ExecStartPost=/usr/bin/python3 /opt/healthcheck/healthcheck_update.py --service sync --field repo --value swng.cloudlinux.com --status OK
```

Then:

```bash
systemctl daemon-reload
```

### Step 6 — Trigger sync to flip PENDING → OK

Run your sync service once so `ExecStartPost` fires and flips the status:

```bash
# choose the service unit matching your setup
systemctl start swng-mirror.service               # or cloudlinux-complete-mirror.service /
                                                  #    swng-<version>-mirror.service /
                                                  #    swng-reposync.service
```

Verify:

```bash
curl -s https://<your-mirror>/healthcheck.json
```

Expected:

```json
{
  "healthcheck_update": "YYYY/MM/DD HH:MM:SS",
  "sync_status": [
    {"repo": "swng.cloudlinux.com", "status": "OK", "time": "YYYY/MM/DD HH:MM:SS"}
  ]
}
```

If `status` stays `PENDING` after a sync run, check that your service unit has the `ExecStartPost=` line and that `daemon-reload` was issued:

```bash
systemctl cat <your-sync>.service | grep ExecStartPost
journalctl -u <your-sync>.service --since '5 min ago'
```

## Advanced Options

### Partial Syncs
If a sync is interrupted, RSync will resume from where it left off on the next run. The `--partial` option can help with large files:
The --partial option tells rsync to save partially downloaded files and download them later, which saves time and traffic when dealing with large ISOs/archives.

```bash
rsync -av --delete --partial rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /var/www/mirrors/cloudlinux/
```

### Selective Synchronization

Sync only specific versions or architectures:

```bash
# Sync only CloudLinux 10
rsync -av --delete \
  --include="10/**" \
  --exclude="*" \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/

# Sync only x86_64 architecture
rsync -av --delete \
  --include="*/x86_64/**" \
  --exclude="*" \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/
```

### Bandwidth Limiting

Limit bandwidth usage during sync:

```bash
rsync -av --delete --bwlimit=10000 \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/
```

### Compression

Enable compression (useful for slow connections):

```bash
rsync -avz --delete \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/
```