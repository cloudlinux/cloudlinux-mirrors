# Repository Mirroring

## Table of Contents

- [Introduction](#introduction)
- [What is upstream.cloudlinux.com?](#what-is-upstreamcloudlinuxcom)
- [Access Methods](#access-methods)
- [Creating a Local Mirror](#creating-a-local-mirror)
- [Cloning Specific Repositories](#cloning-specific-repositories)
- [Mirroring SWNG Repositories](#mirroring-swng-repositories)
- [Adding Your Mirror to CloudLinux Mirror Rotation](#adding-your-mirror-to-cloudlinux-mirror-rotation)
- [Automated Mirror Setup with Ansible](#automated-mirror-setup-with-ansible)
- [Containerized Mirror Setup with Docker](#containerized-mirror-setup-with-docker)
- [Choosing the Right Approach](#choosing-the-right-approach)
- [Using apt-mirror](#using-apt-mirror-for-debianubuntu-based-systems)
- [Serving Your Local Mirror](#serving-your-local-mirror)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Advanced Options](#advanced-options)
- [Support and Resources](#support-and-resources)
- [Summary](#summary)

## Introduction

`upstream.cloudlinux.com` is CloudLinux's dedicated repository mirroring service that provides unrestricted access to SWNG and CloudLinux repositories. This service is designed for organizations that need to create and maintain local mirrors of CloudLinux repositories.

### Understanding CloudLinux Repositories

**SWNG** (Spacewalk Next Generation) is the **main operational repository** containing:
- All packages required for the operational system
- Regular security and feature updates
- Current and actively maintained CloudLinux version 10 (8/9 support coming soon)
- The primary repository used by CloudLinux systems for day-to-day operations

**repo.cloudlinux.com** (accessed via `upstream.cloudlinux.com/cloudlinux/`) contains:
- Scripts and tools required for system conversions
- Installation images and ISO files
- Older versions and legacy packages
- Source packages (SRPMs)
- Conversion and migration utilities

For most production environments, **SWNG is the primary repository** you should mirror, as it contains all the packages needed for operational systems and receives regular updates.

### How CloudLinux Package Delivery Works

The CloudLinux package delivery system operates in two phases:

1. **Initial Installation/Conversion Phase**
   - During installation or conversion from CentOS/AlmaLinux/Ubuntu or other operating systems
   - CloudLinux OS calls `repo.cloudlinux.com` repository
   - Downloads basic packages and scripts required for conversion
   - Sets up the initial CloudLinux system configuration

2. **Operational Updates Phase**
   - After installation/conversion, all updates come from **SWNG repositories**
   - Updates are distributed through the mirror service configured in YUM
   - Mirror service URL: `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`
   - The mirror service provides a list of available mirrors based on:
     - **Geographic proximity** - closest mirrors to the requesting IP address
     - **Network-specific mirrors** - mirrors configured for specific IP addresses or networks
     - **Fallback mechanism** - if a network-specific mirror is not operating, the system automatically falls back to public mirrors
   - This allows CloudLinux systems to use "vanilla" YUM configuration while automatically selecting the best mirror

**Benefits of this approach:**
- Automatic mirror selection based on location and network configuration
- High availability through fallback to public mirrors
- No manual repository URL configuration needed on client systems
- Support for private mirrors for specific networks while maintaining standard configuration
- **Selective version mirroring**: The new SWNG mirror system allows mirroring only the specific CloudLinux versions you need, unlike the old system which required mirroring all versions

## Mirror System Changes (Old vs New)

The new mirroring system is gradually replacing the old one. Key changes and behaviors:

**What is changing for customers:**
- **Open HTTPS mirrors**: Mirrors are fully accessible over standard HTTPS (no custom SSL or XMLRPC transport), so customers can fully set up and control mirrors.
- **New mirror service endpoint**: `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors` replaces the old `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cln-mirrors`.
- **Automatic client transition**: The mirrorlist URL used by CloudLinux OS is updated automatically by `rhn-client-tools` and `cloudlinux-release` package updates.
- **Partial mirror support**: The new mirror service supports mirrors that carry only some OS versions, reducing storage and bandwidth.
- **Autonomous install/conversion**: `repo.cloudlinux.com` content can be freely synced, enabling a fully autonomous environment for installation and conversion.

**Legacy vs new mirrorlist usage (behavioral differences):**
- The **old** `cln-mirrors` endpoint was required for systems using the legacy yum-rhn-plugin/XMLRPC flow and custom SSL certificates.
- The **new** `cl-mirrors` endpoint is used with standard `mirrorlist=` entries in `.repo` files and works with publicly accessible HTTPS mirrors.
- These endpoints are **not interchangeable**; client updates move systems to the new endpoint automatically.

**Why open HTTPS mirrors matter:**
- Mirror content is browsable and verifiable in a standard browser or with `curl`.
- Customers can host mirrors on their own infrastructure without special SSL tooling.
- Standard HTTP tooling and monitoring works out of the box (no XMLRPC transport).

**Mirror service behavior (high level):**
- The service returns a list of nearby, available mirrors based on requester IP.
- Mirrors can be **public** or **private** (IP/network-scoped).
- With the new service, mirrors can be **partial** (only some versions), and clients still get a valid list of mirrors that match their version.

**Installation and conversion flow impact:**
- `repo.cloudlinux.com` is used for install/conversion assets and legacy content.
- After conversion/installation, systems switch to **SWNG** for operational updates.
- Because the full `repo.cloudlinux.com` is large, most mirrors should **sync it partially** (only the needed repositories) unless a fully autonomous environment is required.

## What is upstream.cloudlinux.com?

`upstream.cloudlinux.com` is a new repository service that provides:

- **Unrestricted Access:** No authentication required for downloading repository content
- **Multiple Access Methods:** Both HTTP/HTTPS and RSync protocols
- **Complete Repository Content:** Full access to SWNG (main operational repository) and CloudLinux (legacy/conversion tools) repositories
- **Directory Browsing:** Web interface to explore available packages and versions
- **Efficient Synchronization:** RSync support for incremental updates

### Access Methods

### Method 1: HTTP/HTTPS (Web Browser or wget/curl)

Use this method for:
- Browsing available packages
- Downloading individual packages
- Quick access without setting up RSync

**Base URL:** `https://upstream.cloudlinux.com/`

**Available Paths:**
- `https://upstream.cloudlinux.com/swng/` - **SWNG repository (main operational repository)** - Contains all packages for operational systems
- `https://upstream.cloudlinux.com/cloudlinux/` - CloudLinux repository (conversion tools, images, older versions, source packages)

**Examples:**

```bash
# Browse SWNG repositories (main operational repository)
curl https://upstream.cloudlinux.com/swng/
# Shows: 10/ now; 8/9 coming soon

# Browse SWNG for CloudLinux 10
curl https://upstream.cloudlinux.com/swng/10/

# Browse CloudLinux repository (for conversion tools and legacy packages)
curl https://upstream.cloudlinux.com/cloudlinux/10/

# List available SWNG versions (main repository)
curl https://upstream.cloudlinux.com/swng/
```

### Method 2: RSync (Recommended for Mirroring)

Use this method for:
- Creating complete local mirrors
- Incremental updates (only changed files)
- Bandwidth-efficient synchronization
- Automated mirroring scripts

**RSync Endpoint:** `rsync://rsync.upstream.cloudlinux.com/`

**RSync Modules:**
- `SWNG` - **SWNG repository (main operational repository)** - Contains all packages for operational systems
- `CLOUDLINUX` - CloudLinux repository (conversion tools, images, older versions, source packages)

**Basic RSync Command Examples:**

```bash
# Sync SWNG repository (main operational repository - recommended for most use cases)
rsync -av --delete rsync://rsync.upstream.cloudlinux.com/SWNG/ /path/to/local/mirror/swng/

# Sync CloudLinux repository (for conversion tools and legacy packages)
rsync -av --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /path/to/local/mirror/cloudlinux/
```

## Mirroring SWNG Repositories

**SWNG (Spacewalk Next Generation) is the main operational repository** for CloudLinux systems. It contains:
- All packages required for operational CloudLinux systems
- Regular security and feature updates
- Current and actively maintained CloudLinux versions 10 (Support for earlier versions will be added later 8, 9 etc.)
- The primary repository used by CloudLinux systems for day-to-day operations

**For most production environments, SWNG should be your primary mirror**, as it contains all the packages needed for operational systems and receives regular updates.

**Advantages of SWNG over the old mirror system:**
- **Selective version mirroring**: Unlike the old system, SWNG allows you to mirror only the specific CloudLinux versions you need (e.g., only version 9, or only versions 8 and 9)
- **Reduced storage requirements**: Mirror only what you need instead of all versions
- **Lower bandwidth usage**: Sync only the versions in use in your environment
- **Flexible deployment**: Choose which versions to mirror based on your infrastructure needs

**How SWNG is used:**
- After initial installation/conversion (which uses `repo.cloudlinux.com`), all operational updates come from SWNG repositories
- SWNG mirrors are distributed through the mirror service at `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`
- CloudLinux systems automatically select the best mirror based on geographic location or network-specific configuration
- This allows using standard CloudLinux YUM configuration while benefiting from optimized mirror selection

### SWNG Top-Level Layout and Public Index

The SWNG top-level directory is expected to expose the same structure as upstream. In mixed setups, the SWNG content can be under `<domain>/swng/` instead of the site root. The top level includes marker files, version symlinks, and repository directories.

**Example: `upstream/swng` contains:**

```
10
8
8-next
9
9-next
cloudlinux-x86_64-server-10
cloudlinux-x86_64-server-8.10
cloudlinux-x86_64-server-9.7
cloudlinux-i686-server-6
ubuntu-amd64-debian-linux-server-jammy
cloudlinux-x86_64-server-8.tgz
listAllPackagesChecksum
```

**Notes:**
- The `8/`, `9/`, `10/` and `*-next` entries are symlinks pointing to the current minor release directories.
- Directory browsing must be enabled so the index is publicly visible.

## Automated Mirror Setup with Ansible

For organizations managing multiple mirror servers or requiring infrastructure-as-code approaches, Ansible playbooks are available to automate the complete mirror setup process.

### Ansible Use Cases

- **Infrastructure Automation**: Automate mirror setup across multiple servers
- **Configuration Management**: Version-controlled mirror configurations
- **Multi-Environment Setup**: Easily replicate mirror setups in dev/staging/prod
- **Compliance**: Documented, repeatable infrastructure setup
- **Team Collaboration**: Shareable, maintainable mirror configurations

For detailed documentation, see `ansible/README.md` and individual playbook README files.

## Containerized Mirror Setup with Docker

For containerized environments or when you want isolated mirror processes, Docker and Docker Compose configurations are available.

### Docker Use Cases

- **Containerized Infrastructure**: Run mirrors in isolated containers
- **Easy Deployment**: Simple `docker compose up` to start mirroring
- **Resource Isolation**: Controlled CPU and memory usage
- **Portability**: Run on any Docker-compatible platform
- **Development/Testing**: Quick setup for testing mirror configurations
- **Microservices Architecture**: Integrate mirrors into containerized environments
- **Cloud Deployments**: Deploy mirrors in Kubernetes, Docker Swarm, or cloud container services

### HTTPS/Let's Encrypt (Docker)

For Docker-based setups using the bundled Nginx service and Let's Encrypt:

- Ensure `CERTBOT_DOMAIN` points to this server (DNS A/AAAA record).
- Open inbound ports `80` and `443`.
- Set `CERTBOT_EMAIL` and `CERTBOT_DOMAIN` in `.env`.

On first run, Nginx starts in HTTP-only mode for ACME. Once the certificate is issued,
it automatically reloads and enables HTTPS.

### Volume Management

Mirror data and logs are stored in persistent volumes:

```yaml
volumes:
  - ./mirror-data:/var/www/mirrors/swng
  - ./logs:/var/log
```

### Resource Limits

Docker Compose configurations include resource limits:

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
```

For detailed documentation, see `docker/README.md` and individual setup README files.

## Installation Types

This repository provides multiple approaches to set up and maintain mirrors:

1. **Ansible Playbooks**: Infrastructure-as-code automation for multiple servers
2. **Docker Containers**: Containerized mirror setups for isolated, portable deployments
3. **Manual Setup**: Direct RSync commands and systemd timers for full control

Choose the approach that best fits your infrastructure and requirements. All methods support the same mirroring capabilities with different levels of automation and deployment flexibility.

Choose one of the supported installation types below. Each type has both Ansible and Docker implementations with full step-by-step instructions in the linked directories.

### 1) combined-mirror

Mirrors both **SWNG** and **repo.cloudlinux.com** (conversion/legacy content) in one setup.

- Supports combined or separate sync modes
- Best for: Full, self-contained mirror environments
- Storage: Highest (SWNG + CloudLinux)
- Ansible: `ansible/combined-mirror/README.md`
- Docker: `docker/combined-mirror/README.md`

### 2) complete-swng-rsync

Mirrors the **entire SWNG** repository (all supported versions).

- Sets up complete SWNG repository mirror using RSync
- Configures systemd timers for automated updates
- Best for: Central SWNG mirror, full operational updates
- Storage: High (SWNG only)
- Ansible: `ansible/complete-swng-rsync/README.md`
- Docker: `docker/complete-swng-rsync/README.md`

### 3) specific-version-rsync (Recommended)

Mirrors **only SWNG for CloudLinux 10** (8/9 support coming soon).

- Mirrors specific CloudLinux versions (10 now; 8/9 coming soon)
- Version-specific systemd services and timers
- Best for: Smaller storage footprint, single-version environments, needing only specific versions
- Storage: Lower
- Ansible: `ansible/specific-version-rsync(Recomended)/README.md`
- Docker: `docker/specific-version-rsync/README.md`

### 4) yum-reposync

Uses `reposync` to mirror **specific SWNG repositories** (selective subsets).

- Uses yum-reposync for selective repository mirroring
- Automatic metadata generation
- Best for: Tight control over which repos/arches are synced
- Storage: Lowest (only selected repos)
- Ansible: `ansible/yum-reposync/README.md`
- Docker: `docker/yum-reposync/README.md`

## Adding Your Mirror to CloudLinux Mirror Rotation

After creating your local mirror, you need to contact the CloudLinux support team to have your mirror added to the mirror service. This allows CloudLinux systems to automatically use your mirror while maintaining "vanilla" CloudLinux and YUM settings.

### Mirror Requirements

Before contacting support, ensure your mirror has the following components:

1. **Synchronization Scripts**
   - Automated sync scripts (RSync or reposync) configured
   - Systemd timers or cron jobs for regular updates
   - Logging configured for sync operations
   - See examples in this documentation for setup

2. **Nginx Web Server**
   - Nginx configured to serve the mirror directories
   - Directory browsing enabled
   - Proper access to repository files and metadata
   - HTTP/HTTPS access configured
   - See examples in this documentation for Nginx configuration

3. **SSL Certificate (Required)**
   - **Proper SSL certificate is required** for mirrors added to the CloudLinux mirror service
   - Valid SSL certificate from a trusted Certificate Authority (CA)
   - Let's Encrypt certificates are recommended and supported
   - Certificate must be valid and not expired
   - HTTPS must be properly configured and working
   - Automatic certificate renewal should be configured (e.g., via Certbot)
   - The Ansible playbooks in this repository include automatic SSL certificate setup using Certbot
   - See `ansible/CERTBOT-SSL-SETUP.md` for detailed SSL configuration instructions

4. **Repository Structure**
   - Mirror must be accessible via HTTPS (SSL certificate required)
   - Repository metadata properly generated
   - GPG keys accessible
   - Proper directory structure matching upstream

### Adding Your Mirror to the Mirror Service

To have your mirror added to the CloudLinux mirror service (mirrorlist at `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`), contact the CloudLinux support team.

**Contact CloudLinux Support:**
- **Email:** Contact CloudLinux support team
- **Information to Provide:**
  - Mirror URL with HTTPS (e.g., `https://mirror.yourdomain.com/swng/` for SWNG)
  - **Confirmation that SSL certificate is properly configured and valid**
  - SWNG mirror URL (if mirroring SWNG)
  - CloudLinux repository URL (if mirroring CloudLinux repository)
  - Geographic location of the mirror
  - Available bandwidth/capacity
  - Sync frequency and method
  - Whether it's for public or private use
  - For private use: specific IP addresses or networks that should use this mirror

**Public index requirement (for SWNG):**
- The domain name/path you provide to CloudLinux support must return a directory index that matches the upstream layout.
- For mixed setups, the SWNG public index can be under `<domain>/swng/`.
- Example public page (output similar to upstream):

```
curl -L https://swng.example.net/
<html>
<head><title>Index of /</title></head>
<body>
<h1>Index of /</h1><hr><pre><a href="../">../</a>
<a href="10/">10/</a>
<a href="8/">8/</a>
<a href="8-next/">8-next/</a>
<a href="9/">9/</a>
<a href="9-next/">9-next/</a>
<a href="cloudlinux-amd64-debian-linux-server-focal-staging/">cloudlinux-amd64-debian-linux-server-focal-staging/</a>
<a href="cloudlinux-athlon-server-5/">cloudlinux-athlon-server-5/</a>
<a href="cloudlinux-i386-server-5/">cloudlinux-i386-server-5/</a>
<a href="cloudlinux-i386-server-5-hybrid/">cloudlinux-i386-server-5-hybrid/</a>
<a href="cloudlinux-i386-server-6/">cloudlinux-i386-server-6/</a>
<a href="cloudlinux-i686-server-5/">cloudlinux-i686-server-5/</a>
<a href="cloudlinux-i686-server-5-hybrid/">cloudlinux-i686-server-5-hybrid/</a>
<a href="cloudlinux-i686-server-6/">cloudlinux-i686-server-6/</a>
<a href="cloudlinux-x86_64-server-10/">cloudlinux-x86_64-server-10/</a>
<a href="cloudlinux-x86_64-server-5/">cloudlinux-x86_64-server-5/</a>
<a href="cloudlinux-x86_64-server-5-hybrid/">cloudlinux-x86_64-server-5-hybrid/</a>
<a href="cloudlinux-x86_64-server-6/">cloudlinux-x86_64-server-6/</a>
<a href="cloudlinux-x86_64-server-6-hybrid/">cloudlinux-x86_64-server-6-hybrid/</a>
<a href="cloudlinux-x86_64-server-6-hybrid-legacy/">cloudlinux-x86_64-server-6-hybrid-legacy/</a>
...
<a href="cloudlinux-x86_64-server-9.6/">cloudlinux-x86_64-server-9.6/</a>
<a href="cloudlinux-x86_64-server-9.7/">cloudlinux-x86_64-server-9.7/</a>
<a href="listAllPackagesChecksum/">listAllPackagesChecksum/</a>
<a href="lost%2Bfound/">lost+found/</a>
<a href="ubuntu-amd64-debian-linux-server-jammy/">ubuntu-amd64-debian-linux-server-jammy/</a>
<a href="cloudlinux-x86_64-server-8.tgz">cloudlinux-x86_64-server-8.tgz</a>
</pre><hr></body>
</html>
```

**Partial SWNG public mirrors (select versions only):**
- Customers can sync only the required SWNG versions and declare the list to CloudLinux support.
- Provide the versions you mirror using `swng_options`, for example:

```yaml
swng_options:
  repos:
    - name: "cloudlinux-x86_64-server-9.6"
      type: "dnf"
    - name: "cloudlinux-x86_64-server-9.7"
      type: "dnf"
    - name: "ubuntu-amd64-debian-linux-server-jammy"
      type: "apt"
      dist:
        url: "stable/22.04"
        name: "jammy"
        suites:
        components:
          - "main"
```

### Mirror Access Options

1. **Public Mirror Rotation**
   - Your mirror will be added to the global mirror rotation
   - CloudLinux systems will automatically select the best mirror based on geographic location and performance
   - All CloudLinux customers can potentially use your mirror
   - Mirror appears in the public mirrorlist

2. **Private Mirror (IP/Network-based)**
   - Your mirror can be configured for specific IP addresses or networks only
   - Only machines from those IP addresses or networks will use your mirror
   - **This allows you to use "vanilla" CloudLinux and YUM settings** while using your own dedicated mirror
   - No changes needed to CloudLinux or YUM configuration on client machines
   - Useful for enterprise customers with dedicated infrastructure
   - Requires providing specific IP addresses or network ranges to CloudLinux support
   - **Automatic fallback**: If your private mirror is not operating, systems automatically fall back to public mirrors

**Benefits of Private Mirror Configuration:**
- Use standard CloudLinux and YUM configuration (no custom repository URLs needed)
- Automatic mirror selection for specified IP addresses/networks via the mirror service
- Transparent to end users - no configuration changes required
- Your infrastructure serves your specific network while maintaining standard settings
- High availability through automatic fallback to public mirrors if your mirror is unavailable
- The mirror service (`https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`) automatically provides the appropriate mirror list based on the requesting IP address

### Mirror Service Requirements

- Mirror must be accessible 24/7
- **Must have a valid SSL certificate** (HTTPS required)
- SSL certificate must be from a trusted Certificate Authority
- Certificate must be valid and not expired
- Must maintain synchronization (use timers as shown in examples above)
- Must serve valid repository metadata
- Must have sufficient bandwidth for expected load
- Must follow CloudLinux mirroring best practices
- Nginx must be properly configured and running with HTTPS
- Sync scripts must be operational
- Automatic certificate renewal should be configured

### Example: Mirror Information to Provide to Support

**For Public Mirror:**

```
Mirror Details:
- SWNG URL: https://mirror.example.com/swng/
- CloudLinux URL: https://mirror.example.com/cloudlinux/ (if applicable)
- SSL Certificate: Valid Let's Encrypt certificate (auto-renewal configured)
- Location: US East (Virginia)
- Bandwidth: 10 Gbps
- Type: Public rotation
- Sync Method: RSync with systemd timer
- Sync Frequency: Every 4 hours
- Storage: 2 TB available
- Web Server: Nginx with HTTPS (configured and running)
- Sync Scripts: Systemd timers configured
```

**For Private Mirror (IP/Network-based):**

```
Mirror Details:
- SWNG URL: https://mirror.example.com/swng/
- CloudLinux URL: https://mirror.example.com/cloudlinux/ (if applicable)
- SSL Certificate: Valid Let's Encrypt certificate (auto-renewal configured)
- Location: US East (Virginia)
- Type: Private mirror for specific IP addresses/networks
- IP Addresses/Networks: 
  - 192.168.0.0/16
  - 10.0.0.0/8
  - 203.0.113.0/24
- Sync Method: RSync with systemd timer
- Sync Frequency: Every 4 hours
- Web Server: Nginx with HTTPS (configured and running)
- Sync Scripts: Systemd timers configured
- Note: Want to use vanilla CloudLinux/YUM settings with dedicated mirror
```

### Verification After Mirror is Added

Once your mirror is added to rotation, you can verify it's being used:

```bash
# Check which mirror is being used
yum repoinfo

# Test repository access
yum makecache

# Verify SSL certificate is working
curl -I https://mirror.yourdomain.com/swng/
openssl s_client -connect mirror.yourdomain.com:443 -servername mirror.yourdomain.com

# Monitor mirror access logs (if configured)
tail -f /var/log/httpd/access_log
# or
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/ssl-access.log
```

## SSL Certificate Setup

**Important:** All mirrors must have a valid SSL certificate. 
The Ansible playbooks in this repository include automatic SSL certificate setup:

- **Automatic Setup:** All playbooks include Certbot configuration for Let's Encrypt certificates
- **HTTPS by Default:** Playbooks configure HTTPS with automatic HTTP to HTTPS redirect
- **Auto-Renewal:** Certificates are automatically renewed via cron job


To set up SSL manually or customize the configuration, refer to the Certbot documentation or use the Ansible playbooks which handle SSL setup automatically.


### Overview

All playbooks configured to automatically:
1. Install Certbot and python3-certbot-nginx
2. Obtain Let's Encrypt SSL certificates
3. Configure Nginx for HTTPS with automatic HTTP to HTTPS redirect
4. Set up automatic certificate renewal via cron

### Variables

Each playbook's contains `vars` section:

```yaml
vars:
  # ... existing variables ...
  
  # SSL/Certbot configuration
  mirror_domain: "{{ inventory_hostname }}"  # Domain name for the mirror
  certbot_email: "admin@{{ mirror_domain }}"  # Email for Let's Encrypt notifications
  certbot_authenticator: standalone  # Options: standalone, webroot
  certbot_webroot: "{{ mirror_base_path }}/acme"  # Only used with webroot authenticator
  certbot_enabled: true  # Set to false to disable SSL setup
  certbot_cron_enabled: true  # Enable automatic renewal
  certbot_cron_schedule:
    minute: 0
    hour: 3
```

### Tasks

Each playbook's contains this tasks

```yaml
- name: Install certbot packages
  package:
    name:
      - certbot
      - python3-certbot-nginx
    state: present
  when: certbot_enabled | bool

- name: Create webroot for ACME challenge (when using webroot)
  file:
    path: "{{ certbot_webroot }}"
    state: directory
    owner: root
    group: root
    mode: '0755'
  when: certbot_enabled | bool and certbot_authenticator == 'webroot'

- name: Stop nginx for standalone auth (if running)
  systemd:
    name: nginx
    state: stopped
  when: certbot_enabled | bool and certbot_authenticator == 'standalone'
  ignore_errors: true

- name: Obtain Let's Encrypt cert using standalone
  command: >
    certbot certonly --standalone --preferred-challenges http
    --non-interactive --agree-tos
    --email {{ certbot_email }}
    -d {{ mirror_domain }}
  args:
    creates: "/etc/letsencrypt/live/{{ mirror_domain }}/fullchain.pem"
  when: certbot_enabled | bool and certbot_authenticator == 'standalone'
  ignore_errors: true

- name: Obtain Let's Encrypt cert using webroot
  command: >
    certbot certonly --webroot
    --webroot-path {{ certbot_webroot }}
    --non-interactive --agree-tos
    --email {{ certbot_email }}
    -d {{ mirror_domain }}
  args:
    creates: "/etc/letsencrypt/live/{{ mirror_domain }}/fullchain.pem"
  when: certbot_enabled | bool and certbot_authenticator == 'webroot'
  ignore_errors: true

- name: Start nginx after standalone certbot
  systemd:
    name: nginx
    state: started
  when: certbot_enabled | bool and certbot_authenticator == 'standalone'

- name: Create Nginx HTTPS configuration
  template:
    src: nginx-https.conf.j2
    dest: /etc/nginx/conf.d/{{ service_name | default('mirror') }}-https.conf
    mode: '0644'
  notify: restart nginx
  when: certbot_enabled | bool

- name: Update HTTP Nginx configuration to redirect to HTTPS
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/conf.d/{{ service_name | default('mirror') }}.conf
    mode: '0644'
  notify: restart nginx
  when: certbot_enabled | bool

- name: Ensure certbot renew cron job exists
  cron:
    name: "Certbot renew"
    job: "certbot renew --quiet --deploy-hook 'systemctl reload nginx'"
    minute: "{{ certbot_cron_schedule.minute }}"
    hour: "{{ certbot_cron_schedule.hour }}"
  when: certbot_enabled | bool and certbot_cron_enabled | bool
```

### Nginx Configuration

 HTTP Configuration (nginx.conf.j2)

```nginx
{% if certbot_enabled | default(false) %}
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name {{ mirror_domain }};
    
    # ACME challenge location for Let's Encrypt
    location /.well-known/acme-challenge/ {
        root {{ certbot_webroot | default('/var/www/mirrors/acme') }};
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}
{% else %}
# Original HTTP-only configuration
server {
    listen 80;
    server_name _;
    # ... rest of configuration ...
}
{% endif %}
```

HTTPS Configuration (nginx-https.conf.j2)

```nginx
server {
    listen 443 ssl http2;
    server_name {{ mirror_domain }};
    root {{ mirror_path }};
    index index.html;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/{{ mirror_domain }}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{{ mirror_domain }}/privkey.pem;
    
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

    # Logging
    access_log /var/log/nginx/mirror-https-access.log;
    error_log /var/log/nginx/mirror-https-error.log;

    # Repository locations
    location / {
        try_files $uri $uri/ =404;
    }

    # Allow large file downloads
    client_max_body_size 0;
}
```

## Authenticator Methods

### Standalone (Default)
- Stops Nginx temporarily during certificate issuance
- Simpler setup, no webroot configuration needed
- Use when: You can temporarily stop Nginx

### Webroot
- Nginx continues running during certificate issuance
- Requires webroot directory to be accessible
- Use when: Nginx must remain running

## Certificate Renewal

Certificates are automatically renewed via cron job (default: daily at 3:00 AM). The renewal hook reloads Nginx to use the new certificates.

## Files Created

- `/etc/letsencrypt/live/<domain>/fullchain.pem` - SSL certificate
- `/etc/letsencrypt/live/<domain>/privkey.pem` - Private key
- `/etc/nginx/conf.d/<service>-https.conf` - HTTPS configuration
- Cron job for automatic renewal


## Choosing the Right Approach

### Manual Setup (RSync/Systemd)
**Best for:**
- Single server setups
- Full control over configuration
- Learning and understanding the process
- Custom requirements

**Advantages:**
- Direct system integration
- No additional dependencies
- Full visibility and control

### Ansible Playbooks
**Best for:**
- Multiple server management
- Infrastructure-as-code practices
- Version-controlled configurations
- Team collaboration
- Automated deployments

**Advantages:**
- Repeatable, documented setup
- Multi-server automation
- Configuration management
- Easy updates and maintenance

### Docker Containers
**Best for:**
- Containerized environments
- Quick deployment and testing
- Resource isolation
- Cloud deployments
- Microservices architecture

**Advantages:**
- Isolation and portability
- Easy deployment
- Resource control
- Consistent environments

### Comparison Summary

| Feature | Manual | Ansible | Docker |
|---------|--------|---------|--------|
| Setup Complexity | Medium | Low | Low |
| Multi-Server | Manual | Automated | Per Container |
| Configuration Management | Manual | Version Controlled | Container Config |
| Resource Isolation | No | No | Yes |
| Portability | Low | Medium | High |
| Learning Curve | Medium | Medium | Low |
| Best For | Single Server | Multiple Servers | Containerized |

## Using apt-mirror (For Debian/Ubuntu-based Systems)

If you're mirroring on a Debian/Ubuntu system:

### Step 1: Install apt-mirror

```bash
apt-get update
apt-get install -y apt-mirror
```

### Step 2: Configure apt-mirror

Edit `/etc/apt/mirror.list`:

```
############# config ##################
set base_path    /var/spool/apt-mirror
set nthreads     20
set _tilde       0
#######################################

deb https://upstream.cloudlinux.com/cloudlinux/ cloudlinux main
```

### Step 3: Run Mirror

```bash
apt-mirror
```

## Serving Your Local Mirror

### Option 1: Nginx

Create `/etc/nginx/conf.d/cloudlinux-mirror.conf`:

```nginx
server {
    listen 80;
    server_name mirror.yourdomain.com;
    root /var/www/mirrors/cloudlinux;
    
    location / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
```

### Option 2: Apache

Create `/etc/httpd/conf.d/cloudlinux-mirror.conf`:

```apache
<VirtualHost *:80>
    ServerName mirror.yourdomain.com
    DocumentRoot /var/www/mirrors/cloudlinux
    
    <Directory /var/www/mirrors/cloudlinux>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
```

## Best Practices

1. **Bandwidth Management:**
   - Use `--bwlimit` option to limit bandwidth during business hours
   - Schedule syncs during off-peak hours

2. **Storage Management:**
   - Monitor disk usage regularly
   - Consider excluding old versions if space is limited
   - Use `--exclude` to skip unnecessary content

3. **Error Handling:**
   - Monitor sync logs for errors
   - Set up alerts for failed syncs
   - Keep multiple sync attempts in case of temporary failures

4. **Security:**
   - Keep your mirror server updated
   - Use HTTPS if serving to clients
   - Implement access controls if needed

5. **Performance:**
   - Use local storage (not network storage) for better performance
   - Consider using SSD for frequently accessed repositories
   - Monitor I/O performance



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
# Sync only CloudLinux 8
rsync -av --delete \
  --include="8/**" \
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
  rsync://upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/
```


## Recommendation

For most production environments, **prioritize mirroring SWNG** as it contains all packages needed for operational systems and receives regular updates. Mirror the CloudLinux repository (`/cloudlinux/`) only if you need conversion tools, installation images, or legacy packages.

### SSL Certificate Requirement

**Important:** All mirrors must have a valid SSL certificate to be added to the CloudLinux mirror service. The Ansible playbooks in this repository include automatic SSL certificate setup using Certbot with Let's Encrypt. Ensure your mirror has:

- Valid SSL certificate from a trusted Certificate Authority
- HTTPS properly configured and working
- Automatic certificate renewal configured
- See the "Adding Your Mirror to CloudLinux Mirror Rotation" section for detailed requirements

## Support and Resources

- **HTTP/HTTPS URL:** https://upstream.cloudlinux.com/
- **SWNG (Main Operational Repository):** https://upstream.cloudlinux.com/swng/
- **CloudLinux Repository (Conversion Tools):** https://upstream.cloudlinux.com/cloudlinux/
- **RSync Endpoint:** rsync://rsync.upstream.cloudlinux.com/
- **RSync Modules:** `SWNG` (main operational), `CLOUDLINUX` (conversion tools)
- **Public Mirrorlist:** https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors
- **Documentation:** Check CloudLinux documentation for repository configuration
- **Support:** Contact CloudLinux support for assistance with mirroring and adding your mirror to the mirror service


## Summary

`upstream.cloudlinux.com` provides a reliable, efficient way to create and maintain local mirrors of CloudLinux repositories. Whether you use HTTP/HTTPS for occasional downloads or RSync for complete mirroring, this service ensures you have the content you need when you need it.


## Manual Installations

Short, direct examples. Adjust paths as needed.
### Prepare Storage

Ensure you have sufficient disk space. Repository mirrors can require several hundred gigabytes to multiple terabytes depending on what you mirror.

**Storage recommendation:** Use a dedicated disk or partition for mirror storage to avoid filling the root filesystem and to improve I/O performance.

**Sizing guidance:**
- SWNG mirror size is approximately **500 GB**
- The full `repo.cloudlinux.com` (CloudLinux repository) is **3+ TB**
- In most cases, **sync `repo.cloudlinux.com` only partially** (only the repositories you actually need)

**Recommendation:** For most production environments, prioritize mirroring **SWNG** (the main operational repository) as it contains all packages needed for operational systems.


## 1. Combined-mirror: Mirroring SWNG + CloudLinux with RSync

This example shows how to create a combined local mirror of SWNG and CloudLinux repositories using RSync with automated updates via systemd timers.

#### Step 1: Prepare Storage and Initial Sync
Check available disk space (SWNG can require several hundred GB)
```bash
df -h
```
Create mirror directories
```bash
mkdir -p /var/www/mirrors/swng /var/www/mirrors/cloudlinux

# Perform initial sync (this may take several hours)
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ \
  /var/www/mirrors/swng/

rsync -av --delete \
  --progress \
  --log-file=/var/log/cloudlinux-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/
```

#### Step 2: Create Systemd Service and Timer for Automated Updates
Create `/etc/systemd/system/combined-mirror.service`:

```bash
[Unit]
Description=Sync Complete CloudLinux and SWNG Mirrors
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/SWNG/ /var/www/mirrors/swng/ && /usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /var/www/mirrors/cloudlinux/'
StandardOutput=append:/var/log/combined-mirror.log
StandardError=append:/var/log/combined-mirror.log
```

Create `/etc/systemd/system/combined-mirror.timer`:

```bash
[Unit]
Description=Run Combined Mirror Sync Every 4 Hours
Requires=combined-mirror.service

[Timer]
OnCalendar=*-*-* 00,04,08,12,16,20:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start the timer:

```bash
systemctl daemon-reload
systemctl enable combined-mirror.timer
systemctl start combined-mirror.timer

# Check timer status
systemctl status combined-mirror.timer
systemctl list-timers combined-mirror.timer
```
For automation (systemd timers), see `ansible/combined-mirror/README.md`.


## 2. Complete-swng-rsync: Mirroring the Complete SWNG Repository with RSync

This example shows how to create a complete local mirror of all SWNG repositories using RSync with automated updates via systemd timers.

#### Step 1: Prepare Storage and Initial Sync
Check available disk space (SWNG can require several hundred GB)
```bash
df -h
```
Create mirror directory
```bash
mkdir -p /var/www/mirrors/swng

# Perform initial sync (this may take several hours)
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ \
  /var/www/mirrors/swng/
```
#### Step 2: Create Systemd Service and Timer for Automated Updates
Create /etc/systemd/system/swng-mirror.service:

```bash
[Unit]
Description=Sync Complete SWNG Repository Mirror
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ \
  /var/www/mirrors/swng/
StandardOutput=append:/var/log/swng-mirror.log
StandardError=append:/var/log/swng-mirror.log
```
Create /etc/systemd/system/swng-mirror.timer:

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
For automation (systemd timers), see `ansible/complete-swng-rsync/README.md`.


## 3. Specific-version-rsync: Mirroring Specific SWNG Versions with RSync (Recommended)

This example shows how to mirror a specific CloudLinux version (10) from SWNG using RSync with automated updates via systemd timers.

#### Step 1: Prepare Storage and Initial Sync
Check available disk space
```bash
df -h
```
Create mirror directory
```bash
mkdir -p /var/www/mirrors/swng/10

# Perform initial sync (this may take several hours)
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-10-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/10/ \
  /var/www/mirrors/swng/10/
```

#### Step 2: Create Systemd Service and Timer for Automated Updates
Create `/etc/systemd/system/swng-10-mirror.service`:

```bash
[Unit]
Description=Sync CloudLinux 10 SWNG Repository Mirror
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/SWNG/10/ \
  /var/www/mirrors/swng/10/
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

# Check timer status
systemctl status swng-10-mirror.timer
systemctl list-timers swng-10-mirror.timer
```

For automation (systemd timers), see `ansible/specific-version-rsync(Recomended)/README.md`.


## yum-reposync: Mirroring specific repositories with `reposync`
### Current and actively maintained CloudLinux versions: 10 (8/9 coming soon)

For YUM/DNF-based mirroring, you can use `reposync` to mirror specific repository paths:

#### Step 1: Install Required Tools

```bash
dnf -y install dnf-plugins-core createrepo_c || yum -y install yum-utils createrepo
```

#### Step 2: Create Repository Configuration for Specific Repositories

Create `/etc/yum.repos.d/cloudlinux-upstream.repo` with specific repository paths:

**Example: CloudLinux 10 BaseOS x86_64**

```ini
[CloudLinux-10-x86_64]
name=CloudLinux 10 BaseOS x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/10/BaseOS/x86_64/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

**Example: CloudLinux 10 AppStream x86_64**

```ini
[CloudLinux-10-x86_64-AppStream]
name=CloudLinux 10 AppStream x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/10/AppStream/x86_64/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

**Example: Multiple Repositories (CloudLinux 10)**

```ini
[CloudLinux-10-x86_64-BaseOS]
name=CloudLinux 10 BaseOS x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/10/BaseOS/x86_64/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux

[CloudLinux-10-x86_64-AppStream]
name=CloudLinux 10 AppStream x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/10/AppStream/x86_64/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux

[CloudLinux-10-x86_64-Extras]
name=CloudLinux 10 Extras x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/10/extras/x86_64/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

#### Step 3: Sync Specific Repository

```bash
# Create destination directory
mkdir -p /var/www/mirrors/cloudlinux

# Sync CloudLinux 10 BaseOS repository
reposync -p /var/www/mirrors/cloudlinux/ -r CloudLinux-10-x86_64

# Sync multiple repositories
reposync -p /var/www/mirrors/cloudlinux/ -r CloudLinux-10-x86_64-BaseOS -r CloudLinux-10-x86_64-AppStream

# Update repository metadata after sync
createrepo_c /var/www/mirrors/cloudlinux/CloudLinux-10-x86_64/ || createrepo /var/www/mirrors/cloudlinux/CloudLinux-10-x86_64/
```

#### Step 4: Browse Available Repositories

You can explore available repository paths using curl:

```bash
# List CloudLinux versions
curl https://upstream.cloudlinux.com/cloudlinux/

# List CloudLinux 10 repositories
curl https://upstream.cloudlinux.com/cloudlinux/10/

# List BaseOS architectures
curl https://upstream.cloudlinux.com/cloudlinux/10/BaseOS/

# List specific repository contents
curl https://upstream.cloudlinux.com/cloudlinux/10/BaseOS/x86_64/os/
```

### Using RSync for Specific Repository Paths

You can clone specific repository paths using RSync by specifying the path after the module name:

#### Basic RSync for Specific Paths

```bash
# Clone CloudLinux 10 BaseOS repository
rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/10/BaseOS/ \
  /var/www/mirrors/cloudlinux/10/BaseOS/

# Clone CloudLinux 10 BaseOS x86_64 only
rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/10/BaseOS/x86_64/ \
  /var/www/mirrors/cloudlinux/10/BaseOS/x86_64/
```

#### Explore Available RSync Paths

You can list available paths using RSync:

```bash
# List available modules
rsync rsync://rsync.upstream.cloudlinux.com/

# List CloudLinux repository structure
rsync rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/

# List CloudLinux 10 structure
rsync rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/10/

# List BaseOS structure
rsync rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/10/BaseOS/

# Example output:
# drwxr-xr-x             28 2025/11/14 15:00:10 .
# drwxr-xr-x             33 2025/11/14 15:00:14 x86_64
```

#### Complete Example: Cloning CloudLinux 10 BaseOS

```bash
# Create destination directory
mkdir -p /var/www/mirrors/cloudlinux/10/BaseOS

# Clone the repository
rsync -av --delete \
  --progress \
  --log-file=/var/log/cloudlinux-10-baseos-sync.log \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/10/BaseOS/ \
  /var/www/mirrors/cloudlinux/10/BaseOS/

# Verify the sync
ls -lh /var/www/mirrors/cloudlinux/10/BaseOS/
```

#### Automated Sync for Specific Repositories

Create a systemd service for automated syncing of specific repositories:

**`/etc/systemd/system/cloudlinux-10-baseos-sync.service`:**

```ini
[Unit]
Description=Sync CloudLinux 10 BaseOS Repository
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/10/BaseOS/ /var/www/mirrors/cloudlinux/10/BaseOS/
StandardOutput=append:/var/log/cloudlinux-10-baseos-sync.log
StandardError=append:/var/log/cloudlinux-10-baseos-sync.log
```

**`/etc/systemd/system/cloudlinux-10-baseos-sync.timer`:**

```ini
[Unit]
Description=Run CloudLinux 10 BaseOS Sync Every 6 Hours
Requires=cloudlinux-10-baseos-sync.service

[Timer]
OnCalendar=*-*-* 00,06,12,18:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl enable cloudlinux-10-baseos-sync.timer
systemctl start cloudlinux-10-baseos-sync.timer
```

### Mirroring specific SWNG repositories with `reposync`

This example shows how to use `reposync` (from `yum-utils`) to mirror specific SWNG repositories for specific CloudLinux versions.

#### Step 1: Install Required Tools

```bash
dnf -y install dnf-plugins-core createrepo_c || yum -y install yum-utils createrepo
```

#### Step 2: Create Repository Configuration for SWNG

Create `/etc/yum.repos.d/swng-upstream.repo`:

**Example: CloudLinux 10 SWNG x86_64**

```ini
[SWNG-10-x86_64]
name=CloudLinux 10 SWNG x86_64 (Main Operational Repository)
baseurl=https://upstream.cloudlinux.com/swng/10/x86_64/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

**Note:** The SWNG repository structure at `https://upstream.cloudlinux.com/swng/` contains version directories (10/, etc.). Each version directory contains architecture-specific subdirectories (x86_64/, aarch64/, etc.) with the actual repository content.

**Example: Multiple SWNG Repositories (CloudLinux 10)**

```ini
[SWNG-10-x86_64]
name=CloudLinux 10 SWNG x86_64
baseurl=https://upstream.cloudlinux.com/swng/10/x86_64/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

#### Step 3: Sync Specific SWNG Repository

```bash
# Create destination directory
mkdir -p /var/www/mirrors/swng

# Sync CloudLinux 10 SWNG repository
reposync -p /var/www/mirrors/swng/ -r SWNG-10-x86_64

# Update repository metadata after sync
createrepo_c /var/www/mirrors/swng/SWNG-10-x86_64/ || createrepo /var/www/mirrors/swng/SWNG-10-x86_64/
```

#### Step 4: Create Automated Sync with Systemd Timer

Create `/etc/systemd/system/swng-reposync.service`:

```ini
[Unit]
Description=Sync SWNG Repositories with reposync
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reposync -p /var/www/mirrors/swng/ -r SWNG-10-x86_64
ExecStartPost=/bin/bash -c '/usr/bin/createrepo_c /var/www/mirrors/swng/SWNG-10-x86_64/ || /usr/bin/createrepo /var/www/mirrors/swng/SWNG-10-x86_64/'
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
```