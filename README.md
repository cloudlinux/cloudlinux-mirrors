# How to Use upstream.cloudlinux.com for Repository Mirroring

## Introduction

`upstream.cloudlinux.com` is CloudLinux's dedicated repository mirroring service that provides unrestricted access to CloudLinux and SWNG repositories. This service is designed for organizations that need to create and maintain local mirrors of CloudLinux repositories.

## What is upstream.cloudlinux.com?

`upstream.cloudlinux.com` is a special repository servuce that provides:

- **Unrestricted Access:** No authentication required for downloading repository content
- **Multiple Access Methods:** Both HTTP/HTTPS and RSync protocols
- **Complete Repository Content:** Full access to CloudLinux and SWNG repositories
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
- `https://upstream.cloudlinux.com/` - Root (CloudLinux repositories)
- `https://upstream.cloudlinux.com/cloudlinux/` - CloudLinux repository content
- `https://upstream.cloudlinux.com/swng/` - SWNG repository content

**Examples:**

```bash
# Browse CloudLinux 8 repositories
curl https://upstream.cloudlinux.com/cloudlinux/8/

# Browse CloudLinux 9 BaseOS repository
curl https://upstream.cloudlinux.com/cloudlinux/9/BaseOS/x86_64/os/

# Download a specific package
wget https://upstream.cloudlinux.com/cloudlinux/8/x86_64/updates/Packages/c/cloudlinux-release-8.0-1.el8.cl.x86_64.rpm

# List available CloudLinux versions
curl https://upstream.cloudlinux.com/cloudlinux/
```

### Method 2: RSync (Recommended for Mirroring)

Use this method for:
- Creating complete local mirrors
- Incremental updates (only changed files)
- Bandwidth-efficient synchronization
- Automated mirroring scripts

**RSync Endpoint:** `rsync://rsync.upstream.cloudlinux.com/`

**RSync Modules:**
- `CLOUDLINUX` - CloudLinux repository content
- `SWNG` - SWNG repository content

**Basic RSync Command:**

```bash
# Sync CloudLinux repository
rsync -av --delete rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ /path/to/local/mirror/cloudlinux/

# Sync SWNG repository
rsync -av --delete rsync://rsync.upstream.cloudlinux.com/SWNG/ /path/to/local/mirror/swng/
```

**Command Options Explained:**
- `-a` - Archive mode (preserves permissions, timestamps, etc.)
- `-v` - Verbose output
- `--delete` - Delete files in destination that don't exist in source
- `rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/` - Source module
- `/path/to/local/mirror/cloudlinux/` - Destination directory

## Creating a Local Mirror

### Step 1: Prepare Storage

Ensure you have sufficient disk space. CloudLinux repositories can require several hundred gigabytes.

```bash
# Check available space
df -h

# Create mirror directory
mkdir -p /var/www/mirrors/cloudlinux
```

### Step 2: Initial Sync

Perform the initial synchronization (this may take several hours depending on your connection):

```bash
# Sync CloudLinux repository
rsync -av --delete \
  --progress \
  --log-file=/var/log/cloudlinux-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/CLOUDLINUX/ \
  /var/www/mirrors/cloudlinux/

# Sync SWNG repository (if needed)
rsync -av --delete \
  --progress \
  --log-file=/var/log/swng-mirror.log \
  rsync://rsync.upstream.cloudlinux.com/SWNG/ \
  /var/www/mirrors/swng/
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

SWNG (Software Network Group) repositories contain additional software packages for CloudLinux. This section provides comprehensive examples for creating local mirrors of SWNG repositories.

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
name=CloudLinux 9 SWNG x86_64
baseurl=https://upstream.cloudlinux.com/swng/9/x86_64/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

**Example: CloudLinux 8 SWNG x86_64**

```ini
[SWNG-8-x86_64]
name=CloudLinux 8 SWNG x86_64
baseurl=https://upstream.cloudlinux.com/swng/8/x86_64/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-cloudlinux
```

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

After creating your local mirror, you need to contact the CloudLinux support team to have your mirror added to the public or private mirror rotation system. This ensures that CloudLinux customer machines will automatically use your mirror.

### Important Steps After Mirror Creation

1. **Verify Your Mirror is Accessible**
   - Ensure your mirror is publicly accessible via HTTP/HTTPS
   - Test that repository metadata is properly generated
   - Verify GPG keys are accessible

2. **Contact CloudLinux Support**
   - **Email:** Contact CloudLinux support team
   - **Information to Provide:**
     - Mirror URL (e.g., `https://mirror.yourdomain.com/cloudlinux/`)
     - Geographic location of the mirror
     - Available bandwidth/capacity
     - Whether it's for public or private rotation
     - For private rotation: specific subnets or IP ranges that should use this mirror

3. **Public Mirror Rotation**
   - Your mirror will be added to the global mirror rotation
   - CloudLinux systems will automatically select the best mirror based on geographic location and performance
   - All CloudLinux customers can potentially use your mirror

4. **Private Mirror Rotation (Subnet-based)**
   - Your mirror will be configured for specific subnets or IP ranges
   - Only machines from those subnets will use your mirror
   - Useful for enterprise customers with dedicated infrastructure
   - Requires providing subnet information to CloudLinux support

5. **Mirror Requirements**
   - Mirror must be accessible 24/7
   - Must maintain synchronization (use timers as shown in examples above)
   - Must serve valid repository metadata
   - Must have sufficient bandwidth for expected load
   - Must follow CloudLinux mirroring best practices

### Example: Mirror Information to Provide to Support

```
Mirror Details:
- URL: https://mirror.example.com/cloudlinux/
- SWNG URL: https://mirror.example.com/swng/
- Location: US East (Virginia)
- Bandwidth: 10 Gbps
- Type: Public rotation
- Sync Frequency: Every 4 hours via systemd timer
- Storage: 2 TB available
```

Or for private rotation:

```
Mirror Details:
- URL: https://mirror.example.com/cloudlinux/
- SWNG URL: https://mirror.example.com/swng/
- Location: US East (Virginia)
- Type: Private rotation
- Subnets: 192.168.0.0/16, 10.0.0.0/8
- Sync Frequency: Every 4 hours via systemd timer
```

### Verification After Mirror is Added

Once your mirror is added to rotation, you can verify it's being used:

```bash
# Check which mirror is being used
yum repoinfo

# Test repository access
yum makecache

# Monitor mirror access logs (if configured)
tail -f /var/log/httpd/access_log
# or
tail -f /var/log/nginx/access.log
```

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
- **RSync Endpoint:** rsync://rsync.upstream.cloudlinux.com/
- **RSync Modules:** `CLOUDLINUX`, `SWNG`
- **Documentation:** Check CloudLinux documentation for repository configuration
- **Support:** Contact CloudLinux support for assistance with mirroring

## Summary

`upstream.cloudlinux.com` provides a reliable, efficient way to create and maintain local mirrors of CloudLinux repositories. Whether you use HTTP/HTTPS for occasional downloads or RSync for complete mirroring, this service ensures you have the content you need when you need it.

Key advantages:
- ✅ No authentication required
- ✅ Multiple access methods (HTTP/HTTPS, RSync)
- ✅ Efficient incremental updates
- ✅ Complete repository content
- ✅ Reliable and maintained by CloudLinux
