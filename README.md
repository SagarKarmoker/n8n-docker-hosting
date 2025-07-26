# n8n Docker Deployment on Render.com

This project provides a complete setup for deploying n8n (workflow automation tool) on Render.com with a PostgreSQL database.

## 🚀 Features

- **Docker-based deployment** for easy setup and maintenance
- **PostgreSQL database** for persistent data storage
- **Basic authentication** for security
- **SMTP email configuration** for notifications
- **Health checks** for monitoring
- **Environment-based configuration**

## 📋 Prerequisites

- A Render.com account
- Git repository to host this code
- SMTP credentials (optional, for email notifications)

## 🛠️ Setup Instructions

### 1. Fork/Clone this Repository

```bash
git clone <your-repo-url>
cd n8n-docker-onrender
```

### 2. Deploy to Render.com

#### Option A: Using Render Blueprint (Recommended)

1. **Connect your repository** to Render.com
2. **Create a new Blueprint Instance**
3. **Select this repository**
4. **Render will automatically**:
   - Create a PostgreSQL database
   - Deploy the n8n web service
   - Configure all environment variables

#### Option B: Manual Deployment

1. **Create a PostgreSQL database** on Render.com
2. **Create a new Web Service**:
   - Connect your repository
   - Set environment to `Docker`
   - Set build command: `docker build -t n8n .`
   - Set start command: `docker run -p 5678:5678 n8n`

### 3. Configure Environment Variables

Update the following variables in your Render.com dashboard:

#### Required Variables:
- `N8N_BASIC_AUTH_USER`: Your admin username
- `N8N_BASIC_AUTH_PASSWORD`: Your admin password
- `N8N_ENCRYPTION_KEY`: A 32-character random string
- `N8N_HOST`: Your app URL (e.g., `your-app.onrender.com`)

#### Database Variables (Auto-configured if using Blueprint):
- `DB_POSTGRESDB_HOST`: Database host
- `DB_POSTGRESDB_PORT`: Database port (usually 5432)
- `DB_POSTGRESDB_DATABASE`: Database name
- `DB_POSTGRESDB_USER`: Database username
- `DB_POSTGRESDB_PASSWORD`: Database password

#### Optional SMTP Variables:
- `N8N_SMTP_HOST`: SMTP server (e.g., `smtp.gmail.com`)
- `N8N_SMTP_PORT`: SMTP port (usually 587)
- `N8N_SMTP_USER`: Your email address
- `N8N_SMTP_PASS`: Your email app password

### 4. Local Development

To run locally with Docker Compose:

```bash
# Copy environment file
cp env.example .env

# Edit .env with your values
nano .env

# Start services
docker-compose up -d

# Access n8n at http://localhost:5678
```

## 🔧 Configuration

### Environment Variables

See `env.example` for all available configuration options.

### Database

The setup uses PostgreSQL 15 with the following default configuration:
- Database name: `n8n`
- Username: `n8n`
- Schema: `public`

### Security

- Basic authentication is enabled by default
- Encryption key is required for secure data storage
- HTTPS is enforced in production

## 📊 Monitoring

### Health Checks

The application includes health checks at `/healthz` endpoint.

### Logs

Access logs through Render.com dashboard or using:

```bash
# Local development
docker-compose logs -f n8n

# Render.com
# Use the dashboard or Render CLI
```

## 🔄 Updates

To update n8n:

1. **Update the Dockerfile** with a new n8n version
2. **Redeploy** on Render.com
3. **Database migrations** are handled automatically

## 🚨 Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check database credentials in environment variables
   - Ensure database is running and accessible

2. **Authentication Issues**
   - Verify `N8N_BASIC_AUTH_USER` and `N8N_BASIC_AUTH_PASSWORD`
   - Check if basic auth is enabled

3. **Email Not Working**
   - Verify SMTP credentials
   - Check if your email provider allows app passwords

4. **Webhook Issues**
   - Ensure `WEBHOOK_URL` is set correctly
   - Check if your app URL is accessible

### Support

- Check n8n documentation: https://docs.n8n.io/
- Render.com documentation: https://render.com/docs
- Create an issue in this repository

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 