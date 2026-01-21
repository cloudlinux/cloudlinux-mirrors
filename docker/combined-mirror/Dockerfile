FROM cloudlinux:8

# Install required packages
RUN yum install -y rsync cronie && \
    yum clean all

# Create mirror directories
RUN mkdir -p /var/www/mirrors/cloudlinux && \
    mkdir -p /var/www/mirrors/swng && \
    chmod 755 /var/www/mirrors/cloudlinux && \
    chmod 755 /var/www/mirrors/swng

# Create sync scripts
COPY sync-cloudlinux.sh /usr/local/bin/sync-cloudlinux.sh
COPY sync-swng.sh /usr/local/bin/sync-swng.sh
COPY sync-combined.sh /usr/local/bin/sync-combined.sh
RUN chmod +x /usr/local/bin/sync-*.sh

# Create log directory
RUN mkdir -p /var/log && \
    touch /var/log/cloudlinux-mirror.log && \
    touch /var/log/swng-mirror.log && \
    touch /var/log/combined-mirror.log

# Set up cron job based on SYNC_MODE
# Default to combined mode (runs every 4 hours)
RUN echo "0 */4 * * * /usr/local/bin/sync-combined.sh >> /var/log/combined-mirror.log 2>&1" | crontab -

# Create entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Volumes for mirror data
VOLUME ["/var/www/mirrors/cloudlinux", "/var/www/mirrors/swng"]

# Volume for logs
VOLUME ["/var/log"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["crond", "-f", "-d", "8"]
