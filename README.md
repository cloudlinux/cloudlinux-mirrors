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
- Current and actively maintained CloudLinux versions (8, 9, 10, etc.)
- The primary repository used by CloudLinux systems for day-to-day operations

*Note: SWNG is an acronym for "Spacewalk (open source Red Hat tool for distribution) Next Generation".*

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
- **Selective mirroring**: The new SWNG mirror system allows mirroring only the specific CloudLinux versions you need, unlike the old system which required mirroring all versions

## What is upstream.cloudlinux.com?

`upstream.cloudlinux.com` is a special repository service that provides:

- **Unrestricted Access:** No authentication required for downloading repository content
- **Multiple Access Methods:** Both HTTP/HTTPS and RSync protocols
- **Complete Repository Content:** Full access to SWNG (main operational repository) and CloudLinux (legacy/conversion tools) repositories
- **Directory Browsing:** Web interface to explore available packages and versions
- **Efficient Synchronization:** RSync support for incremental updates

## Access Methods

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
# Shows: 8/, 9/, 10/, etc. - Current CloudLinux versions

# Browse SWNG for CloudLinux 9
curl https://upstream.cloudlinux.com/swng/9/

# Browse CloudLinux repository (for conversion tools and legacy packages)
curl https://upstream.cloudlinux.com/cloudlinux/8/

# Browse CloudLinux 9 BaseOS repository
curl https://upstream.cloudlinux.com/cloudlinux/9/BaseOS/x86_64/os/

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

**Basic RSync Command:**

```bash
# Sync SWNG repository (main operational repository - recommended for most use cases)
rsync -av --delete rsync://rsync.upstream.cloudlinux.com/SWNG/ /path/to/local/mirror/swng/

# Sync CloudLinux repository (for conversion tools and legacy packages)
rsync -av --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /path/to/local/mirror/cloudlinux/
```

**Command Options Explained:**
- `-a` - Archive mode (preserves permissions, timestamps, etc.)
- `-v` - Verbose output
- `--delete` - Delete files in destination that don't exist in source
- `rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/` - Source module
- `/path/to/local/mirror/cloudlinux/` - Destination directory

## Creating a Local Mirror

### Step 1: Prepare Storage

Ensure you have sufficient disk space. Repository mirrors can require several hundred gigabytes to over a terabyte depending on what you mirror.

**Recommendation:** For most production environments, prioritize mirroring **SWNG** (the main operational repository) as it contains all packages needed for operational systems.

```bash
# Check available space
df -h

# Create mirror directories
mkdir -p /var/www/mirrors/swng      # Main operational repository (recommended)
mkdir -p /var/www/mirrors/cloudlinux # Conversion tools and legacy packages (optional)
```

### Step 2: Initial Sync

Perform the initial synchronization (this may take several hours depending on your connection):

**Recommended: Sync SWNG (Main Operational Repository)**

```bash
# Sync SWNG repository (main operational repository - recommended)
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ \
  /var/www/mirrors/swng/
```

**Note:** After setting up your mirror, ensure you configure a valid SSL certificate. The Ansible playbooks in this repository include automatic SSL certificate setup using Certbot. See the "Adding Your Mirror to CloudLinux Mirror Rotation" section for SSL certificate requirements.

**Optional: Sync CloudLinux Repository (for conversion tools and legacy packages)**

```bash
# Sync CloudLinux repository (only if you need conversion tools, images, or legacy packages)
rsync -av --delete \
  --progress \
  --log-file=/var/log/cloudlinux-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/
```

### Step 3: Set Up Automated Updates

Create a cron job or systemd timer to keep your mirror updated:

**Option A: Cron Job**

```bash
# Edit crontab
crontab -e

# Add line to sync every 4 hours
0 */4 * * * rsync -av --delete --quiet rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /var/www/mirrors/cloudlinux/ >> /var/log/cloudlinux-mirror.log 2>&1
```

**Option B: Systemd Timer**

Create `/etc/systemd/system/cloudlinux-mirror.service`:

```ini
[Unit]
Description=Sync CloudLinux Repository Mirror
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /var/www/mirrors/cloudlinux/
StandardOutput=append:/var/log/cloudlinux-mirror.log
StandardError=append:/var/log/cloudlinux-mirror.log
```

Create `/etc/systemd/system/cloudlinux-mirror.timer`:

```ini
[Unit]
Description=Run CloudLinux Mirror Sync Every 4 Hours
Requires=cloudlinux-mirror.service

[Timer]
OnCalendar=*-*-* 00,04,08,12,16,20:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl enable cloudlinux-mirror.timer
systemctl start cloudlinux-mirror.timer
```

## Cloning Specific Repositories

### Using yum_reposync for Specific Repositories

For YUM-based repositories, you can use `yum_reposync` to clone specific repository paths:

#### Step 1: Install Required Tools

```bash
yum install -y yum-utils createrepo
```

#### Step 2: Create Repository Configuration for Specific Repositories

Create `/etc/yum.repos.d/cloudlinux-upstream.repo` with specific repository paths:

**Example: CloudLinux 9 BaseOS x86_64**

```ini
[CloudLinux-9-x86_64]
name=CloudLinux 9 BaseOS x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/9/BaseOS/x86_64/os/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

**Example: CloudLinux 8 Updates x86_64**

```ini
[CloudLinux-8-x86_64-Updates]
name=CloudLinux 8 Updates x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/8/x86_64/updates/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

**Example: Multiple Repositories**

```ini
[CloudLinux-9-x86_64-BaseOS]
name=CloudLinux 9 BaseOS x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/9/BaseOS/x86_64/os/
enabled=1
gpgcheck=1

[CloudLinux-9-x86_64-AppStream]
name=CloudLinux 9 AppStream x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/9/AppStream/x86_64/os/
enabled=1
gpgcheck=1

[CloudLinux-9-x86_64-Extras]
name=CloudLinux 9 Extras x86_64
baseurl=https://upstream.cloudlinux.com/cloudlinux/9/extras/x86_64/os/
enabled=1
gpgcheck=1
```

#### Step 3: Sync Specific Repository

```bash
# Sync CloudLinux 9 BaseOS repository
reposync -p /var/www/mirrors/cloudlinux/ -r CloudLinux-9-x86_64

# Sync multiple repositories
reposync -p /var/www/mirrors/cloudlinux/ -r CloudLinux-9-x86_64-BaseOS -r CloudLinux-9-x86_64-AppStream

# Update repository metadata after sync
createrepo /var/www/mirrors/cloudlinux/CloudLinux-9-x86_64/
```

#### Step 4: Browse Available Repositories

You can explore available repository paths using curl:

```bash
# List CloudLinux versions
curl https://upstream.cloudlinux.com/cloudlinux/

# List CloudLinux 9 repositories
curl https://upstream.cloudlinux.com/cloudlinux/9/

# List BaseOS architectures
curl https://upstream.cloudlinux.com/cloudlinux/9/BaseOS/

# List specific repository contents
curl https://upstream.cloudlinux.com/cloudlinux/9/BaseOS/x86_64/os/
```

### Using RSync for Specific Repository Paths

You can clone specific repository paths using RSync by specifying the path after the module name:

#### Basic RSync for Specific Paths

```bash
# Clone CloudLinux 9 BaseOS repository
rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/9/BaseOS/ \
  /var/www/mirrors/cloudlinux/9/BaseOS/

# Clone CloudLinux 9 BaseOS x86_64 only
rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/9/BaseOS/x86_64/ \
  /var/www/mirrors/cloudlinux/9/BaseOS/x86_64/

# Clone CloudLinux 8 Updates repository
rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/8/x86_64/updates/ \
  /var/www/mirrors/cloudlinux/8/x86_64/updates/
```

#### Explore Available RSync Paths

You can list available paths using RSync:

```bash
# List available modules
rsync rsync://rsync.upstream.cloudlinux.com/

# List CloudLinux repository structure
rsync rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/

# List CloudLinux 9 structure
rsync rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/9/

# List BaseOS structure
rsync rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/9/BaseOS/

# Example output:
# drwxr-xr-x             28 2025/11/14 15:00:10 .
# drwxr-xr-x             33 2025/11/14 15:00:14 x86_64
```

#### Complete Example: Cloning CloudLinux 9 BaseOS

```bash
# Create destination directory
mkdir -p /var/www/mirrors/cloudlinux/9/BaseOS

# Clone the repository
rsync -av --delete \
  --progress \
  --log-file=/var/log/cloudlinux-9-baseos-sync.log \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/9/BaseOS/ \
  /var/www/mirrors/cloudlinux/9/BaseOS/

# Verify the sync
ls -lh /var/www/mirrors/cloudlinux/9/BaseOS/
```

#### Automated Sync for Specific Repositories

Create a systemd service for automated syncing of specific repositories:

**`/etc/systemd/system/cloudlinux-9-baseos-sync.service`:**

```ini
[Unit]
Description=Sync CloudLinux 9 BaseOS Repository
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -av --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/9/BaseOS/ /var/www/mirrors/cloudlinux/9/BaseOS/
StandardOutput=append:/var/log/cloudlinux-9-baseos-sync.log
StandardError=append:/var/log/cloudlinux-9-baseos-sync.log
```

**`/etc/systemd/system/cloudlinux-9-baseos-sync.timer`:**

```ini
[Unit]
Description=Run CloudLinux 9 BaseOS Sync Every 6 Hours
Requires=cloudlinux-9-baseos-sync.service

[Timer]
OnCalendar=*-*-* 00,06,12,18:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl enable cloudlinux-9-baseos-sync.timer
systemctl start cloudlinux-9-baseos-sync.timer
```

## Mirroring SWNG Repositories

**SWNG (Spacewalk Next Generation) is the main operational repository** for CloudLinux systems. It contains:
- All packages required for operational CloudLinux systems
- Regular security and feature updates
- Current and actively maintained CloudLinux versions (8, 9, 10, etc.)
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

This section provides comprehensive examples for creating local mirrors of SWNG repositories.

### Example 1: Mirroring the Complete SWNG Repository with RSync

This example shows how to create a complete local mirror of all SWNG repositories using RSync with automated updates via systemd timers.

#### Step 1: Prepare Storage and Initial Sync

```bash
# Check available disk space (SWNG can require several hundred GB)
df -h

# Create mirror directory
mkdir -p /var/www/mirrors/swng

# Perform initial sync (this may take several hours)
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ \
  /var/www/mirrors/swng/
```

#### Step 2: Create Systemd Service and Timer for Automated Updates

Create `/etc/systemd/system/swng-mirror.service`:

```ini
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

Create `/etc/systemd/system/swng-mirror.timer`:

```ini
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

### Example 2: Mirroring Specific SWNG Versions with RSync

This example demonstrates how to mirror only specific CloudLinux versions from SWNG (e.g., only CloudLinux 8 or CloudLinux 9).

#### Mirroring CloudLinux 8 SWNG Only

```bash
# Create destination directory
mkdir -p /var/www/mirrors/swng/8

# Sync CloudLinux 8 SWNG repositories
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-8-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/8/ \
  /var/www/mirrors/swng/8/
```

#### Mirroring CloudLinux 9 SWNG Only

```bash
# Create destination directory
mkdir -p /var/www/mirrors/swng/9

# Sync CloudLinux 9 SWNG repositories
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-9-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/9/ \
  /var/www/mirrors/swng/9/
```

#### Automated Sync for Specific SWNG Version with Timer

Create `/etc/systemd/system/swng-9-mirror.service`:

```ini
[Unit]
Description=Sync CloudLinux 9 SWNG Repository Mirror
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/SWNG/9/ \
  /var/www/mirrors/swng/9/
StandardOutput=append:/var/log/swng-9-mirror.log
StandardError=append:/var/log/swng-9-mirror.log
```

Create `/etc/systemd/system/swng-9-mirror.timer`:

```ini
[Unit]
Description=Run CloudLinux 9 SWNG Mirror Sync Every 6 Hours
Requires=swng-9-mirror.service

[Timer]
OnCalendar=*-*-* 00,06,12,18:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start:

```bash
systemctl daemon-reload
systemctl enable swng-9-mirror.timer
systemctl start swng-9-mirror.timer
```

### Example 3: Mirroring Specific SWNG Repositories with yum-reposync

This example shows how to use `reposync` (from `yum-utils`) to mirror specific SWNG repositories for specific CloudLinux versions.

#### Step 1: Install Required Tools

```bash
yum install -y yum-utils createrepo
```

#### Step 2: Create Repository Configuration for SWNG

Create `/etc/yum.repos.d/swng-upstream.repo`:

**Example: CloudLinux 9 SWNG x86_64**

```ini
[SWNG-9-x86_64]
name=CloudLinux 9 SWNG x86_64 (Main Operational Repository)
baseurl=https://upstream.cloudlinux.com/swng/9/x86_64/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

**Example: CloudLinux 8 SWNG x86_64**

```ini
[SWNG-8-x86_64]
name=CloudLinux 8 SWNG x86_64 (Main Operational Repository)
baseurl=https://upstream.cloudlinux.com/swng/8/x86_64/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

**Note:** The SWNG repository structure at `https://upstream.cloudlinux.com/swng/` contains version directories (8/, 9/, 10/, etc.). Each version directory contains architecture-specific subdirectories (x86_64/, aarch64/, etc.) with the actual repository content.

**Example: Multiple SWNG Repositories**

```ini
[SWNG-9-x86_64]
name=CloudLinux 9 SWNG x86_64
baseurl=https://upstream.cloudlinux.com/swng/9/x86_64/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux

[SWNG-8-x86_64]
name=CloudLinux 8 SWNG x86_64
baseurl=https://upstream.cloudlinux.com/swng/8/x86_64/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

#### Step 3: Sync Specific SWNG Repository

```bash
# Sync CloudLinux 9 SWNG repository
reposync -p /var/www/mirrors/swng/ -r SWNG-9-x86_64

# Sync multiple SWNG repositories
reposync -p /var/www/mirrors/swng/ -r SWNG-9-x86_64 -r SWNG-8-x86_64

# Update repository metadata after sync
createrepo /var/www/mirrors/swng/SWNG-9-x86_64/
createrepo /var/www/mirrors/swng/SWNG-8-x86_64/
```

#### Step 4: Create Automated Sync with Systemd Timer

Create `/etc/systemd/system/swng-reposync.service`:

```ini
[Unit]
Description=Sync SWNG Repositories with reposync
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/reposync -p /var/www/mirrors/swng/ -r SWNG-9-x86_64 -r SWNG-8-x86_64
ExecStartPost=/usr/bin/createrepo /var/www/mirrors/swng/SWNG-9-x86_64/
ExecStartPost=/usr/bin/createrepo /var/www/mirrors/swng/SWNG-8-x86_64/
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

### Example 4: Mirroring Specific SWNG Repository Paths with RSync

You can mirror specific repository paths within SWNG:

```bash
# Mirror CloudLinux 9 SWNG x86_64 only
rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/SWNG/9/x86_64/ \
  /var/www/mirrors/swng/9/x86_64/

# Mirror CloudLinux 8 SWNG x86_64 only
rsync -av --delete \
  rsync://rsync.upstream.cloudlinux.com/SWNG/8/x86_64/ \
  /var/www/mirrors/swng/8/x86_64/

# Explore available SWNG paths
rsync rsync://rsync.upstream.cloudlinux.com/SWNG/
rsync rsync://rsync.upstream.cloudlinux.com/SWNG/9/
```

### Example 5: Combined CloudLinux and SWNG Mirroring

Create a comprehensive mirror setup that includes both CloudLinux and SWNG:

Create `/etc/systemd/system/cloudlinux-complete-mirror.service`:

```ini
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

```ini
[Unit]
Description=Run Complete CloudLinux and SWNG Mirror Sync Every 4 Hours
Requires=cloudlinux-complete-mirror.service

[Timer]
OnCalendar=*-*-* 00,04,08,12,16,20:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

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

### SSL Certificate Setup

**Important:** All mirrors must have a valid SSL certificate. The Ansible playbooks in this repository include automatic SSL certificate setup:

- **Automatic Setup:** All playbooks include Certbot configuration for Let's Encrypt certificates
- **HTTPS by Default:** Playbooks configure HTTPS with automatic HTTP to HTTPS redirect
- **Auto-Renewal:** Certificates are automatically renewed via cron job
- **Documentation:** See `ansible/CERTBOT-SSL-SETUP.md` for detailed SSL configuration

To set up SSL manually or customize the configuration, refer to the Certbot documentation or use the Ansible playbooks which handle SSL setup automatically.

## Automated Mirror Setup with Ansible

For organizations managing multiple mirror servers or requiring infrastructure-as-code approaches, Ansible playbooks are available to automate the complete mirror setup process.

### Available Ansible Playbooks

The repository includes several Ansible playbooks located in the `ansible/` directory:

1. **Complete SWNG Mirror** (`ansible/complete-swng-rsync/`)
   - Sets up complete SWNG repository mirror using RSync
   - Configures systemd timers for automated updates
   - Best for: Complete SWNG mirroring needs

2. **Specific Version Mirror** (`ansible/specific-version-rsync/`)
   - Mirrors specific CloudLinux versions (8 or 9)
   - Version-specific systemd services and timers
   - Best for: Organizations needing only specific versions

3. **SWNG Mirror with yum-reposync** (`ansible/yum-reposync/`)
   - Uses yum-reposync for selective repository mirroring
   - Automatic metadata generation
   - Best for: Selective repository mirroring

4. **Combined CloudLinux and SWNG Mirror** (`ansible/combined-mirror/`)
   - Mirrors both CloudLinux and SWNG repositories
   - Supports combined or separate sync modes
   - Best for: Complete mirror infrastructure

### Quick Start with Ansible

1. **Install Ansible** (if not already installed):

```bash
# On RHEL/CentOS/CloudLinux
yum install -y ansible

# On Debian/Ubuntu
apt-get install -y ansible
```

2. **Choose a playbook** and navigate to its directory:

```bash
cd ansible/complete-swng-rsync
```

3. **Edit the inventory file** (`inventory.ini`) with your server details:

```ini
[mirror_servers]
mirror-server-01 ansible_host=192.168.1.100

[mirror_servers:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

4. **Run the playbook**:

```bash
ansible-playbook -i inventory.ini playbook.yml
```

### Ansible Use Cases

- **Infrastructure Automation**: Automate mirror setup across multiple servers
- **Configuration Management**: Version-controlled mirror configurations
- **Multi-Environment Setup**: Easily replicate mirror setups in dev/staging/prod
- **Compliance**: Documented, repeatable infrastructure setup
- **Team Collaboration**: Shareable, maintainable mirror configurations

### Customization

Each playbook supports extensive customization through variables:

```bash
# Override default variables
ansible-playbook -i inventory.ini playbook.yml \
  -e "mirror_base_path=/opt/mirrors" \
  -e "sync_interval_hours=6"

# Use variables file
ansible-playbook -i inventory.ini playbook.yml -e @vars.yml
```

For detailed documentation, see `ansible/README.md` and individual playbook README files.

## Containerized Mirror Setup with Docker

For containerized environments or when you want isolated mirror processes, Docker and Docker Compose configurations are available.

### Available Docker Setups

The repository includes several Docker configurations located in the `docker/` directory:

1. **Complete SWNG Mirror** (`docker/complete-swng-rsync/`)
   - Containerized complete SWNG mirror
   - Cron-based automated syncs
   - Best for: Containerized SWNG mirroring

2. **Specific Version Mirror** (`docker/specific-version-rsync/`)
   - Containerized version-specific mirrors
   - Separate containers per version
   - Best for: Version-specific containerized mirrors

3. **SWNG Mirror with yum-reposync** (`docker/yum-reposync/`)
   - Containerized selective repository mirroring
   - Automatic metadata generation
   - Best for: Selective containerized mirroring

4. **Combined CloudLinux and SWNG Mirror** (`docker/combined-mirror/`)
   - Containerized complete mirror setup
   - Optional Nginx web server included
   - Best for: Complete containerized mirror infrastructure

### Quick Start with Docker Compose

1. **Navigate to a Docker setup directory**:

```bash
cd docker/complete-swng-rsync
```

2. **Create data directories**:

```bash
mkdir -p mirror-data logs
```

3. **Start the container**:

```bash
docker-compose up -d
```

4. **View logs**:

```bash
docker-compose logs -f
```

### Docker Use Cases

- **Containerized Infrastructure**: Run mirrors in isolated containers
- **Easy Deployment**: Simple `docker-compose up` to start mirroring
- **Resource Isolation**: Controlled CPU and memory usage
- **Portability**: Run on any Docker-compatible platform
- **Development/Testing**: Quick setup for testing mirror configurations
- **Microservices Architecture**: Integrate mirrors into containerized environments
- **Cloud Deployments**: Deploy mirrors in Kubernetes, Docker Swarm, or cloud container services

### Docker Configuration Options

All Docker setups support environment variable configuration:

```yaml
# docker-compose.yml
environment:
  - RSYNC_SOURCE=rsync://rsync.upstream.cloudlinux.com/SWNG/
  - MIRROR_PATH=/var/www/mirrors/swng
  - INITIAL_SYNC=true
  - SYNC_INTERVAL_HOURS=4
```

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

### Serving Mirrors from Containers

The combined mirror setup includes an optional Nginx service:

```bash
# Access mirrors via web server
curl http://localhost/cloudlinux/
curl http://localhost/swng/
```

For detailed documentation, see `docker/README.md` and individual setup README files.

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

## Troubleshooting

### Connection Issues

```bash
# Test RSync connectivity
rsync rsync://rsync.upstream.cloudlinux.com/

# Test HTTP connectivity
curl -I https://upstream.cloudlinux.com/

# Check DNS resolution
nslookup upstream.cloudlinux.com
```

### Sync Failures

```bash
# Check RSync logs
tail -f /var/log/cloudlinux-mirror.log

# Test with verbose output
rsync -avv --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /tmp/test-sync/

# Check disk space
df -h
```

### Partial Syncs

If a sync is interrupted, RSync will resume from where it left off on the next run. The `--partial` option can help with large files:

```bash
rsync -av --delete --partial rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /var/www/mirrors/cloudlinux/
```

## Advanced Options

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

## Support and Resources

- **HTTP/HTTPS URL:** https://upstream.cloudlinux.com/
- **SWNG (Main Operational Repository):** https://upstream.cloudlinux.com/swng/
- **CloudLinux Repository (Conversion Tools):** https://upstream.cloudlinux.com/cloudlinux/
- **RSync Endpoint:** rsync://rsync.upstream.cloudlinux.com/
- **RSync Modules:** `SWNG` (main operational), `CLOUDLINUX` (conversion tools)
- **Public Mirrorlist:** https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors
- **Documentation:** Check CloudLinux documentation for repository configuration
- **Support:** Contact CloudLinux support for assistance with mirroring and adding your mirror to the mirror service

### Repository Structure

The SWNG repository structure at `https://upstream.cloudlinux.com/swng/` contains:
- Version directories: `8/`, `9/`, `10/`, etc. (current CloudLinux versions)
- Each version directory contains architecture-specific subdirectories (e.g., `x86_64/`, `aarch64/`)
- These contain the actual repository metadata and packages

Example structure:
```
/swng/
  ├── 8/          (CloudLinux 8)
  ├── 9/          (CloudLinux 9)
  ├── 10/         (CloudLinux 10)
  └── ...
```

## Summary

`upstream.cloudlinux.com` provides a reliable, efficient way to create and maintain local mirrors of CloudLinux repositories. Whether you use HTTP/HTTPS for occasional downloads or RSync for complete mirroring, this service ensures you have the content you need when you need it.

### Repository Overview

- **SWNG** (`https://upstream.cloudlinux.com/swng/`) - **Main operational repository**
  - Contains all packages for operational CloudLinux systems
  - Receives regular security and feature updates
  - Current versions: 8, 9, 10, etc.
  - **Recommended for most production environments**

- **CloudLinux Repository** (`https://upstream.cloudlinux.com/cloudlinux/`)
  - Conversion scripts and tools
  - Installation images and ISO files
  - Older versions and legacy packages
  - Source packages (SRPMs)

### Key Advantages

- ✅ No authentication required
- ✅ Multiple access methods (HTTP/HTTPS, RSync)
- ✅ Efficient incremental updates
- ✅ Complete repository content
- ✅ Reliable and maintained by CloudLinux

### Automation Options

This repository provides multiple approaches to set up and maintain mirrors:

1. **Manual Setup**: Direct RSync commands and systemd timers for full control
2. **Ansible Playbooks**: Infrastructure-as-code automation for multiple servers
3. **Docker Containers**: Containerized mirror setups for isolated, portable deployments

Choose the approach that best fits your infrastructure and requirements. All methods support the same mirroring capabilities with different levels of automation and deployment flexibility.

### Recommendation

For most production environments, **prioritize mirroring SWNG** as it contains all packages needed for operational systems and receives regular updates. Mirror the CloudLinux repository (`/cloudlinux/`) only if you need conversion tools, installation images, or legacy packages.

### SSL Certificate Requirement

**Important:** All mirrors must have a valid SSL certificate to be added to the CloudLinux mirror service. The Ansible playbooks in this repository include automatic SSL certificate setup using Certbot with Let's Encrypt. Ensure your mirror has:

- Valid SSL certificate from a trusted Certificate Authority
- HTTPS properly configured and working
- Automatic certificate renewal configured
- See the "Adding Your Mirror to CloudLinux Mirror Rotation" section for detailed requirements
