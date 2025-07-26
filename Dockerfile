FROM node:18-alpine

# Install dependencies
RUN apk add --update --no-cache \
    graphicsmagick \
    tzdata \
    su-exec \
    && rm -rf /var/cache/apk/*

# Create n8n user
RUN addgroup -g 1000 n8n && \
    adduser -D -s /bin/sh -u 1000 -G n8n n8n

# Set working directory
WORKDIR /home/node

# Install n8n globally
RUN npm install -g n8n

# Create n8n directory
RUN mkdir -p /home/node/.n8n && \
    chown -R n8n:n8n /home/node/.n8n

# Switch to n8n user
USER n8n

# Expose port
EXPOSE 5678

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:5678/healthz', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start n8n
CMD ["n8n", "start"] 