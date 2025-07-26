#!/bin/bash

# n8n AWS Deployment Script
# This script sets up n8n on AWS EC2 with Nginx and SSL

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=${1:-"your-domain.com"}
EMAIL=${2:-"admin@your-domain.com"}

echo -e "${GREEN}🚀 Starting n8n AWS deployment...${NC}"

# Update system
echo -e "${YELLOW}📦 Updating system packages...${NC}"
sudo apt update && sudo apt upgrade -y

# Install Docker and Docker Compose
echo -e "${YELLOW}🐳 Installing Docker and Docker Compose...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Install Certbot for SSL certificates
echo -e "${YELLOW}🔒 Installing Certbot for SSL certificates...${NC}"
sudo apt install -y certbot python3-certbot-nginx

# Create SSL directory
echo -e "${YELLOW}📁 Creating SSL directory...${NC}"
sudo mkdir -p /etc/nginx/ssl

# Generate self-signed certificate (temporary)
echo -e "${YELLOW}🔐 Generating temporary SSL certificate...${NC}"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Create environment file
echo -e "${YELLOW}⚙️ Creating environment configuration...${NC}"
if [ ! -f .env ]; then
    cp env.example .env
    echo -e "${GREEN}✅ Environment file created. Please edit .env with your configuration.${NC}"
fi

# Update nginx configuration with domain
echo -e "${YELLOW}🔧 Updating Nginx configuration...${NC}"
sed -i "s/your-domain.com/$DOMAIN/g" nginx.conf

# Start services
echo -e "${YELLOW}🚀 Starting n8n services...${NC}"
docker-compose -f docker-compose.aws.yml up -d

# Wait for services to start
echo -e "${YELLOW}⏳ Waiting for services to start...${NC}"
sleep 30

# Check if services are running
echo -e "${YELLOW}🔍 Checking service status...${NC}"
if docker-compose -f docker-compose.aws.yml ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Services are running successfully!${NC}"
else
    echo -e "${RED}❌ Some services failed to start. Check logs with: docker-compose -f docker-compose.aws.yml logs${NC}"
    exit 1
fi

# Get SSL certificate (if domain is configured)
if [ "$DOMAIN" != "your-domain.com" ]; then
    echo -e "${YELLOW}🔒 Obtaining SSL certificate from Let's Encrypt...${NC}"
    sudo certbot --nginx -d $DOMAIN --email $EMAIL --agree-tos --non-interactive
    
    # Update nginx configuration to use Let's Encrypt certificates
    sudo sed -i "s|ssl_certificate /etc/nginx/ssl/cert.pem;|ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;|g" nginx.conf
    sudo sed -i "s|ssl_certificate_key /etc/nginx/ssl/key.pem;|ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;|g" nginx.conf
    
    # Restart nginx
    docker-compose -f docker-compose.aws.yml restart nginx
fi

# Setup automatic SSL renewal
echo -e "${YELLOW}🔄 Setting up automatic SSL renewal...${NC}"
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# Setup log rotation
echo -e "${YELLOW}📋 Setting up log rotation...${NC}"
sudo tee /etc/logrotate.d/n8n << EOF
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

# Display final information
echo -e "${GREEN}🎉 n8n deployment completed successfully!${NC}"
echo -e "${GREEN}📊 Access your n8n instance at: https://$DOMAIN${NC}"
echo -e "${YELLOW}📝 Don't forget to:${NC}"
echo -e "   1. Edit .env file with your configuration"
echo -e "   2. Set up your domain DNS to point to this server"
echo -e "   3. Configure your firewall to allow ports 80 and 443"
echo -e "   4. Set up monitoring and backups"

# Display useful commands
echo -e "${YELLOW}🔧 Useful commands:${NC}"
echo -e "   View logs: docker-compose -f docker-compose.aws.yml logs -f"
echo -e "   Stop services: docker-compose -f docker-compose.aws.yml down"
echo -e "   Restart services: docker-compose -f docker-compose.aws.yml restart"
echo -e "   Update n8n: git pull && docker-compose -f docker-compose.aws.yml up -d --build" 