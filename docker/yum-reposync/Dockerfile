FROM almalinux:8

# Install required packages
RUN yum install -y yum-utils createrepo cronie && \
    yum clean all

# Create mirror directory
RUN mkdir -p /var/www/mirrors/swng && \
    chmod 755 /var/www/mirrors/swng

# Create sync script
COPY sync-script.sh /usr/local/bin/sync-script.sh
RUN chmod +x /usr/local/bin/sync-script.sh

# Create repository configuration template
COPY swng-upstream.repo /etc/yum.repos.d/swng-upstream.repo

# Import CloudLinux GPG key
RUN rpm --import https://repo.cloudlinux.com/cloudlinux/RPM-GPG-KEY-cloudlinux || true

# Create log directory
RUN mkdir -p /var/log && \
    touch /var/log/swng-reposync.log

# Set up cron job (runs every 6 hours by default)
RUN echo "0 */6 * * * /usr/local/bin/sync-script.sh >> /var/log/swng-reposync.log 2>&1" | crontab -

# Create entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Volume for mirror data
VOLUME ["/var/www/mirrors/swng"]

# Volume for logs
VOLUME ["/var/log"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["crond", "-n", "-s"]
