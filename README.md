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
- **Bitwarden**: https://vault.corp.swayn.com/ (password manager)
- **Health Check**: https://localhost/health

### Service Details
- **Grafana** (Port 3000): Visualization and dashboard platform
- **Prometheus** (Port 9090): Metrics collection and storage
- **Alert Manager** (Port 9093): Alert handling and notifications
- **Bitwarden** (Port 80): Self-hosted password manager (Vaultwarden)
- **Node.js Scanner**: Automated service that syncs Bitwarden entries to Prometheus targets
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

The monitoring stack includes an automated Node.js service that scans Bitwarden entries and dynamically updates Prometheus targets.

### Features
- **Automatic Discovery**: Scans Bitwarden entries every minute for URIs
- **Dynamic Configuration**: Automatically adds/removes Prometheus targets based on Bitwarden changes
- **URI Parsing**: Extracts hostnames and ports from Bitwarden entry URIs
- **Live Updates**: Triggers Prometheus configuration reload when changes are detected
- **Change Detection**: Only updates when Bitwarden entries actually change

### How It Works
1. **Authentication**: Logs into Bitwarden using provided credentials
2. **Scanning**: Retrieves all entries with URIs every 60 seconds
3. **Processing**: Extracts service names and endpoints from entries
4. **Configuration**: Updates Prometheus scrape targets with new/changed entries
5. **Reload**: Triggers Prometheus configuration reload to apply changes

### Configuration
Set the following environment variables in your `.env` file:
```bash
BITWARDEN_USERNAME=your_bitwarden_username
BITWARDEN_PASSWORD=your_bitwarden_password
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

## 📁 Directory Structure

```
swayn-monitoring/
├── configs/                 # Configuration files
│   ├── alertmanager/
│   ├── grafana/
│   │   ├── dashboards/
│   │   └── provisioning/
│   ├── nginx/
│   │   └── ssl/            # SSL certificates
│   └── prometheus/
├── data/                    # Persistent data (created by Docker)
├── docker-compose.yml       # Main compose file
├── docker-compose.ssl.yml   # SSL override file
├── install.sh              # Setup script
├── .env.example            # Environment template
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