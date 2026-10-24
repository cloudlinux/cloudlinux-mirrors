# CloudLinux Mirror Setup

This repository contains ready-to-use Ansible playbooks, Docker Compose setups, and manual step-by-step instructions for setting up CloudLinux repository mirrors.

For background on the mirror system changes (legacy XMLRPC/custom SSL to standard HTTPS) and the migration guide, see the public KB article: **CloudLinux Mirror System: What Is Changing and How to Migrate** [CloudLinux Support KB](https://cloudlinux.zendesk.com/hc/en-us/articles/26200193937052-CloudLinux-Mirror-System-What-Is-Changing-and-How-to-Migrate?brand_id=1568765).

**CloudLinux OS 7, 8, 9 and 10** clients get their repositories from the mirror service once both packages below are at or above these versions:

| OS | `cloudlinux-release` | `rhn-client-tools` |
|---|---|---|
| CloudLinux OS 7 | 7.9-2.15.el7h | 2.0.2-54 (2.0.2-55 or newer recommended) |
| CloudLinux OS 8 | 8.10-14 | 3.0.3-1 |
| CloudLinux OS 9 | 9.7-2 | 3.0.3-1 |
| CloudLinux OS 10 | all releases | all releases |

Both packages are required: `cloudlinux-release` adds the mirrorlist repository, but the CLN channel (same repo id) shadows it until `rhn-client-tools` is updated too, and `cloudlinux-release` does not pull in the new `rhn-client-tools`, so updating `cloudlinux-release` alone silently stays on CLN.

## Table of Contents

- [Mirror Requirements](#mirror-requirements)
- [Recommended Setup: complete-swng-rsync](#recommended-setup-complete-swng-rsync)
- [Alternative Mirror Types](#alternative-mirror-types)
- [Setup Methods](#setup-methods)
- [Adding /healthcheck to Existing Deployments](#adding-healthcheck-to-existing-deployments)
- [Registering Your Mirror](#registering-your-mirror)
- [Best Practices](#best-practices)
- [Upstream Reference](#upstream-reference)
- [Support](#support)

## Mirror Requirements

Your mirror must meet these requirements to be included in the CloudLinux mirror service:

- **HTTPS** with a valid certificate from a public CA (e.g., Let's Encrypt)
- **Directory browsing** enabled (public index must match upstream layout)
- **No authentication** required to access repository content
- **Repository metadata** accessible (`repodata/repomd.xml` reachable for mirrored trees)
- **Automated sync** configured (systemd timer or cron, every 4-6 hours recommended)
- **Correct base paths**: e.g. `https://your-mirror.example.com/swng/` for SWNG

The Ansible playbooks include automatic SSL certificate setup using Certbot with Let's Encrypt.

Where the mirror data lives is up to you: `mirror_base_path` (default `/var/www/mirrors`) can be a
directory on the root filesystem or a dedicated disk mounted anywhere (CloudLinux's own mirrors use
`/storage`). Mount the disk first if you want one, set `mirror_base_path` in `defaults/main.yml`, and
the playbook checks that the filesystem holding it has at least `mirror_min_free_gb` free before it
starts the initial sync (the default per mirror type is in the comparison table below).

## Recommended Setup: complete-swng-rsync

Mirrors the **entire SWNG** repository (all supported versions).

- Complete SWNG mirror using RSync
- Systemd timers for automated updates
- Best for: central mirror serving multiple CloudLinux versions
- Storage: ~600 GB with `rsync -H` (~760 GB without)

Each setup method has its own detailed README:

| Method | Location | Best for |
|---|---|---|
| **Ansible** | `ansible/complete-swng-rsync/` | Multiple servers, automated deployment |
| **Docker** | `docker/complete-swng-rsync/` | Containerized environments |
| **Manual** | `manual install/README.md` (section 2) | Single server, step-by-step |

### Quick Start

**Ansible:**

```bash
cd ansible/complete-swng-rsync/
# Edit inventory.ini with your target hosts
ansible-playbook -i inventory.ini playbook.yml
```

**Docker:**

```bash
cd docker/complete-swng-rsync/
mkdir -p mirror-data logs
docker compose up -d
```

**Manual:** follow section "2. Complete-swng-rsync" in `manual install/README.md`.

## Alternative Mirror Types

If the recommended setup doesn't fit your needs, choose one of these alternatives. Each is available as Ansible, Docker, or manual installation under the corresponding directory.

### specific-version-rsync

Mirrors **only SWNG for a specific CloudLinux version**: CloudLinux 10 only (enforced by the playbook/container); to serve CloudLinux OS 7-9 clients use complete SWNG rsync.

> **Not eligible for the public mirror service.** The service checks the full channel set under `/swng/<channel-name>/`; this variant serves `/swng/<version>/` only. Use it for your own servers with a fixed `baseurl`, or deploy complete-swng-rsync to be listed.

- Smallest storage footprint
- Version-specific systemd services and timers
- Best for: single-version environments
- Storage: ~8 GB today (CloudLinux 10, 2026-10); plan 100-200 GB over the release lifetime
- Paths: `ansible/specific-version-rsync/` | `docker/specific-version-rsync/`

### yum-reposync

Uses `reposync` to mirror **specific SWNG repositories** (selective subsets).

- Selective repository and architecture mirroring
- Automatic metadata generation with `createrepo`
- Best for: tight control over which repos/arches are synced
- Storage: varies (lowest)
- Paths: `ansible/yum-reposync/` | `docker/yum-reposync/`

### combined-mirror

Mirrors both **SWNG** and **repo.cloudlinux.com** (conversion/legacy content) in one setup.

- Combined or separate sync modes
- Best for: fully autonomous environments (install + conversion + updates)
- Storage: highest (~4 TB with `rsync -H`: SWNG ~600 GB + CloudLinux repo ~3.4 TB)
- Paths: `ansible/combined-mirror/` | `docker/combined-mirror/`

> Most production environments only need SWNG. Mirror `repo.cloudlinux.com` only if you require conversion tools, installation images, or a fully offline environment. The public mirrorlist service hands out only `/swng/` URLs, so a registered mirror never receives `/cloudlinux/` traffic.

### Mirror Type Comparison

| Feature | complete-swng-rsync | specific-version-rsync | yum-reposync | combined-mirror |
|---------|---------------------|------------------------|--------------|-----------------|
| Scope | SWNG (all versions) | SWNG (one version) | SWNG (selected repos) | SWNG + CloudLinux |
| Sync method | RSync | RSync | reposync | RSync |
| Storage | ~600 GB (`rsync -H`) | ~8 GB today (CL10), plan 100-200 GB | ~8 GB (default repos) | ~4 TB |
| `mirror_min_free_gb` default | 600 | 20 | 20 | 4000 |
| Eligible for the public mirror service | **Yes** | No | No | Yes |
| Selectivity | Complete | Version-based | Repository-based | Complete |
| Best for | **Most environments** | Single-version | Fine-grained control | Full autonomous |

## Setup Methods

| | Ansible | Docker | Manual |
|---|---|---|---|
| **Location** | `ansible/<type>/` | `docker/<type>/` | `manual install/README.md` |
| **Setup complexity** | Low | Low | Medium |
| **Multi-server** | Automated | Per container | Manual |
| **Config management** | Version controlled | Container config | Manual |
| **Resource isolation** | No | Yes | No |
| **Best for** | Multiple servers | Containerized environments | Single server |

Each directory contains its own `README.md` with detailed configuration options.

## Adding /healthcheck to Existing Deployments

If you set up your mirror **before** the `/healthcheck` endpoint contract was introduced (legacy deployment, missing endpoint, or `/healthcheck.json` returning 404), follow the migration guide for your setup method:

| Method | Migration |
|---|---|
| **Ansible** | Re-run with `--tags healthcheck` — see [ansible/README.md](ansible/README.md#adding-healthcheck-to-existing-deployments) |
| **Manual** | Add files + nginx + systemd hooks — see [manual install/README.md](manual%20install/README.md#adding-healthcheck-to-existing-deployments) |

> ⚠️ **Without a working `/healthcheck.json`, your mirror is silently dropped from the mirrorlist response** even after registration — clients never reach it.

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
| **SWNG** | Main operational repository — all packages for day-to-day CloudLinux operations, security and feature updates | ~600 GB with `rsync -H` (~760 GB without) |
| **CloudLinux** (`repo.cloudlinux.com`) | Conversion tools, installation images/ISOs, legacy packages, SRPMs | ~3.4 TB with `rsync -H` (~3.8 TB without) |

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

# Mirror CloudLinux repo (~3.4 TB — partial sync recommended)
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
