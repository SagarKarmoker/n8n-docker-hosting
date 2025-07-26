#!/bin/bash

# User data script for n8n EC2 instance
# This script runs when the EC2 instance starts

set -e

# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    git

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Certbot
apt install -y certbot python3-certbot-nginx

# Create application directory
mkdir -p /opt/n8n
cd /opt/n8n

# Clone the repository (you'll need to replace with your actual repo URL)
# git clone https://github.com/yourusername/n8n-docker-onrender.git .

# Create SSL directory
mkdir -p /etc/nginx/ssl

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=${domain}"

# Set proper permissions
chown -R ubuntu:ubuntu /opt/n8n
chmod 600 /etc/nginx/ssl/*.pem

# Create systemd service for n8n
cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/n8n
ExecStart=/usr/local/bin/docker-compose -f docker-compose.aws.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.aws.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl enable n8n.service

# Setup log rotation
cat > /etc/logrotate.d/n8n << EOF
/var/lib/docker/volumes/*/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

# Setup automatic SSL renewal
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# Create a simple health check script
cat > /opt/n8n/health_check.sh << 'EOF'
#!/bin/bash
if curl -f http://localhost/healthz > /dev/null 2>&1; then
    echo "n8n is healthy"
    exit 0
else
    echo "n8n is not responding"
    exit 1
fi
EOF

chmod +x /opt/n8n/health_check.sh

# Create environment file template
cat > /opt/n8n/env.example << 'EOF'
# n8n Basic Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-secure-password

# n8n Host Configuration
N8N_HOST=${domain}
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://${domain}
GENERIC_TIMEZONE=UTC

# Database Configuration (PostgreSQL)
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=your-rds-endpoint.amazonaws.com
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n
DB_POSTGRESDB_PASSWORD=your-db-password

# n8n Security
N8N_ENCRYPTION_KEY=your-32-character-encryption-key
N8N_USER_MANAGEMENT_DISABLED=false

# Email Configuration (SMTP)
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=your-email@gmail.com
N8N_SMTP_PASS=your-app-password
N8N_SMTP_SENDER=your-email@gmail.com
N8N_SMTP_REPLY_TO=your-email@gmail.com
N8N_SMTP_SECURE=true

# n8n Settings
N8N_LOG_LEVEL=info
N8N_DIAGNOSTICS_ENABLED=false
N8N_PAYLOAD_SIZE_MAX=16
N8N_EDITOR_BASE_URL=https://${domain}
EOF

# Set ownership
chown -R ubuntu:ubuntu /opt/n8n

# Reboot to ensure all changes take effect
reboot 