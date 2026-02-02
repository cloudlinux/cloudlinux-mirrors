# Support Team Notes: Mirror System Changes

This document is for CloudLinux support teams and summarizes the changes customers will see as new package versions are released. Exact package versions will be added later.

## What is changing

- **New mirrorlist endpoint**: `cl-mirrors` replaces the legacy `cln-mirrors`.
- **Open HTTPS mirrors**: mirrors are accessible via standard HTTPS (no custom SSL or XMLRPC transport).
- **Partial mirrors supported**: customers can mirror only specific OS versions and still be served by the mirror service.
- **Autonomous installs/conversions**: customers can sync `repo.cloudlinux.com` content freely if they need isolated environments.

## Client-side update behavior

- The switch to the new mirrorlist endpoint happens automatically when:
  - `rhn-client-tools` is updated, and/or
  - `cloudlinux-release` is updated.
- No manual change is required on the client for the new endpoint once these package updates land.

## Legacy vs New Endpoints

- Old endpoint: `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cln-mirrors`
  - Required for older yum-rhn-plugin/XMLRPC flow.
  - Uses legacy mirror configuration and custom SSL.
- New endpoint: `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`
  - Used with standard `mirrorlist=` entries in `.repo` files.
  - Requires standard HTTPS mirrors (no custom SSL/XMLRPC).
- The two endpoints are **not interchangeable**.

## Package Versions

The exact package versions that trigger the transition will be added later:

- `rhn-client-tools`: **TBD**
- `cloudlinux-release`: **TBD**

## What to tell customers

- If they rely on the legacy mirror system, they should prepare to migrate to the new HTTPS mirror configuration.
- Newer OS/package versions will expect the new mirrorlist endpoint and open HTTPS mirrors.
- Partial mirrors are supported; they do **not** need to mirror all versions.

