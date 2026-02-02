# FAQ and How-To: Creating a CloudLinux Mirror

This document is intended for customers and support teams. It provides a short how-to for setting up a mirror and a checklist of required information to provide to support.

## How to Create a Mirror (SWNG)

1. **Prepare storage**
   - Use a dedicated disk or partition.
   - Plan for ~500 GB for SWNG.

2. **Sync SWNG**
   - Use rsync:
     - `rsync://rsync.upstream.cloudlinux.com/SWNG/`

3. **Expose via HTTPS**
   - Configure Nginx (or another web server).
   - Enable directory browsing.
   - Ensure HTTPS works with a valid certificate.

4. **Validate the public index**
   - Ensure the index matches the upstream structure.
   - Mixed setups can use `<domain>/swng/`.

## Optional: Sync `repo.cloudlinux.com`

Use this only if you need a fully autonomous install/conversion environment:

- Full sync is **3+ TB**.
- In most cases, sync only the required sub-repositories.

## Information to Provide to CloudLinux Support

- Mirror URL (HTTPS)
  - Example: `https://mirror.example.com/swng/`
- Whether the mirror is **public** or **private**
- For private mirrors: list of IPs or networks
- Geographic location
- Available bandwidth/capacity
- Sync method and frequency
- Whether the mirror is **complete** or **partial**
- If partial, list the versions mirrored (`swng_options`)


