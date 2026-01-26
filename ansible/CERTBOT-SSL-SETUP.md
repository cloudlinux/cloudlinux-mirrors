# Certbot and SSL Certificate Setup for CloudLinux Mirrors

This document describes how to add SSL certificate support using Certbot to the Ansible playbooks.

## Overview

All playbooks can be configured to automatically:
1. Install Certbot and python3-certbot-nginx
2. Obtain Let's Encrypt SSL certificates
3. Configure Nginx for HTTPS with automatic HTTP to HTTPS redirect
4. Set up automatic certificate renewal via cron

## Variables to Add

Add these variables to each playbook's `vars` section:

```yaml
vars:
  # ... existing variables ...
  
  # SSL/Certbot configuration
  mirror_domain: "{{ inventory_hostname }}"  # Domain name for the mirror
  certbot_email: "admin@{{ mirror_domain }}"  # Email for Let's Encrypt notifications
  certbot_authenticator: standalone  # Options: standalone, webroot
  certbot_webroot: "{{ mirror_base_path }}/acme"  # Only used with webroot authenticator
  certbot_enabled: true  # Set to false to disable SSL setup
  certbot_cron_enabled: true  # Enable automatic renewal
  certbot_cron_schedule:
    minute: 0
    hour: 3
```

## Tasks to Add

Add these tasks after the Nginx installation and before the final Nginx status check:

```yaml
- name: Install certbot packages
  package:
    name:
      - certbot
      - python3-certbot-nginx
    state: present
  when: certbot_enabled | bool

- name: Create webroot for ACME challenge (when using webroot)
  file:
    path: "{{ certbot_webroot }}"
    state: directory
    owner: root
    group: root
    mode: '0755'
  when: certbot_enabled | bool and certbot_authenticator == 'webroot'

- name: Stop nginx for standalone auth (if running)
  systemd:
    name: nginx
    state: stopped
  when: certbot_enabled | bool and certbot_authenticator == 'standalone'
  ignore_errors: true

- name: Obtain Let's Encrypt cert using standalone
  command: >
    certbot certonly --standalone --preferred-challenges http
    --non-interactive --agree-tos
    --email {{ certbot_email }}
    -d {{ mirror_domain }}
  args:
    creates: "/etc/letsencrypt/live/{{ mirror_domain }}/fullchain.pem"
  when: certbot_enabled | bool and certbot_authenticator == 'standalone'
  ignore_errors: true

- name: Obtain Let's Encrypt cert using webroot
  command: >
    certbot certonly --webroot
    --webroot-path {{ certbot_webroot }}
    --non-interactive --agree-tos
    --email {{ certbot_email }}
    -d {{ mirror_domain }}
  args:
    creates: "/etc/letsencrypt/live/{{ mirror_domain }}/fullchain.pem"
  when: certbot_enabled | bool and certbot_authenticator == 'webroot'
  ignore_errors: true

- name: Start nginx after standalone certbot
  systemd:
    name: nginx
    state: started
  when: certbot_enabled | bool and certbot_authenticator == 'standalone'

- name: Create Nginx HTTPS configuration
  template:
    src: nginx-https.conf.j2
    dest: /etc/nginx/conf.d/{{ service_name | default('mirror') }}-https.conf
    mode: '0644'
  notify: restart nginx
  when: certbot_enabled | bool

- name: Update HTTP Nginx configuration to redirect to HTTPS
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/conf.d/{{ service_name | default('mirror') }}.conf
    mode: '0644'
  notify: restart nginx
  when: certbot_enabled | bool

- name: Ensure certbot renew cron job exists
  cron:
    name: "Certbot renew"
    job: "certbot renew --quiet --deploy-hook 'systemctl reload nginx'"
    minute: "{{ certbot_cron_schedule.minute }}"
    hour: "{{ certbot_cron_schedule.hour }}"
  when: certbot_enabled | bool and certbot_cron_enabled | bool
```

## Nginx Configuration Updates

### HTTP Configuration (nginx.conf.j2)

Update to handle HTTPS redirect and ACME challenges:

```nginx
{% if certbot_enabled | default(false) %}
# HTTP to HTTPS redirect
server {
    listen 80;
    server_name {{ mirror_domain }};
    
    # ACME challenge location for Let's Encrypt
    location /.well-known/acme-challenge/ {
        root {{ certbot_webroot | default('/var/www/mirrors/acme') }};
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}
{% else %}
# Original HTTP-only configuration
server {
    listen 80;
    server_name _;
    # ... rest of configuration ...
}
{% endif %}
```

### HTTPS Configuration (nginx-https.conf.j2)

Create a new template file for HTTPS configuration:

```nginx
server {
    listen 443 ssl http2;
    server_name {{ mirror_domain }};
    root {{ mirror_path }};
    index index.html;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/{{ mirror_domain }}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/{{ mirror_domain }}/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Enable directory listing
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    # Logging
    access_log /var/log/nginx/mirror-https-access.log;
    error_log /var/log/nginx/mirror-https-error.log;

    # Repository locations
    location / {
        try_files $uri $uri/ =404;
    }

    # Allow large file downloads
    client_max_body_size 0;
}
```

## Authenticator Methods

### Standalone (Default)
- Stops Nginx temporarily during certificate issuance
- Simpler setup, no webroot configuration needed
- Use when: You can temporarily stop Nginx

### Webroot
- Nginx continues running during certificate issuance
- Requires webroot directory to be accessible
- Use when: Nginx must remain running

## Usage

### Enable SSL (Default)
```bash
ansible-playbook -i inventory.ini playbook.yml
```

### Disable SSL
```bash
ansible-playbook -i inventory.ini playbook.yml -e "certbot_enabled=false"
```

### Custom Domain
```bash
ansible-playbook -i inventory.ini playbook.yml -e "mirror_domain=mirror.example.com"
```

### Use Webroot Authenticator
```bash
ansible-playbook -i inventory.ini playbook.yml -e "certbot_authenticator=webroot"
```

## Certificate Renewal

Certificates are automatically renewed via cron job (default: daily at 3:00 AM). The renewal hook reloads Nginx to use the new certificates.

## Files Created

- `/etc/letsencrypt/live/<domain>/fullchain.pem` - SSL certificate
- `/etc/letsencrypt/live/<domain>/privkey.pem` - Private key
- `/etc/nginx/conf.d/<service>-https.conf` - HTTPS configuration
- Cron job for automatic renewal
