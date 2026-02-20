# Support Team Notes: Mirror System Changes

This document is for CloudLinux support teams. It explains **why** the mirror system is changing, **what** the customer impact is, and provides a **support-ready checklist** for answering common questions and troubleshooting.

Related docs:
- Customer-facing guide: `docs/upstream.cloudlinux.com-customer-guide.md`
- Internal architecture: `docs/CL-mirrors-nonxmlrpc.md`

## What is changing

- **New mirrorlist endpoint**: `cl-mirrors` replaces the legacy `cln-mirrors`.
- **Open HTTPS mirrors**: mirrors are accessible via standard HTTPS (no custom SSL or XMLRPC transport).
- **Partial mirrors supported**: customers can mirror only specific OS versions and still be served by the mirror service.
- **Autonomous installs/conversions**: customers can sync `repo.cloudlinux.com` content freely if they need isolated environments.

## Why we are switching (customer-friendly)

Key message to customers:
- License validation is performed **inside CloudLinux OS**, so repositories and mirrors do not need mirror-side authentication.
- The legacy system relied on **custom SSL + XMLRPC transport**, which is operationally heavy and harder for customers to manage.
- The new approach uses **standard HTTPS** and standard `dnf/yum` mechanics (mirrorlists + fallback), which is simpler, more reliable, and easier to troubleshoot.

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

## Quick answers (FAQ)

### “Do we need to do anything on the servers?”

- **Most customers**: no manual change on the client, it transitions via package updates (see above).
- **Customers with their own mirrors**: yes, they must provide an **open HTTPS mirror** compatible with the new flow and ask Support to add it to mirror rotation (public or private scoped).

### “Can we keep using the old mirror?”

- Older systems/tools may continue to use `cln-mirrors`.
- Newer CloudLinux versions/tooling will use `cl-mirrors`. If a customer mirror only supports the legacy flow, updated clients may stop using it.

### “Why can’t we use the same domain for both old and new mirror?”

- The legacy setup typically requires a **custom SSL certificate** bound to the customer domain for the XMLRPC flow.
- The new setup requires a normal **public CA certificate** for standard HTTPS.
- These TLS expectations conflict for a single endpoint, so customers should treat legacy and new mirrors as separate endpoints.

### “Do we need to mirror everything?”

- No. **Partial mirrors are supported**. Customers can mirror only the OS versions they need and provide the list/scope to Support.

## Troubleshooting: identify which flow the customer is on

Ask the customer to run the following checks and paste the output.

```bash
# New flow: cl-mirrors appears in dnf/yum repo configs
grep -R "mirrorlists/cl-mirrors" /etc/yum.repos.d/ 2>/dev/null || true

# Legacy flow: mirrorURL in up2date config (XMLRPC legacy)
grep -R "^mirrorURL=" /etc/sysconfig/rhn/up2date 2>/dev/null || true

# Confirm mirrorlist endpoints are reachable
curl -sS "https://repo.cloudlinux.com/cloudlinux/mirrorlists/cl-mirrors" | head -n 20
curl -sS "https://repo.cloudlinux.com/cloudlinux/mirrorlists/cln-mirrors" | head -n 20
```

Common interpretation:
- If the customer only sees `cln-mirrors` / `mirrorURL=...`, they are on the **legacy** flow.
- If `.repo` contains `mirrorlist=...cl-mirrors`, they are on the **new** flow.

## What to collect from customers (mirror onboarding / issues)

If the customer wants their mirror added (or says it is not being used), collect:
- Mirror URL (HTTPS), e.g. `https://mirror.example.com/swng/` (and optionally `/cloudlinux/`)
- Public or private mirror
  - If private: the customer’s **egress IPs / CIDRs** that should receive the mirror
- Geo location (country/city)
- Full vs partial
  - If partial: which versions/paths are mirrored (they may provide this as `swng_options`)
- Confirmation the mirror serves repository metadata over HTTPS (example URL if they have one)

## Package Versions (transition triggers)

The exact package versions that trigger the transition will be added later:

- `rhn-client-tools`: **TBD**
- `cloudlinux-release`: **TBD**

## What to tell customers

- If they rely on the legacy mirror system, they should prepare to migrate to the new HTTPS mirror configuration.
- Newer OS/package versions will expect the new mirrorlist endpoint and open HTTPS mirrors.
- Partial mirrors are supported; they do **not** need to mirror all versions.

## When to escalate to REA&IT

Escalate with collected outputs if:
- There is a suspected mirrorservice outage or widespread mirrorlist anomalies.

