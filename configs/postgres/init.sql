-- Swayn Monitoring Database Initialization
-- This file is executed when the PostgreSQL container starts for the first time

-- Create monitoring schema
CREATE SCHEMA IF NOT EXISTS monitoring;

-- Create a table for storing custom metrics (example)
CREATE TABLE IF NOT EXISTS monitoring.custom_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(255) NOT NULL,
    metric_value NUMERIC NOT NULL,
    labels JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create an index on timestamp for better query performance
CREATE INDEX IF NOT EXISTS idx_custom_metrics_timestamp ON monitoring.custom_metrics (timestamp);
CREATE INDEX IF NOT EXISTS idx_custom_metrics_name ON monitoring.custom_metrics (metric_name);

-- Create a table for storing alert history (example)
CREATE TABLE IF NOT EXISTS monitoring.alert_history (
    id SERIAL PRIMARY KEY,
    alert_name VARCHAR(255) NOT NULL,
    severity VARCHAR(50),
    status VARCHAR(50),
    description TEXT,
    labels JSONB,
    annotations JSONB,
    starts_at TIMESTAMP WITH TIME ZONE,
    ends_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for alert history
CREATE INDEX IF NOT EXISTS idx_alert_history_status ON monitoring.alert_history (status);
CREATE INDEX IF NOT EXISTS idx_alert_history_starts_at ON monitoring.alert_history (starts_at);

-- Create table for Prometheus targets management
CREATE TABLE IF NOT EXISTS monitoring.prometheus_targets (
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

-- Create indexes for targets
CREATE INDEX IF NOT EXISTS idx_targets_enabled ON monitoring.prometheus_targets (enabled);
CREATE INDEX IF NOT EXISTS idx_targets_job_name ON monitoring.prometheus_targets (job_name);

-- Insert some default targets
INSERT INTO monitoring.prometheus_targets (job_name, target_url, description) VALUES
('prometheus', 'localhost:9090', 'Prometheus itself'),
('grafana', 'grafana:3000', 'Grafana web interface'),
('alertmanager', 'alertmanager:9093', 'Alert Manager service'),
('postgres', 'postgres:5432', 'PostgreSQL database'),
('keypair-service', 'keypair-service:3001', 'Keypair management service')
ON CONFLICT (job_name) DO NOTHING;

-- Create tables for keypair service
CREATE TABLE IF NOT EXISTS monitoring.keypairs (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    type VARCHAR(50) NOT NULL, -- ssh, api, certificate, etc.
    public_key TEXT,
    private_key TEXT,
    encrypted_private_key TEXT,
    passphrase_hash VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS monitoring.service_accounts (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'user',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for keypairs
CREATE INDEX IF NOT EXISTS idx_keypairs_type ON monitoring.keypairs (type);
CREATE INDEX IF NOT EXISTS idx_keypairs_name ON monitoring.keypairs (name);

-- Insert default admin user (password: admin123)
-- Hash generated with bcrypt, 12 salt rounds
INSERT INTO monitoring.service_accounts (username, password_hash, role) VALUES
('admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj7HQTWKaL6e', 'admin')
ON CONFLICT (username) DO NOTHING;

-- Grant permissions to the monitoring user
GRANT ALL PRIVILEGES ON SCHEMA monitoring TO monitoring_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA monitoring TO monitoring_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA monitoring TO monitoring_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA monitoring GRANT ALL ON TABLES TO monitoring_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA monitoring GRANT ALL ON SEQUENCES TO monitoring_user;

-- Insert a sample record to verify the setup
INSERT INTO monitoring.custom_metrics (metric_name, metric_value, labels)
VALUES ('database_initialized', 1, '{"component": "postgres", "status": "ready"}')
ON CONFLICT DO NOTHING;