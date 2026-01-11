FROM node:18-alpine

# Install Bitwarden CLI dependencies
RUN apk add --no-cache curl bash

# Install Bitwarden CLI
RUN curl -L "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o bw-linux.zip && \
    unzip bw-linux.zip && \
    chmod +x bw && \
    mv bw /usr/local/bin/ && \
    rm bw-linux.zip

# Install etcdctl for debugging (optional)
RUN apk add --no-cache etcd-ctl

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install Node.js dependencies
RUN npm ci --only=production

# Copy application code
COPY . .

# Create a startup script
RUN echo '#!/bin/bash\n\
echo "🚀 Starting Bitwarden Prometheus Scanner..."\n\
echo "⏳ Waiting for Bitwarden to be ready..."\n\
sleep 30\n\
exec node scanner.js' > /app/start.sh && \
    chmod +x /app/start.sh

# Run the scanner
CMD ["/app/start.sh"]