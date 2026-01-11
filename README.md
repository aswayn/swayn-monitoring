# swayn-monitoring

A comprehensive monitoring stack using Docker Compose with Grafana, Prometheus, Alert Manager, and nginx reverse proxy.

## 🚀 Quick Start

### Prerequisites
- Docker
- Docker Compose

### Installation
1. Clone the repository
2. Run the setup script:
   ```bash
   ./install.sh
   ```

3. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env to set your desired Grafana admin password
   ```

4. Start the services:
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.ssl.yml up -d
   ```

## 📊 Services

### Access URLs
- **Grafana**: https://localhost/grafana/ (admin/admin by default)
- **Prometheus**: https://localhost/prometheus/
- **Alert Manager**: https://localhost/alertmanager/
- **Loki**: http://localhost:3100/ (log aggregation)
- **Bitwarden**: https://vault.corp.swayn.com/ (password manager)
- **Keypair Service API**: http://localhost:3002/api/ (keypair management - internal only)
- **Health Check**: https://localhost/health

### Service Details
- **Grafana** (Port 3000): Visualization and dashboard platform with Loki logs integration
- **Prometheus** (Port 9090): Metrics collection and storage with etcd service discovery
- **Loki** (Ports 3100, 1514): Log aggregation with syslog TCP/UDP support
- **Alert Manager** (Port 9093): Alert handling and notifications
- **Bitwarden** (Port 80): Self-hosted password manager (Vaultwarden)
- **Keypair Service** (Port 3001): REST API for managing cryptographic keypairs
- **etcd** (Ports 2379/2380): Distributed key-value store for configuration management
- **Node.js Scanner**: Automated service that syncs Bitwarden entries to etcd for Prometheus
- **Nginx** (Ports 80/443): Reverse proxy with SSL termination

## 🔐 SSL Configuration

The setup includes a self-signed SSL certificate with the following details:
- **Domain**: `*.corp.swayn.com` (wildcard certificate)
- **Country**: Australia (AU)
- **State**: NSW
- **Location**: Sydney
- **Organization**: Swayn Enterprises
- **Validity**: 1 year

### Certificate Location
- Certificate: `configs/nginx/ssl/server.crt`
- Private Key: `configs/nginx/ssl/server.key`

### SSL Features
- TLS 1.2 and 1.3 support
- Modern cipher suites
- HTTP/2 support
- Automatic HTTP to HTTPS redirection

## 🕐 Timezone Configuration

All services are configured for Australia/Sydney timezone:
- Container timezone: `TZ=Australia/Sydney`
- Grafana UI timezone: `Australia/Sydney`
- Dashboard defaults to Sydney timezone

## 🤖 Node.js Bitwarden Scanner

The monitoring stack includes an automated Node.js service that scans Bitwarden entries and dynamically updates Prometheus targets via etcd service discovery.

### Features
- **Automatic Discovery**: Scans Bitwarden entries every minute for URIs
- **etcd Integration**: Writes target configurations to etcd key-value store
- **Dynamic Configuration**: Automatically adds/removes Prometheus targets based on Bitwarden changes
- **Change Detection**: Only updates when Bitwarden entries actually change
- **URI Parsing**: Extracts hostnames and ports from Bitwarden entry URIs
- **Real-time Updates**: Prometheus automatically discovers new targets via service discovery

### How It Works
1. **Authentication**: Logs into Bitwarden using provided credentials
2. **Scanning**: Retrieves all entries with URIs every 60 seconds
3. **Processing**: Extracts service names and endpoints from entries
4. **etcd Storage**: Writes target configurations to etcd with structured keys
5. **Service Discovery**: Prometheus automatically discovers targets from etcd

### Configuration
Set the following environment variables in your `.env` file:
```bash
BITWARDEN_USERNAME=your_bitwarden_username
BITWARDEN_PASSWORD=your_bitwarden_password
```

### etcd Integration
The scanner writes to etcd using this structure:
```
/prometheus/targets/{job_name}/{target_url} = {"target": "host:port", "labels": {...}}
```

### Bitwarden Entry Format
The scanner looks for entries with:
- **Name**: Used as the Prometheus job name (sanitized for Prometheus format)
- **URI**: HTTP/HTTPS URLs that become Prometheus targets
- **Multiple URIs**: Each URI in an entry becomes a separate target

### Example
A Bitwarden entry named "My Web Service" with URI "http://web-service:8080" creates:
```
etcd key: /prometheus/targets/my_web_service/web-service:8080
Value: {"target": "web-service:8080", "labels": {"bitwarden_item": "My Web Service", "source": "bitwarden"}}
```

Prometheus discovers this as:
```yaml
- job_name: 'bitwarden-targets'
  etcd_sd_configs:
    - server: 'etcd:2379'
      prefix: '/prometheus/targets/'
  relabel_configs:
    - source_labels: ['__meta_etcd_key']
      regex: '/prometheus/targets/(.+)/(.+)'
      replacement: '${1}'
      target_label: 'job'
```

### Bitwarden Entry Format
The scanner looks for entries with:
- **Name**: Used as the Prometheus job name (sanitized for Prometheus format)
- **URI**: HTTP/HTTPS URLs that become Prometheus targets
- **Multiple URIs**: Each URI in an entry becomes a separate target

### Example
A Bitwarden entry named "My Web Service" with URI "http://web-service:8080" will create:
```yaml
- job_name: bitwarden_my_web_service
  static_configs:
    - targets: ['web-service:8080']
  labels:
    bitwarden_item: "My Web Service"
    source: bitwarden
```

### Security Notes
- Credentials are stored as environment variables
- Bitwarden CLI handles secure authentication
- No sensitive data is logged or exposed
- Scanner runs in isolated container with minimal privileges

## 🔐 Bitwarden Password Manager

The monitoring stack includes Bitwarden (Vaultwarden) for secure password management.

### Features
- **Self-hosted**: Complete control over your password data
- **Cross-platform**: Web interface with mobile and desktop clients
- **Organizations**: Share passwords securely with team members
- **Two-factor authentication**: Enhanced security with 2FA
- **Admin Panel**: Administrative interface for user management

### First-Time Setup
1. Access Bitwarden at https://vault.corp.swayn.com/
2. Create your account (first user becomes admin)
3. Configure organizations and security settings
4. Set up 2FA for enhanced security

### Admin Access
- Admin panel: https://vault.corp.swayn.com/admin
- Use the `BITWARDEN_ADMIN_TOKEN` from your `.env` file
- Generate a secure random token for production use

### Environment Variables
Add to your `.env` file:
```bash
BITWARDEN_ADMIN_TOKEN=your_secure_random_token
BITWARDEN_USERNAME=your_bitwarden_username
BITWARDEN_PASSWORD=your_bitwarden_password
```

Generate a secure token with:
```bash
openssl rand -base64 32
```

### Security Notes
- Change the default admin token in production
- Enable HTTPS in production environments
- Regularly backup the `bitwarden_data` volume
- Consider enabling additional security features

## 🔔 MS Teams Alert Notifications

The Alertmanager is configured to send notifications to Microsoft Teams channels for different alert severities.

### Notification Channels
- **General Alerts**: All alerts sent to the main Teams channel
- **Critical Alerts**: 🚨 High-priority alerts with special formatting
- **Warning Alerts**: ⚠️ Warning-level alerts

### Setup MS Teams Webhooks
1. Go to your Microsoft Teams channel
2. Click the "..." menu → "Workflows" → "Post to a channel when a webhook request is received"
3. Create incoming webhooks for each notification type:
   - General notifications webhook
   - Critical alerts webhook (optional)
   - Warning alerts webhook (optional)

4. Copy the webhook URLs and add them to your `.env` file:
```bash
MSTEAMS_WEBHOOK_URL=https://outlook.office.com/webhook/your-webhook-url
MSTEAMS_CRITICAL_WEBHOOK_URL=https://outlook.office.com/webhook/your-critical-webhook-url
MSTEAMS_WARNING_WEBHOOK_URL=https://outlook.office.com/webhook/your-warning-webhook-url
```

### Alert Routing
- **Default**: All alerts go to the general MS Teams channel
- **Critical**: Alerts with `severity: critical` go to the critical channel
- **Warning**: Alerts with `severity: warning` go to the warning channel

### Message Format
MS Teams notifications include:
- Alert name and status
- Severity level with emoji indicators
- Instance and job information
- Timestamp
- Alert descriptions and summaries

### Example Prometheus Alert
```yaml
groups:
- name: example
  rules:
  - alert: HighCPUUsage
    expr: cpu_usage > 90
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High CPU usage detected"
      description: "CPU usage is above 90% for more than 5 minutes"
```

## 🗂️ etcd Service Discovery

The monitoring stack uses etcd as a dynamic configuration store for Prometheus service discovery.

### How It Works
1. **Node.js Scanner** reads Bitwarden entries and extracts service endpoints
2. **Target configurations** are written to etcd key-value store
3. **Prometheus** uses etcd service discovery to automatically find new targets
4. **Real-time updates** without manual configuration file changes

### etcd Structure
```
etcd keys: /prometheus/targets/{job_name}/{target_url}
Values: JSON with target information and labels
```

### Benefits
- **Dynamic scaling**: Automatically add/remove monitoring targets
- **Centralized configuration**: Single source of truth for service discovery
- **High availability**: etcd provides distributed, fault-tolerant storage
- **Real-time updates**: No service restarts required for configuration changes

### etcd Access
- **Client Port**: 2379 (HTTP API)
- **Peer Port**: 2380 (cluster communication)
- **Web UI**: Not included (use etcdctl for management)

### Configuration
etcd is configured with:
- **Auto-compaction**: 1-hour retention for configuration history
- **Single-node cluster**: Suitable for development/testing
- **Persistent storage**: Data survives container restarts

## 📝 Loki Log Aggregation

The monitoring stack includes Loki for centralized log aggregation with syslog streaming support.

### Features
- **Syslog Support**: Receives logs via TCP and UDP on port 1514
- **Grafana Integration**: Native integration with Grafana for log visualization
- **Prometheus Compatible**: Works with Promtail for advanced log processing
- **Multi-tenant**: Supports multiple log streams and labeling
- **Efficient Storage**: Optimized for log data with compression

### Syslog Configuration
Loki listens for syslog messages on:
- **TCP**: Port 1514 (reliable delivery)
- **UDP**: Port 1514 (high-throughput)

### Log Ingestion Examples

**Send logs via TCP:**
```bash
echo "<14>$(date '+%b %d %H:%M:%S') myhost myapp[123]: Test log message" | nc localhost 1514
```

**Send logs via UDP:**
```bash
echo "<14>$(date '+%b %d %H:%M:%S') myhost myapp[123]: UDP log message" | nc -u localhost 1514
```

**From systemd services:**
```bash
# Add to systemd service configuration
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=my-service
```

**From Docker containers:**
```bash
docker run --log-driver syslog --log-opt syslog-address=tcp://localhost:1514 your-app
```

### Grafana Integration
Loki is automatically configured as a datasource in Grafana:
- **URL**: http://loki:3100
- **Type**: Loki
- **Access**: Proxy

### Query Examples
```
# Basic log search
{job="syslog"}

# Filter by hostname
{hostname="web-server"}

# Search for errors
{job="syslog"} |= "error"

# Time-based queries
{job="syslog"} [5m]
```

### Configuration
Loki is configured with:
- **Retention**: Configurable log retention policies
- **Indexing**: Efficient indexing for fast queries
- **Compression**: Automatic log compression
- **Multi-format**: Supports JSON, logfmt, and plain text

## 🔑 Keypair Management Service

The monitoring stack includes a secure keypair management service for storing and managing cryptographic keys, SSH keys, API keys, and certificates.

### Features
- **Keypair Storage**: Secure storage of public/private keypairs in PostgreSQL
- **SSH Key Generation**: Automated generation of SSH keypairs with optional passphrase protection
- **REST API**: Full CRUD operations for keypair management
- **Authentication**: JWT-based authentication with role-based access
- **Encryption**: Private keys can be encrypted with passphrases
- **Metadata Support**: Flexible JSON metadata for additional key information

### API Endpoints

#### Authentication
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "admin",
  "password": "admin123"
}
```

#### Keypair Operations
```http
# Generate SSH keypair
POST /api/keys/generate-ssh
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "name": "my-ssh-key",
  "passphrase": "optional-passphrase",
  "keySize": 2048
}

# List all keypairs
GET /api/keys
Authorization: Bearer <jwt-token>

# Get specific keypair
GET /api/keys/{id}
Authorization: Bearer <jwt-token>

# Get private key (with passphrase if encrypted)
POST /api/keys/{id}/private
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "passphrase": "key-passphrase"
}

# Update keypair metadata
PUT /api/keys/{id}
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "metadata": {
    "environment": "production",
    "purpose": "database-access"
  }
}

# Delete keypair
DELETE /api/keys/{id}
Authorization: Bearer <jwt-token>
```

### Default Credentials
- **Username**: admin
- **Password**: admin123
- **Role**: admin

### Security Features
- **JWT Authentication**: Bearer token-based authentication
- **Password Hashing**: Bcrypt password hashing for service accounts
- **Key Encryption**: AES-256-CBC encryption for private keys with passphrases
- **Role-based Access**: Support for different user roles and permissions
- **HTTPS Ready**: Designed to work behind reverse proxies with SSL

### Environment Variables
Add to your `.env` file:
```bash
JWT_SECRET=your-secure-jwt-secret-change-this-in-production
```

### Usage Examples

**Generate and Store SSH Key:**
```bash
curl -X POST http://localhost:3002/api/keys/generate-ssh \
  -H "Authorization: Bearer <your-jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "web-server-ssh",
    "passphrase": "my-secure-passphrase",
    "keySize": 4096
  }'
```

**Retrieve Public Key:**
```bash
curl -X GET http://localhost:3002/api/keys/1 \
  -H "Authorization: Bearer <your-jwt-token>"
```

**Get Encrypted Private Key:**
```bash
curl -X POST http://localhost:3002/api/keys/1/private \
  -H "Authorization: Bearer <jwt-token>" \
  -H "Content-Type: application/json" \
  -d '{"passphrase": "my-secure-passphrase"}'
```

### Integration
The keypair service integrates seamlessly with:
- **Bitwarden**: For password management alongside keypairs
- **PostgreSQL**: For secure, persistent storage
- **Monitoring Stack**: Can be monitored by Prometheus
- **CI/CD Pipelines**: API can be used by automation tools

## 📁 Directory Structure

```
swayn-monitoring/
├── configs/                 # Configuration files
│   ├── alertmanager/
│   ├── grafana/
│   │   ├── dashboards/
│   │   └── provisioning/
│   ├── loki/               # Loki configuration
│   ├── nginx/
│   │   └── ssl/            # SSL certificates
│   ├── postgres/
│   ├── prometheus/
│   └── web/                # PHP configuration
├── data/                    # Persistent data (created by Docker)
├── docker-compose.yml       # Main compose file
├── docker-compose.ssl.yml   # SSL override file
├── install.sh              # Setup script
├── .env.example            # Environment template
├── keypair-service/        # Keypair management service
├── README.md               # Main documentation
└── scanner/                # Node.js Bitwarden scanner
```

## 🔧 Configuration

### Environment Variables
Create a `.env` file with:
```bash
GF_ADMIN_PASSWORD=your_secure_password
```

### Custom SSL Certificates
To use your own certificates:
1. Place your certificate in `configs/nginx/ssl/server.crt`
2. Place your private key in `configs/nginx/ssl/server.key`
3. Restart the services

## 📈 Monitoring Setup

### Adding Targets to Prometheus
Edit `configs/prometheus/prometheus.yml` to add new scrape targets:

```yaml
scrape_configs:
  - job_name: 'your-service'
    static_configs:
      - targets: ['your-service:9090']
```

### Grafana Dashboards
- Dashboards are auto-provisioned from `configs/grafana/dashboards/`
- Data sources are auto-configured for Prometheus

### Alerting
- Configure alerts in Prometheus configuration
- Alert Manager handles routing and notifications
- Default configuration sends emails (update SMTP settings in alertmanager.yml)

## 🛠️ Development

### Running Single Services
```bash
# Run only Prometheus
docker-compose up prometheus

# Run only Grafana
docker-compose up grafana
```

### Logs
```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f grafana
```

### Rebuilding
```bash
# Rebuild after configuration changes
docker-compose up -d --build
```

## 🔍 Troubleshooting

### SSL Certificate Warnings
Since this uses self-signed certificates, browsers will show security warnings. This is expected for development/testing environments.

### Port Conflicts
If ports 80 or 443 are already in use:
```bash
# Change ports in docker-compose.ssl.yml
ports:
  - "8080:80"
  - "8443:443"
```

### Permission Issues
Ensure the SSL certificate files have correct permissions:
```bash
chmod 644 configs/nginx/ssl/server.crt
chmod 600 configs/nginx/ssl/server.key
```

## 📝 Notes

- All data is persisted using Docker named volumes
- Services are configured to restart automatically unless stopped manually
- The setup includes basic security headers and rate limiting
- Timezone is set to Australia/Sydney for all services

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request