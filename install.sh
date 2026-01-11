#!/bin/bash

# Swayn Monitoring Setup Script
# This script sets up the directory structure and basic configuration files
# for the monitoring stack (Prometheus, Grafana, Alert Manager, Nginx)

set -e

echo "🚀 Setting up Swayn Monitoring directory structure..."

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p configs/prometheus
mkdir -p configs/alertmanager
mkdir -p configs/grafana/provisioning/datasources
mkdir -p configs/grafana/provisioning/dashboards
mkdir -p configs/grafana/dashboards
mkdir -p configs/loki
mkdir -p configs/nginx/ssl
mkdir -p keypair-service
mkdir -p scanner
mkdir -p data/grafana
mkdir -p data/loki
mkdir -p data/prometheus

echo "📝 Creating configuration files..."

# Create Prometheus configuration
cat > configs/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
EOF

# Create Alertmanager configuration
cat > configs/alertmanager/alertmanager.yml << 'EOF'
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@swayn-monitoring.local'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email-notifications'
  routes:
  - match:
      alertname: Watchdog
    receiver: 'devnull'

receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'admin@swayn-monitoring.local'
    send_resolved: true

- name: 'devnull'
EOF

# Create Grafana datasource provisioning
cat > configs/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Create Grafana dashboard provisioning
cat > configs/grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'default'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create a basic dashboard
cat > configs/grafana/dashboards/system-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "System Overview",
    "tags": ["system", "overview"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{instance}}"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - ((node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100)",
            "legendFormat": "{{instance}}"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 0
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "timepicker": {},
    "templating": {
      "list": []
    },
    "annotations": {
      "list": []
    },
    "refresh": "5s",
    "schemaVersion": 16,
    "version": 0,
    "links": []
  }
}
EOF

# Create Nginx configuration
cat > configs/nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=auth:10m rate=5r/s;

    upstream grafana_backend {
        server grafana:3000;
    }

    upstream prometheus_backend {
        server prometheus:9090;
    }

    upstream alertmanager_backend {
        server alertmanager:9093;
    }

    server {
        listen 80;
        server_name localhost;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # Grafana
        location /grafana/ {
            proxy_pass http://grafana_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;

            # WebSocket support for live dashboards
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Prometheus
        location /prometheus/ {
            proxy_pass http://prometheus_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Alert Manager
        location /alertmanager/ {
            proxy_pass http://alertmanager_backend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Default location - redirect to Grafana
        location / {
            return 301 /grafana/;
        }
    }
}
EOF

# Create .env file template
cat > .env.example << 'EOF'
# Grafana Admin Password
GF_ADMIN_PASSWORD=admin

# Bitwarden Configuration
BITWARDEN_ADMIN_TOKEN=your_secure_admin_token_here
BITWARDEN_USERNAME=your_bitwarden_username
BITWARDEN_PASSWORD=your_bitwarden_password

# Microsoft Teams Webhook URLs for Alertmanager
MSTEAMS_WEBHOOK_URL=https://outlook.office.com/webhook/your-webhook-url
MSTEAMS_CRITICAL_WEBHOOK_URL=https://outlook.office.com/webhook/your-critical-webhook-url
MSTEAMS_WARNING_WEBHOOK_URL=https://outlook.office.com/webhook/your-warning-webhook-url

# Keypair Service Configuration
JWT_SECRET=your-secure-jwt-secret-change-this-in-production

# SSL certificates are automatically configured via docker-compose.ssl.yml
# SSL_CERT_PATH=/path/to/cert.pem
# SSL_KEY_PATH=/path/to/key.pem

# Optional: Email Configuration for Alertmanager
# SMTP_HOST=localhost
# SMTP_PORT=587
# SMTP_USER=
# SMTP_PASS=
EOF

# Create docker-compose override for SSL (if needed)
cat > docker-compose.ssl.yml << 'EOF'
version: '3.8'

services:
  nginx:
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./configs/nginx/ssl:/etc/nginx/ssl:ro
    environment:
      - SSL_CERT_PATH=${SSL_CERT_PATH}
      - SSL_KEY_PATH=${SSL_KEY_PATH}
EOF

# Set permissions
echo "🔒 Setting permissions..."
chmod 644 configs/prometheus/prometheus.yml
chmod 644 configs/alertmanager/alertmanager.yml
chmod 755 configs/alertmanager/entrypoint.sh
chmod 644 configs/grafana/provisioning/datasources/prometheus.yml
chmod 644 configs/grafana/provisioning/dashboards/dashboard.yml
chmod 644 configs/grafana/dashboards/system-overview.json
chmod 644 configs/nginx/nginx.conf
chmod 644 .env.example
chmod 644 docker-compose.ssl.yml

echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Copy .env.example to .env and configure your settings"
echo "   - Generate a secure BITWARDEN_ADMIN_TOKEN (e.g., openssl rand -base64 32)"
echo "   - Set BITWARDEN_USERNAME and BITWARDEN_PASSWORD for the scanner"
echo "2. Optionally configure SSL certificates in configs/nginx/ssl/"
echo "3. Run: docker-compose up -d"
echo "4. Access the services:"
echo "   - Grafana: http://localhost/grafana/"
echo "   - Prometheus: http://localhost/prometheus/"
echo "   - Alert Manager: http://localhost/alertmanager/"
echo ""
echo "🔧 To add SSL support:"
echo "1. Place your certificates in configs/nginx/ssl/"
echo "2. Run: docker-compose -f docker-compose.yml -f docker-compose.ssl.yml up -d"
echo ""
echo "📖 For more information, see the README.md file."