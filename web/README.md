# Web Configuration Interface

This directory contains the PHP-based web application for managing Swayn Monitoring configuration.

## Files

- `index.php` - Main web interface for managing Prometheus targets
- `config.php` - Database configuration and connection functions
- `targets.php` - API endpoint for CRUD operations on Prometheus targets
- `generate-config.php` - Generates Prometheus configuration from database
- `reload-prometheus.php` - Triggers Prometheus configuration reload

## Features

- Modern, responsive web interface
- Real-time target management (add, edit, delete)
- Dynamic Prometheus configuration generation
- Live Prometheus reload capability
- PostgreSQL integration for data persistence

## Security Note

This interface is intended for internal network use. In production environments, consider:

- Adding authentication
- Restricting access by IP
- Using HTTPS with proper certificates
- Implementing rate limiting

## API Endpoints

### Targets Management
- `GET /config/targets.php?action=list` - List all targets
- `GET /config/targets.php?action=get&id={id}` - Get specific target
- `POST /config/targets.php` - Create/update/delete targets

### Configuration
- `GET /config/generate-config.php` - Generate Prometheus config
- `GET /config/reload-prometheus.php` - Reload Prometheus configuration

## Database Schema

The application uses the `monitoring.prometheus_targets` table:

```sql
CREATE TABLE monitoring.prometheus_targets (
    id SERIAL PRIMARY KEY,
    job_name VARCHAR(255) NOT NULL UNIQUE,
    target_url VARCHAR(500) NOT NULL,
    scrape_interval VARCHAR(50) DEFAULT '15s',
    scrape_timeout VARCHAR(50) DEFAULT '10s',
    labels JSONB DEFAULT '{}',
    enabled BOOLEAN DEFAULT true,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```