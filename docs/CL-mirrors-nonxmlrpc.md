# Internal System Overview (REA&IT)

This document is for internal use by REA&IT and related teams. It summarizes the current CloudLinux mirroring system, the transition from legacy mirrors, and the internal services used to manage mirrorlists.

## Why We Are Moving to the New System

- Remove repository/mirror-side authentication and keep license validation **inside CloudLinux OS only**.
- Eliminate the **custom SSL certificate** workflow.
- Remove **CLN-proxy** request flows from the mirror path.
- Reduce **firewall complexity** and the need for whitelisting on customer-owned mirrors.
- Enable customers to **create and manage their own mirrors** more easily.
- Make mirroring more **flexible and customizable** for different customer needs.

## Key Terms (System Glossary)

- **SWNG mirrors**: Mirrors of the SWNG repository used for regular operational updates.
- **XMLRPC mirrors (legacy)**: Old mirror setup using yum-rhn-plugin/XMLRPC with custom SSL certificates bound to customer domains.
- **Non-XMLRPC mirrors (new)**: New mirror setup using standard HTTPS with public certificates (no XMLRPC).
- **`repo.cloudlinux.com`**: Main public repository for conversion/installation assets and legacy content; also serves mirrorlist endpoints.
- **Release repos**: Source-of-truth repositories hosted at:
  - `release.swng.cloudlinux.com:/swng.cloudlinux.com` (SWNG source)
  - `release.repo.cloudlinux.com` (source for `repo.cloudlinux.com` data)
  - Data is maintained by the **Userspace** team; releases are deployed by the **Buildsystem** team.
- **reposync**: Sync mechanism/service used to mirror content from release repos to `upstream.cloudlinux.com` and legacy XMLRPC mirrors.
- **mirrorservice**: Service that returns a location-aware mirrorlist for clients.
  - Old endpoint: `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cln-mirrors`
  - New endpoint: `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`
- **upstream**: `upstream.cloudlinux.com` unified endpoint for SWNG and `repo.cloudlinux.com` content.

## Host Types in the System

- **Release repos (release hosts)**: Source of truth for SWNG and `repo.cloudlinux.com` data, and the upstream feed for `upstream.cloudlinux.com`.
- **`upstream.cloudlinux.com` (upstream endpoint)**: Load-balanced entrypoint that hides multiple upstream hosts.
- **`repo.cloudlinux.com` (public repository)**: Public endpoint serving repository content and mirrorlist endpoints.
- **CloudLinux-owned mirrors**: High-availability public mirrors that serve as a global fallback when customer-owned mirrors are unavailable.
- **Customer mirrors**: Mirrors managed by customers; can be public or private and can be partial (version-scoped).

## Internal Services

### Mirrorservice (cl-mirrors)

- Repository: `https://reait.gitlab.atm.svcs.io/rea-it/cl-mirrors`
- Purpose: generate mirrorlists based on GeoIP/ASN proximity and mirror availability.
- Output: a prioritized list of mirrors appropriate for the requester.
- Supports both **public** and **private** mirrors.
- Supports **partial mirrors** with version-scoped visibility.
- Mirrors can be **scoped to specific IP ranges** via the mirrorservice, so only those networks receive the mirrorlist entry and **no client-side repository changes are required**.
- The mirrorservice returns **multiple mirrors** in priority order, so if the first (dedicated) mirror is unavailable, clients automatically fall back to the next entries.
- The mirrorservice performs **repository health checks** and returns **only healthy mirrors** in its output.
- Customers are encouraged to **set up and manage their own mirrors**; we only validate mirror health and include them in the mirrorservice.
- If needed, CloudLinux can **deploy and manage mirrors on behalf of customers**.

### Old Mirrorservice (dyn-mirrors)

- Playbook: `https://reait.gitlab.atm.svcs.io/repositories/repo-inventory/-/blob/main/playbooks/dyn_mirrors.yaml`
- Purpose: legacy mirrorservice configuration used with XMLRPC mirrorlists.

### Upstream Repository Endpoint

- `upstream.cloudlinux.com` is a **new unified public endpoint** (not used in the legacy system) for mirroring:
  - **SWNG** (operational repository)
  - **repo.cloudlinux.com** content (conversion, installation assets, legacy packages)
- Supports **HTTP/HTTPS** browsing and **RSync** for both **full** and **partial** mirrors.
- No authentication is required for downloads.
- Base paths:
  - `https://upstream.cloudlinux.com/swng/`
  - `https://upstream.cloudlinux.com/cloudlinux/`
- RSync endpoint and modules:
  - `rsync://rsync.upstream.cloudlinux.com/`
  - Modules: `SWNG`, `CLOUDLINUX`

### Deployment Playbook for CloudLinux-Owned Mirrors

- Playbook: `https://reait.gitlab.atm.svcs.io/repositories/repo-inventory/-/blob/main/playbooks/non_xmlrpc_mirrors.yaml`
- Purpose: deploy and manage CloudLinux-owned mirrors with standard HTTPS access.
- CloudLinux-owned mirrors must be **high-availability** and act as **global fallback** if customer-owned mirrors are unavailable.
- Deployment includes **monitoring** and **reposync** setup.
- Monitoring dashboard: `https://reait-mon.corp.cloudlinux.com/grafana/d/afb1bbcopcf0gc/non-xmlrpc-mirrors-utilisation?orgId=1&from=now-6h&to=now&timezone=browser`

## Transition Overview (Old to New Mirrors)

The new mirroring system is gradually replacing the old one.

**What is changing:**
- **Non-XMLRPC mirrors** replace XMLRPC mirrors, so customers can fully set up and control mirrors.
- **New mirrorservice endpoint**: `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors` replaces `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cln-mirrors`.
- **Automatic client transition**: the mirrorlist URL is updated automatically by `rhn-client-tools` and `cloudlinux-release` package updates.
- **Partial mirrors supported**: mirrors can contain only specific OS versions.
- **Autonomous install/conversion**: `repo.cloudlinux.com` content can be freely synced, enabling fully autonomous installs/conversions when needed.

**Old vs new mirrorlist endpoints:**
- **Old (`cln-mirrors`)**: required for yum-rhn-plugin/XMLRPC flow; configured via `mirrorURL` in `/etc/sysconfig/rhn/up2date`.
- **New (`cl-mirrors`)**: used with standard `mirrorlist=` entries in `.repo` files (same model as AlmaLinux).
- These endpoints are **not interchangeable**.

**XMLRPC vs non-XMLRPC mirrors (not interchangeable):**
- **XMLRPC mirrors** use customer-provided domains bound to **custom SSL certificates** for XMLRPC compatibility.
- **Non-XMLRPC mirrors** use standard HTTPS with public certificates (e.g., Let's Encrypt) and no XMLRPC.
- A single host **cannot serve both** XMLRPC and non-XMLRPC mirrors because it cannot present both the **custom SSL certificate** and a **public CA certificate** for the same domain.
- Systems that **have not updated** `cloudlinux-release` / `rhn-client-tools` **cannot use new mirrors**, and systems on older packages **must stay on old mirrors**.
- Because CloudLinux does **not control customer update cadence** or know which fleets have migrated, we **cannot unilaterally switch** customer-owned mirrors to the new flow.

**Mirrorlist behavior (legacy overview):**
- Client requests a mirrorlist, gets a sorted list based on proximity.
- Client tries the first mirror; if it fails, it moves to the next.
- Mirrorlist is load-balancing at the service level based on requester IP.

## Teams Involved

- **Userspace**: Creates OS code, utilities, and conversion scripts published to SWNG and `repo.cloudlinux.com`.
- **Buildsystem**: Builds and releases packages to SWNG and `repo.cloudlinux.com`.
- **REA&IT**: Provides tooling and maintains public repositories, mirrorservice, endpoints, and hosts (sync, SSL, load balancers, etc.).
- **Support Team**: Customer communication and diagnostics of issues on customer hosts.

## References

- Legacy mirror documentation: `https://cloudlinux.slite.com/api/s/PiwDcKDi3HyxF7/SWNG-mirrors`

## Operational Notes

- SWNG should be the default mirror target for production environments.
- `repo.cloudlinux.com` can be synced to enable autonomous installs/conversions.
- Full `repo.cloudlinux.com` is >3 TB; partial sync is recommended in most cases.

