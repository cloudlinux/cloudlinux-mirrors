# Internal System Overview (REA&IT)

This document is for internal use by REA&IT and related teams. It summarizes the current CloudLinux mirroring system, the transition from legacy mirrors, and the internal services used to manage mirrorlists.

## System Summary

- **SWNG** is the main operational repository used for regular updates.
- **repo.cloudlinux.com** contains conversion and installation assets and legacy content.
- The **new mirror service** provides mirrorlists for standard HTTPS mirrors and supports **partial mirrors** (mirrors that contain only some OS versions).
- The **legacy mirrorlist** exists for older systems that still use the yum-rhn-plugin/XMLRPC flow.
- The migration is gradual; clients move to the new mirrorlist endpoint automatically via package updates.

## Internal Services

### Mirror Service (cl-mirrors)

- Repository: `https://reait.gitlab.atm.svcs.io/rea-it/cl-mirrors`
- Purpose: generate mirrorlists based on GeoIP/ASN proximity and mirror availability.
- Output: a prioritized list of mirrors appropriate for the requester.
- Supports both **public** and **private** mirrors.
- Supports **partial mirrors** with version-scoped visibility.

### Deployment Playbook for CloudLinux-Owned Mirrors

- Playbook: `https://reait.gitlab.atm.svcs.io/repositories/repo-inventory/-/blob/main/playbooks/non_xmlrpc_mirrors.yaml`
- Purpose: deploy and manage CloudLinux-owned mirrors with standard HTTPS access.

## Key Changes vs Legacy Mirrors

- Mirrors are **publicly accessible** over standard HTTPS.
- No custom SSL certificates or XMLRPC endpoints are required.
- Mirrorlist endpoint is `cl-mirrors` (legacy: `cln-mirrors`).
- Partial mirrors are supported by the mirror service.

## Operational Notes

- SWNG should be the default mirror target for production environments.
- `repo.cloudlinux.com` can be synced to enable autonomous installs/conversions.
- Full `repo.cloudlinux.com` is >3 TB; partial sync is recommended in most cases.

