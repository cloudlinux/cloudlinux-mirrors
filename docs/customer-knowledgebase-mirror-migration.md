# Knowledgebase: Mirror Migration for New CloudLinux Versions

This article is for customers and explains why the old mirror system will not support newer CloudLinux OS/package versions, and how to migrate to the new mirror configuration.

## Summary

New CloudLinux versions are moving to the new mirror service and open HTTPS mirrors. The legacy mirror system (custom SSL/XMLRPC) will not support newer OS and package versions. Customers should reconfigure their mirrors to the new standard HTTPS layout and endpoint.

## What is changing

- Legacy mirrors used custom SSL and XMLRPC transport.
- New mirrors use standard HTTPS and normal directory browsing.
- The mirrorlist endpoint is now `cl-mirrors` (not `cln-mirrors`).
- The new system supports partial mirrors (only the OS versions you need).

## Why the old system will not work for newer versions

- Newer CloudLinux packages and tooling use the new mirrorlist endpoint.
- The legacy XMLRPC/custom SSL flow is being phased out.
- Mirrors that only support the old endpoint will not be selected by updated clients.

## What you need to do

1. **Set up a new HTTPS mirror** that exposes SWNG content via standard HTTPS.
2. **Use the new mirrorlist endpoint**:
   - `https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors`
3. **Optionally mirror only the versions you need** (partial mirrors are supported).
4. **Provide your mirror URL and scope** to CloudLinux support so it can be added to mirror rotation.

## Notes

- SWNG is the main operational repository for updates.
- `repo.cloudlinux.com` contains conversion and install assets.
- Full `repo.cloudlinux.com` is large (>3 TB), so partial sync is recommended unless you need a fully autonomous environment.

