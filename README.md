# CloudLinux Mirror Setup

This repository contains ready-to-use Ansible playbooks, Docker Compose setups, and manual step-by-step instructions for setting up CloudLinux repository mirrors.

For background on the mirror system changes (legacy XMLRPC/custom SSL to standard HTTPS) and the migration guide, see the public KB article: **CloudLinux Mirror System: What Is Changing and How to Migrate** ([CloudLinux Support](https://cloudlinux.zendesk.com/) | [Repositories & Mirrors docs](https://docs.cloudlinux.com/cloudlinuxos/repositories_and_mirrors/)).

Currently **CloudLinux OS 10** is supported. Support for older versions (8, 9) will be enabled gradually.

## Table of Contents

- [Mirror Types](#mirror-types)
- [Setup Methods](#setup-methods)
- [Mirror Requirements](#mirror-requirements)
- [Registering Your Mirror](#registering-your-mirror)
- [Best Practices](#best-practices)
- [Upstream Reference](#upstream-reference)
- [Support](#support)

## Mirror Types

Choose the mirror type that fits your needs. Each type is available as an Ansible playbook, Docker Compose setup, or manual installation.

### 1) specific-version-rsync (Recommended)

Mirrors **only SWNG for specific CloudLinux versions** (10 now; 8/9 coming soon).

- Smallest storage footprint
- Version-specific systemd services and timers
- Best for: single-version environments
- Storage: ~100-200 GB per version

### 2) complete-swng-rsync

Mirrors the **entire SWNG** repository (all supported versions).

- Complete SWNG mirror using RSync
- Systemd timers for automated updates
- Best for: central mirror serving multiple CloudLinux versions
- Storage: ~500 GB

### 3) yum-reposync

Uses `reposync` to mirror **specific SWNG repositories** (selective subsets).

- Selective repository and architecture mirroring
- Automatic metadata generation with `createrepo`
- Best for: tight control over which repos/arches are synced
- Storage: varies (lowest)

### 4) combined-mirror

Mirrors both **SWNG** and **repo.cloudlinux.com** (conversion/legacy content) in one setup.

- Combined or separate sync modes
- Best for: fully autonomous environments (install + conversion + updates)
- Storage: highest (SWNG ~500 GB + CloudLinux repo 3+ TB)

> Most production environments only need SWNG. Mirror `repo.cloudlinux.com` only if you require conversion tools, installation images, or a fully offline environment.

### Mirror Type Comparison

| Feature | specific-version-rsync | complete-swng-rsync | yum-reposync | combined-mirror |
|---------|------------------------|---------------------|--------------|-----------------|
| Scope | SWNG (one version) | SWNG (all versions) | SWNG (selected repos) | SWNG + CloudLinux |
| Sync method | RSync | RSync | reposync | RSync |
| Storage | ~100-200 GB | ~500 GB | Varies | 500 GB - 3+ TB |
| Selectivity | Version-based | Complete | Repository-based | Complete |
| Best for | Single-version | Multi-version central | Fine-grained control | Full autonomous |

## Setup Methods

| | Ansible | Docker | Manual |
|---|---|---|---|
| **Location** | `ansible/<type>/` | `docker/<type>/` | `manual install/README.md` |
| **Setup complexity** | Low | Low | Medium |
| **Multi-server** | Automated | Per container | Manual |
| **Config management** | Version controlled | Container config | Manual |
| **Resource isolation** | No | Yes | No |
| **Best for** | Multiple servers | Containerized environments | Single server |

### Quick Start

**Ansible:**

```bash
cd ansible/specific-version-rsync\(Recomended\)/
# Edit inventory.ini with your target hosts
ansible-playbook -i inventory.ini playbook.yml
```

**Docker:**

```bash
cd docker/specific-version-rsync/
mkdir -p mirror-data logs
docker compose up -d
```

**Manual:** follow the step-by-step instructions in `manual install/README.md`.

Each directory contains its own `README.md` with detailed configuration options.

## Mirror Requirements

Your mirror must meet these requirements to be included in the CloudLinux mirror service:

- **HTTPS** with a valid certificate from a public CA (e.g., Let's Encrypt)
- **Directory browsing** enabled (public index must match upstream layout)
- **No authentication** required to access repository content
- **Repository metadata** accessible (`repodata/repomd.xml` reachable for mirrored trees)
- **Automated sync** configured (systemd timer or cron, every 4-6 hours recommended)
- **Correct base paths**: e.g. `https://your-mirror.example.com/swng/` for SWNG

The Ansible playbooks include automatic SSL certificate setup using Certbot with Let's Encrypt.

## Registering Your Mirror

After setup, contact [CloudLinux Support](https://cloudlinux.zendesk.com/) to add your mirror to the mirror service at `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`.

**Information to provide:**

- Mirror URL (HTTPS), e.g. `https://mirror.example.com/swng/`
- **Public** or **private** (if private: egress IPs/CIDRs)
- Geographic location (country/city)
- Available bandwidth/capacity
- Sync method and frequency
- **Complete** or **partial** (if partial: list of mirrored versions)

**Mirror access options:**

- **Public** — added to global rotation; CloudLinux systems select the best mirror by geographic proximity and health
- **Private (IP/network-scoped)** — only machines from specified networks use your mirror; no client-side config changes needed; automatic fallback to public mirrors if your mirror is unavailable

### Verification

After your mirror is added to rotation:

```bash
# Check which mirror your system is using
yum repoinfo

# Test repository access
yum makecache

# Verify your mirror's HTTPS
curl -I https://mirror.yourdomain.com/swng/
```

## Best Practices

- **Sync schedule**: every 4-6 hours; schedule initial syncs during off-peak hours
- **Bandwidth**: use `--bwlimit` in rsync to cap bandwidth during business hours
- **Storage**: use a dedicated disk or partition; monitor disk usage regularly
- **Monitoring**: watch sync logs for errors; set up alerts for failed syncs
- **Security**: keep the mirror server OS updated; serve clients over HTTPS only

## Upstream Reference

`upstream.cloudlinux.com` is CloudLinux's dedicated mirroring endpoint providing unrestricted access to all repository content without authentication.

### Repositories

| Repository | Content | Size |
|---|---|---|
| **SWNG** | Main operational repository — all packages for day-to-day CloudLinux operations, security and feature updates | ~500 GB |
| **CloudLinux** (`repo.cloudlinux.com`) | Conversion tools, installation images/ISOs, legacy packages, SRPMs | 3+ TB |

### HTTPS Access

| URL | Content |
|---|---|
| `https://upstream.cloudlinux.com/swng/` | SWNG repository |
| `https://upstream.cloudlinux.com/cloudlinux/` | CloudLinux repository |

```bash
# Browse available SWNG versions
curl https://upstream.cloudlinux.com/swng/

# Browse CloudLinux 10 SWNG content
curl https://upstream.cloudlinux.com/swng/10/
```

### RSync Access (recommended for mirroring)

| Module | Content |
|---|---|
| `rsync://rsync.upstream.cloudlinux.com/SWNG` | SWNG repository |
| `rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX` | CloudLinux repository |

```bash
# Mirror all SWNG
rsync -avH --delete --numeric-ids --safe-links \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ /var/www/mirrors/swng/

# Mirror only CloudLinux 10 SWNG (partial)
rsync -avH --delete --numeric-ids --safe-links \
  rsync://rsync.upstream.cloudlinux.com/SWNG/10/ /var/www/mirrors/swng/10/

# Mirror CloudLinux repo (3+ TB — partial sync recommended)
rsync -avH --delete --numeric-ids --safe-links \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /var/www/mirrors/cloudlinux/
```

### SWNG Directory Layout

Your mirror's public index must match the upstream structure:

```
10/
8/
8-next/
9/
9-next/
cloudlinux-x86_64-server-10
listAllPackagesChecksum
```

The `8/`, `9/`, `10/` and `*-next` entries are symlinks to current minor release directories. In mixed setups, SWNG content can be served under `<domain>/swng/`.

### Firewall Requirements

Outbound from the mirror host:
- TCP **873** to `rsync.upstream.cloudlinux.com` (rsync)
- TCP **443** to `upstream.cloudlinux.com` (HTTPS)

Inbound to your mirror (for clients):
- TCP **443** (HTTPS)

## Support

- **Public KB**: [CloudLinux Mirror System: What Is Changing and How to Migrate](https://cloudlinux.zendesk.com/)
- **Documentation**: [Repositories & Mirrors](https://docs.cloudlinux.com/cloudlinuxos/repositories_and_mirrors/)
- **Support**: [CloudLinux Support](https://cloudlinux.zendesk.com/)
- **Mirrorlist endpoint**: `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`
