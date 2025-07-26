# n8n AWS Deployment with Nginx

This guide provides complete instructions for deploying n8n on AWS EC2 with Nginx reverse proxy, SSL certificates, and PostgreSQL database.

## 🏗️ Architecture

```
Internet → Nginx (SSL/TLS) → n8n → PostgreSQL (RDS)
```

## 📋 Prerequisites

- AWS account with appropriate permissions
- Domain name (optional but recommended)
- SSH key pair for EC2 access
- Terraform installed (for infrastructure as code)

## 🚀 Quick Start

### Option 1: Automated Deployment with Terraform (Recommended)

1. **Clone and configure the repository**:
   ```bash
   git clone <your-repo-url>
   cd n8n-docker-onrender/terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit configuration**:
   ```bash
   nano terraform.tfvars
   ```
   Update with your specific values:
   - Domain name
   - AWS key pair name
   - Database password
   - Route53 zone ID (if using custom domain)

3. **Deploy infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure n8n**:
   ```bash
   # SSH to your EC2 instance
   ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
   
   # Navigate to n8n directory
   cd /opt/n8n
   
   # Copy and edit environment file
   cp env.example .env
   nano .env
   ```

5. **Start services**:
   ```bash
   sudo systemctl start n8n
   sudo systemctl status n8n
   ```

### Option 2: Manual EC2 Setup

1. **Launch EC2 instance**:
   - Use Ubuntu 22.04 LTS
   - Instance type: t3.medium or larger
   - Security groups: Allow ports 22, 80, 443

2. **Run deployment script**:
   ```bash
   # Upload files to EC2
   scp -r . ubuntu@<EC2_IP>:/opt/n8n/
   
   # SSH to EC2 and run deployment
   ssh ubuntu@<EC2_IP>
   cd /opt/n8n
   chmod +x aws-deploy.sh
   ./aws-deploy.sh your-domain.com admin@your-domain.com
   ```

## 🔧 Configuration

### Environment Variables

Update the `.env` file with your configuration:

```bash
# Required
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your-secure-password
N8N_ENCRYPTION_KEY=your-32-character-random-string
N8N_HOST=your-domain.com

# Database (from Terraform output)
DB_POSTGRESDB_HOST=your-rds-endpoint.amazonaws.com
DB_POSTGRESDB_PASSWORD=your-db-password

# Optional SMTP
N8N_SMTP_USER=your-email@gmail.com
N8N_SMTP_PASS=your-app-password
```

### Nginx Configuration

The `nginx.conf` file includes:
- SSL/TLS termination
- Rate limiting
- Security headers
- WebSocket support
- Static file caching
- Health checks

### SSL Certificates

SSL certificates are automatically managed:
- **Self-signed**: Generated during deployment
- **Let's Encrypt**: Automatically obtained if domain is configured
- **Auto-renewal**: Configured via cron job

## 📊 Monitoring and Maintenance

### Health Checks

```bash
# Check service status
sudo systemctl status n8n

# View logs
docker-compose -f docker-compose.aws.yml logs -f

# Health check endpoint
curl https://your-domain.com/healthz
```

### Backup Strategy

1. **Database backups**:
   - RDS automated backups (enabled by default)
   - Manual snapshots for point-in-time recovery

2. **Application data**:
   ```bash
   # Backup n8n data
   docker run --rm -v n8n_data:/data -v $(pwd):/backup alpine tar czf /backup/n8n-backup-$(date +%Y%m%d).tar.gz -C /data .
   ```

### Updates

```bash
# Update n8n
cd /opt/n8n
git pull
docker-compose -f docker-compose.aws.yml down
docker-compose -f docker-compose.aws.yml up -d --build

# Update infrastructure
cd terraform
terraform plan
terraform apply
```

## 🔒 Security Considerations

### Network Security
- Use VPC with private subnets for database
- Restrict SSH access to your IP
- Enable VPC Flow Logs for monitoring

### Application Security
- Strong passwords for n8n and database
- Regular security updates
- SSL/TLS encryption
- Rate limiting on API endpoints

### Data Protection
- Encrypted storage volumes
- Database encryption at rest
- Regular backups
- Access logging

## 🚨 Troubleshooting

### Common Issues

1. **SSL Certificate Issues**:
   ```bash
   # Check certificate status
   sudo certbot certificates
   
   # Renew manually
   sudo certbot renew
   ```

2. **Database Connection**:
   ```bash
   # Test database connectivity
   docker exec -it n8n-postgres psql -U n8n -d n8n
   ```

3. **Service Not Starting**:
   ```bash
   # Check Docker logs
   docker-compose -f docker-compose.aws.yml logs
   
   # Check system logs
   sudo journalctl -u n8n -f
   ```

4. **High Resource Usage**:
   ```bash
   # Monitor resources
   docker stats
   htop
   ```

### Performance Optimization

1. **Database Optimization**:
   - Use RDS instance with sufficient resources
   - Enable connection pooling
   - Regular maintenance windows

2. **Application Optimization**:
   - Monitor memory usage
   - Adjust worker processes
   - Use CDN for static assets

## 💰 Cost Optimization

### AWS Resources
- **EC2**: Use Spot instances for non-critical workloads
- **RDS**: Use reserved instances for predictable workloads
- **Storage**: Use S3 for backups and static assets

### Monitoring Costs
- Set up CloudWatch alarms
- Use AWS Cost Explorer
- Implement auto-scaling policies

## 📚 Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)

## 🤝 Support

For issues specific to this deployment:
1. Check the troubleshooting section
2. Review logs and error messages
3. Create an issue in the repository
4. Consult AWS and n8n documentation 