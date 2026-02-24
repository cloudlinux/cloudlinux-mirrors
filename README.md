# Repository Mirroring

## Table of Contents

- [Introduction](#introduction)
  - [Understanding CloudLinux Repositories](#understanding-cloudlinux-repositories)
  - [How CloudLinux Package Delivery Works](#how-cloudlinux-package-delivery-works)
- [Mirror System Changes (Old vs New)](#mirror-system-changes-old-vs-new)
- [What is upstream.cloudlinux.com?](#what-is-upstreamcloudlinuxcom)
  - [Access Methods](#access-methods)
- [Mirroring SWNG Repositories](#mirroring-swng-repositories)
- [Installation Types](#installation-types)
- [Adding Your Mirror to CloudLinux Mirror Rotation](#adding-your-mirror-to-cloudlinux-mirror-rotation)
  - [Mirror Requirements](#mirror-requirements)
- [Adding Your Mirror to the Mirror Service](#adding-your-mirror-to-the-mirror-service)
- [Mirror Access Options](#mirror-access-options)
- [Choosing the Right Approach](#choosing-the-right-approach)
- [Best Practices](#best-practices)
- [Recommendation](#recommendation)
- [Support and Resources](#support-and-resources)

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

**What is changing for customers starting with CloudLinux 10:**
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
- **Selective version mirroring**: Unlike the old system, SWNG allows you to mirror only the specific CloudLinux versions you need (e.g., only version 10, or other versions)
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
listAllPackagesChecksum
```

**Notes:**
- The `8/`, `9/`, `10/` and `*-next` entries are symlinks pointing to the current minor release directories.
- Directory browsing must be enabled so the index is publicly visible.

## Installation Types

This repository provides multiple approaches to set up and maintain mirrors:

1. **Ansible Playbooks**: see `ansible/README.md` and individual playbook README files.
2. **Docker Containers**: see `docker/README.md` and individual setup README files.
3. **Manual Setup**: see `manual install/README.md`.

Choose the approach that best fits your infrastructure and requirements. All methods support the same mirroring capabilities with different levels of automation and deployment flexibility.

Choose one of the supported installation types below. Each type has both Ansible and Docker implementations with full step-by-step instructions in the linked directories.

### 1) combined-mirror

Mirrors both **SWNG** and **repo.cloudlinux.com** (conversion/legacy content) in one setup.

- Supports combined or separate sync modes
- Best for: Full, self-contained mirror environments
- Storage: Highest (SWNG + CloudLinux)

### 2) complete-swng-rsync

Mirrors the **entire SWNG** repository (all supported versions).

- Sets up complete SWNG repository mirror using RSync
- Configures systemd timers for automated updates
- Best for: Central SWNG mirror, full operational updates
- Storage: High (SWNG only)

### 3) specific-version-rsync (Recommended)

Mirrors **only SWNG for CloudLinux 10** (8/9 support coming soon).

- Mirrors specific CloudLinux versions (10 now; 8/9 coming soon)
- Version-specific systemd services and timers
- Best for: Smaller storage footprint, single-version environments, needing only specific versions
- Storage: Lower


### 4) yum-reposync

Uses `reposync` to mirror **specific SWNG repositories** (selective subsets).

- Uses yum-reposync for selective repository mirroring
- Automatic metadata generation
- Best for: Tight control over which repos/arches are synced
- Storage: Lowest (only selected repos)

## Adding Your Mirror to CloudLinux Mirror Rotation

After creating your local mirror, you need to contact the CloudLinux support team to have your mirror added to the mirror service. This allows CloudLinux systems to automatically use your mirror while maintaining "vanilla" CloudLinux and YUM settings.

### Mirror Requirements

Before contacting support, ensure your mirror has the following components:

1. **Synchronization Scripts**
   - Automated sync scripts (RSync or reposync) configured
   - Systemd timers or cron jobs for regular updates
   - Logging configured for sync operations

2. **Nginx Web Server**
   - Nginx configured to serve the mirror directories
   - Directory browsing enabled
   - Proper access to repository files and metadata
   - HTTP/HTTPS access configured

3. **SSL Certificate (Required)**
   - **Proper SSL certificate is required** for mirrors added to the CloudLinux mirror service
   - Valid SSL certificate from a trusted Certificate Authority (CA)
   - Let's Encrypt certificates are recommended and supported
   - Certificate must be valid and not expired
   - HTTPS must be properly configured and working
   - Automatic certificate renewal should be configured (e.g., via Certbot)
   - The Ansible playbooks in this repository include automatic SSL certificate setup using Certbot

4. **Repository Structure**
   - Mirror must be accessible via HTTPS (SSL certificate required)
   - Repository metadata properly generated
   - GPG keys accessible
   - Proper directory structure matching upstream

## Adding Your Mirror to the Mirror Service

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
<a href="cloudlinux-x86_64-server-6-hybrid-legacy/">cloudlinux-x86_64-server-6-hybrid-legacy/</a>
...
<a href="cloudlinux-x86_64-server-9.6/">cloudlinux-x86_64-server-9.6/</a>
<a href="cloudlinux-x86_64-server-8.tgz">cloudlinux-x86_64-server-8.tgz</a>
</pre><hr></body>
</html>
```

**Partial SWNG public mirrors (select versions only):**
- Customers can sync only the required SWNG versions and declare the list to CloudLinux support.

## Mirror Access Options

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













## Choosing the Right Approach

- ### Manual Setup (RSync/Systemd)

- ### Ansible Playbooks

- ### Docker Containers

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
