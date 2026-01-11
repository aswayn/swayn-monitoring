#!/bin/bash

#!/bin/bash

# ========================================================================================
# Swayn Monitoring Interactive Setup Script
# ========================================================================================
#
# Interactive installer for the complete monitoring stack including:
#
# Core Monitoring:
#   - Prometheus (metrics collection & alerting)
#   - Grafana (visualization & dashboards)
#   - Alert Manager (alert routing & notifications)
#   - Loki (log aggregation)
#
# Supporting Services:
#   - Bitwarden (password management)
#   - PostgreSQL (database backend)
#   - etcd (service discovery)
#   - Keypair Service (SSH/API key management)
#
# Infrastructure:
#   - Nginx (reverse proxy & SSL termination)
#   - Node.js Scanner (Bitwarden to Prometheus sync)
#
# Requirements: Docker, Docker Compose
# ========================================================================================

set -e

# Check for required tools
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Aborting."; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed. Aborting."; exit 1; }

echo "✅ Prerequisites check passed"

# Configuration variables with defaults
CONFIG_DOMAIN_MAIN="giants.corp.swayn.com"
CONFIG_DOMAIN_VAULT="vault.corp.swayn.com"
CONFIG_SSL_COUNTRY="AU"
CONFIG_SSL_STATE="NSW"
CONFIG_SSL_CITY="Sydney"
CONFIG_SSL_ORG="Swayn Enterprises"
CONFIG_SSL_VALIDITY="365"
CONFIG_SSL_GENERATE_CERTS="yes"
CONFIG_GRAFANA_PASSWORD="admin123"
CONFIG_POSTGRES_USER="monitoring_user"
CONFIG_POSTGRES_PASSWORD="monitoring_pass"
CONFIG_POSTGRES_DB="monitoring"
CONFIG_BITWARDEN_ADMIN_TOKEN=""
CONFIG_BITWARDEN_USERNAME=""
CONFIG_BITWARDEN_PASSWORD=""
CONFIG_MSTEAMS_WEBHOOK=""
CONFIG_MSTEAMS_CRITICAL_WEBHOOK=""
CONFIG_MSTEAMS_WARNING_WEBHOOK=""
CONFIG_JWT_SECRET=""
CONFIG_DEPLOY_MODE="ssl"  # ssl or basic

# Installer state file
INSTALLER_ENV_FILE="installer.env"

# Configuration management functions
save_installer_config() {
    cat > "$INSTALLER_ENV_FILE" << EOF
# Swayn Monitoring Installer Configuration
# Generated: $(date)
# This file contains your installer settings

# Domain Configuration
CONFIG_DOMAIN_MAIN="$CONFIG_DOMAIN_MAIN"
CONFIG_DOMAIN_VAULT="$CONFIG_DOMAIN_VAULT"

# SSL Certificate Settings
CONFIG_SSL_COUNTRY="$CONFIG_SSL_COUNTRY"
CONFIG_SSL_STATE="$CONFIG_SSL_STATE"
CONFIG_SSL_CITY="$CONFIG_SSL_CITY"
CONFIG_SSL_ORG="$CONFIG_SSL_ORG"
CONFIG_SSL_VALIDITY="$CONFIG_SSL_VALIDITY"
CONFIG_SSL_GENERATE_CERTS="$CONFIG_SSL_GENERATE_CERTS"

# Grafana Configuration
CONFIG_GRAFANA_PASSWORD="$CONFIG_GRAFANA_PASSWORD"

# PostgreSQL Configuration
CONFIG_POSTGRES_USER="$CONFIG_POSTGRES_USER"
CONFIG_POSTGRES_PASSWORD="$CONFIG_POSTGRES_PASSWORD"
CONFIG_POSTGRES_DB="$CONFIG_POSTGRES_DB"

# Bitwarden Configuration
CONFIG_BITWARDEN_ADMIN_TOKEN="$CONFIG_BITWARDEN_ADMIN_TOKEN"
CONFIG_BITWARDEN_USERNAME="$CONFIG_BITWARDEN_USERNAME"
CONFIG_BITWARDEN_PASSWORD="$CONFIG_BITWARDEN_PASSWORD"

# MS Teams Notifications
CONFIG_MSTEAMS_WEBHOOK="$CONFIG_MSTEAMS_WEBHOOK"
CONFIG_MSTEAMS_CRITICAL_WEBHOOK="$CONFIG_MSTEAMS_CRITICAL_WEBHOOK"
CONFIG_MSTEAMS_WARNING_WEBHOOK="$CONFIG_MSTEAMS_WARNING_WEBHOOK"

# Security Settings
CONFIG_JWT_SECRET="$CONFIG_JWT_SECRET"
CONFIG_DEPLOY_MODE="$CONFIG_DEPLOY_MODE"
EOF
}

load_installer_config() {
    if [ -f "$INSTALLER_ENV_FILE" ]; then
        echo "📂 Found existing installer configuration, loading settings..."
        source "$INSTALLER_ENV_FILE"
        echo "✅ Configuration loaded successfully"
        return 0
    else
        echo "🆕 Starting fresh installation - you'll be guided through the setup process"
        # Don't save config yet - let user provide inputs first
        return 1
    fi
}

# Menu functions
show_main_menu() {
    clear
    echo "========================================================================================"
    echo "🎯 Swayn Monitoring Stack - Interactive Installer"
    echo "========================================================================================"
    if [ -f "$INSTALLER_ENV_FILE" ]; then
        echo "📂 Resume Mode - Configuration loaded from installer.env"
    else
        echo "🆕 Fresh Installation - Let's configure your monitoring stack"
    fi
    echo ""
    echo "📋 Main Menu:"
    echo "1. 📊 Domain Configuration"
    echo "2. 🔐 SSL Certificate Settings"
    echo "3. 📈 Grafana Configuration"
    echo "4. 💾 PostgreSQL Configuration"
    echo "5. 🔑 Bitwarden Configuration"
    echo "6. 🔔 MS Teams Notifications"
    echo "7. 🔒 Security Settings"
    echo "8. 👀 Review Configuration"
    echo "9. 🚀 Install & Deploy"
    echo "0. ❌ Exit"
    echo ""
    if [ ! -f "$INSTALLER_ENV_FILE" ]; then
        echo "💡 Tip: Start with Domain Configuration (option 1) for fresh installations"
        echo ""
    fi
    echo -n "Choose an option [0-9]: "
}

show_domain_menu() {
    clear
    echo "========================================================================================"
    echo "📊 Domain Configuration"
    echo "========================================================================================"
    echo ""
    echo "Current Settings:"
    echo "  Main Domain: $CONFIG_DOMAIN_MAIN"
    echo "  Vault Domain: $CONFIG_DOMAIN_VAULT"
    echo ""
    echo "Options:"
    echo "1. Edit Main Domain"
    echo "2. Edit Vault Domain"
    echo "9. Back to Main Menu"
    echo ""
    echo -n "Choose an option [1-2,9]: "
}

show_ssl_menu() {
    clear
    echo "========================================================================================"
    echo "🔐 SSL Certificate Settings"
    echo "========================================================================================"
    echo ""
    echo "Current Settings:"
    echo "  Country: $CONFIG_SSL_COUNTRY"
    echo "  State: $CONFIG_SSL_STATE"
    echo "  City: $CONFIG_SSL_CITY"
    echo "  Organization: $CONFIG_SSL_ORG"
    echo "  Validity Days: $CONFIG_SSL_VALIDITY"
    echo "  Generate Certificates: $CONFIG_SSL_GENERATE_CERTS"
    echo ""
    echo "Options:"
    echo "1. Edit Country"
    echo "2. Edit State"
    echo "3. Edit City"
    echo "4. Edit Organization"
    echo "5. Edit Validity Days"
    echo "6. Toggle Certificate Generation"
    echo "7. Generate SSL Certificates Now"
    echo "9. Back to Main Menu"
    echo ""
    echo -n "Choose an option [1-7,9]: "
}

show_grafana_menu() {
    clear
    echo "========================================================================================"
    echo "📈 Grafana Configuration"
    echo "========================================================================================"
    echo ""
    echo "Current Settings:"
    echo "  Admin Password: $CONFIG_GRAFANA_PASSWORD"
    echo ""
    echo "Options:"
    echo "1. Edit Admin Password"
    echo "9. Back to Main Menu"
    echo ""
    echo -n "Choose an option [1,9]: "
}

show_postgres_menu() {
    clear
    echo "========================================================================================"
    echo "💾 PostgreSQL Configuration"
    echo "========================================================================================"
    echo ""
    echo "Current Settings:"
    echo "  Username: $CONFIG_POSTGRES_USER"
    echo "  Password: $CONFIG_POSTGRES_PASSWORD"
    echo "  Database: $CONFIG_POSTGRES_DB"
    echo ""
    echo "Options:"
    echo "1. Edit Username"
    echo "2. Edit Password"
    echo "3. Edit Database Name"
    echo "9. Back to Main Menu"
    echo ""
    echo -n "Choose an option [1-3,9]: "
}

show_bitwarden_menu() {
    clear
    echo "========================================================================================"
    echo "🔑 Bitwarden Configuration"
    echo "========================================================================================"
    echo ""
    echo "Current Settings:"
    echo "  Admin Token: $CONFIG_BITWARDEN_ADMIN_TOKEN"
    echo "  Username: $CONFIG_BITWARDEN_USERNAME"
    echo "  Password: $CONFIG_BITWARDEN_PASSWORD"
    echo ""
    echo "Options:"
    echo "1. Edit Admin Token"
    echo "2. Edit Username"
    echo "3. Edit Password"
    echo "9. Back to Main Menu"
    echo ""
    echo -n "Choose an option [1-3,9]: "
}

show_msteams_menu() {
    clear
    echo "========================================================================================"
    echo "🔔 MS Teams Notifications"
    echo "========================================================================================"
    echo ""
    echo "Current Settings:"
    echo "  General Webhook: $CONFIG_MSTEAMS_WEBHOOK"
    echo "  Critical Webhook: $CONFIG_MSTEAMS_CRITICAL_WEBHOOK"
    echo "  Warning Webhook: $CONFIG_MSTEAMS_WARNING_WEBHOOK"
    echo ""
    echo "Options:"
    echo "1. Edit General Webhook"
    echo "2. Edit Critical Webhook"
    echo "3. Edit Warning Webhook"
    echo "9. Back to Main Menu"
    echo ""
    echo -n "Choose an option [1-3,9]: "
}

show_security_menu() {
    clear
    echo "========================================================================================"
    echo "🔒 Security Settings"
    echo "========================================================================================"
    echo ""
    echo "Current Settings:"
    echo "  JWT Secret: $CONFIG_JWT_SECRET"
    echo "  Deploy Mode: $CONFIG_DEPLOY_MODE"
    echo ""
    echo "Options:"
    echo "1. Edit JWT Secret"
    echo "2. Toggle Deploy Mode (ssl/basic)"
    echo "9. Back to Main Menu"
    echo ""
    echo -n "Choose an option [1-2,9]: "
}

show_review_menu() {
    clear
    echo "========================================================================================"
    echo "👀 Configuration Review"
    echo "========================================================================================"
    if [ ! -f "$INSTALLER_ENV_FILE" ]; then
        echo "📝 Fresh Installation - Review your settings before proceeding"
    else
        echo "📂 Resume Mode - Review and confirm your loaded configuration"
    fi
    echo ""
    echo "📊 Domain Configuration:"
    echo "  Main Domain: $CONFIG_DOMAIN_MAIN"
    echo "  Vault Domain: $CONFIG_DOMAIN_VAULT"
    echo ""
    echo "🔐 SSL Certificate:"
    echo "  Country: $CONFIG_SSL_COUNTRY"
    echo "  State: $CONFIG_SSL_STATE"
    echo "  City: $CONFIG_SSL_CITY"
    echo "  Organization: $CONFIG_SSL_ORG"
    echo "  Validity: $CONFIG_SSL_VALIDITY days"
    echo "  Generate Certificates: $CONFIG_SSL_GENERATE_CERTS"
    echo ""
    echo "📈 Grafana:"
    echo "  Admin Password: $CONFIG_GRAFANA_PASSWORD"
    echo ""
    echo "💾 PostgreSQL:"
    echo "  Username: $CONFIG_POSTGRES_USER"
    echo "  Password: $CONFIG_POSTGRES_PASSWORD"
    echo "  Database: $CONFIG_POSTGRES_DB"
    echo ""
    echo "🔑 Bitwarden:"
    echo "  Admin Token: $CONFIG_BITWARDEN_ADMIN_TOKEN"
    echo "  Username: $CONFIG_BITWARDEN_USERNAME"
    echo "  Password: $CONFIG_BITWARDEN_PASSWORD"
    echo ""
    echo "🔔 MS Teams:"
    echo "  General: $CONFIG_MSTEAMS_WEBHOOK"
    echo "  Critical: $CONFIG_MSTEAMS_CRITICAL_WEBHOOK"
    echo "  Warning: $CONFIG_MSTEAMS_WARNING_WEBHOOK"
    echo ""
    echo "🔒 Security:"
    echo "  JWT Secret: $CONFIG_JWT_SECRET"
    echo "  Deploy Mode: $CONFIG_DEPLOY_MODE"
    echo ""
    echo "Options:"
    echo "1. ✅ Proceed with Installation"
    echo "9. Back to Main Menu"
    echo ""
    echo -n "Choose an option [1,9]: "
}

# Input validation functions
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ Invalid domain format. Please use format: subdomain.domain.tld"
        return 1
    fi
    return 0
}

validate_password() {
    local password=$1
    if [ ${#password} -lt 8 ]; then
        echo "❌ Password must be at least 8 characters long"
        return 1
    fi
    return 0
}

validate_days() {
    local days=$1
    if ! [[ $days =~ ^[0-9]+$ ]] || [ "$days" -lt 30 ] || [ "$days" -gt 3650 ]; then
        echo "❌ Validity days must be a number between 30 and 3650"
        return 1
    fi
    return 0
}

validate_url() {
    local url=$1
    if [ -z "$url" ]; then
        return 0  # Empty is allowed
    fi
    if [[ ! $url =~ ^https:// ]]; then
        echo "❌ URL must start with https://"
        return 1
    fi
    return 0
}

# Input functions
read_input() {
    local prompt=$1
    local default=$2
    local validator=$3

    if [ -n "$default" ]; then
        echo -n "$prompt [$default]: "
    else
        echo -n "$prompt: "
    fi

    read input
    input=${input:-$default}

    if [ -n "$validator" ]; then
        if ! $validator "$input"; then
            return 1
        fi
    fi

    echo "$input"
}

read_password() {
    local prompt=$1
    local default=$2

    echo -n "$prompt: "
    read -s input
    echo ""

    if [ -z "$input" ] && [ -n "$default" ]; then
        input=$default
    fi

    if [ -z "$input" ]; then
        echo "❌ Password cannot be empty"
        return 1
    fi

    echo "$input"
}

# Generate random secrets
generate_secret() {
    openssl rand -base64 32
}

# Menu handlers
handle_domain_menu() {
    while true; do
        show_domain_menu
        read choice
        case $choice in
            1)
                CONFIG_DOMAIN_MAIN=$(read_input "Enter main domain" "$CONFIG_DOMAIN_MAIN" validate_domain) || continue
                save_installer_config
                ;;
            2)
                CONFIG_DOMAIN_VAULT=$(read_input "Enter vault domain" "$CONFIG_DOMAIN_VAULT" validate_domain) || continue
                save_installer_config
                ;;
            9)
                save_installer_config
                return
                ;;
            *)
                echo "❌ Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

generate_ssl_certificates() {
    echo "🔐 Generating SSL certificates..."
    echo "   - Private key: RSA 4096-bit"
    echo "   - Certificate: Self-signed for $CONFIG_DOMAIN_MAIN, $CONFIG_DOMAIN_VAULT"
    echo "   - Validity: $CONFIG_SSL_VALIDITY days"

    # Create SSL directory if it doesn't exist
    mkdir -p "ssl-certificates"

    # Generate SSL private key
    if ! openssl genrsa -out "ssl-certificates/server.key" 4096 2>/dev/null; then
        echo "❌ Failed to generate private key"
        return 1
    fi

    # Generate Certificate Signing Request (CSR)
    if ! openssl req -new -key "ssl-certificates/server.key" -out "ssl-certificates/server.csr" \
      -subj "/C=$CONFIG_SSL_COUNTRY/ST=$CONFIG_SSL_STATE/L=$CONFIG_SSL_CITY/O=$CONFIG_SSL_ORG/CN=$CONFIG_DOMAIN_MAIN" 2>/dev/null; then
        echo "❌ Failed to generate CSR"
        return 1
    fi

    # Generate self-signed certificate with Subject Alternative Names
    if ! openssl x509 -req -in "ssl-certificates/server.csr" \
      -signkey "ssl-certificates/server.key" \
      -out "ssl-certificates/server.crt" \
      -days "$CONFIG_SSL_VALIDITY" \
      -extfile <(printf "subjectAltName=DNS:$CONFIG_DOMAIN_MAIN,DNS:$CONFIG_DOMAIN_VAULT") 2>/dev/null; then
        echo "❌ Failed to generate certificate"
        return 1
    fi

    echo "✅ SSL certificates generated successfully in ssl-certificates/ directory"
    echo "   - server.key (private key)"
    echo "   - server.crt (certificate)"
    echo "   - server.csr (certificate signing request)"

    # Show certificate details
    echo ""
    echo "📜 Certificate Details:"
    openssl x509 -in "ssl-certificates/server.crt" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:|Subject Alternative Name:)" | head -10

    read -p "Press Enter to continue..."
}

handle_ssl_menu() {
    while true; do
        show_ssl_menu
        read choice
        case $choice in
            1)
                CONFIG_SSL_COUNTRY=$(read_input "Enter country code (2 letters)" "$CONFIG_SSL_COUNTRY")
                save_installer_config
                ;;
            2)
                CONFIG_SSL_STATE=$(read_input "Enter state/province" "$CONFIG_SSL_STATE")
                save_installer_config
                ;;
            3)
                CONFIG_SSL_CITY=$(read_input "Enter city" "$CONFIG_SSL_CITY")
                save_installer_config
                ;;
            4)
                CONFIG_SSL_ORG=$(read_input "Enter organization" "$CONFIG_SSL_ORG")
                save_installer_config
                ;;
            5)
                CONFIG_SSL_VALIDITY=$(read_input "Enter validity in days" "$CONFIG_SSL_VALIDITY" validate_days) || continue
                save_installer_config
                ;;
            6)
                if [ "$CONFIG_SSL_GENERATE_CERTS" = "yes" ]; then
                    CONFIG_SSL_GENERATE_CERTS="no"
                else
                    CONFIG_SSL_GENERATE_CERTS="yes"
                fi
                echo "🔄 Certificate generation set to: $CONFIG_SSL_GENERATE_CERTS"
                save_installer_config
                read -p "Press Enter to continue..."
                ;;
            7)
                generate_ssl_certificates
                ;;
            9)
                save_installer_config
                return
                ;;
            *)
                echo "❌ Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

handle_grafana_menu() {
    while true; do
        show_grafana_menu
        read choice
        case $choice in
            1)
                CONFIG_GRAFANA_PASSWORD=$(read_password "Enter Grafana admin password" "$CONFIG_GRAFANA_PASSWORD") || continue
                save_installer_config
                ;;
            9)
                save_installer_config
                return
                ;;
            *)
                echo "❌ Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

handle_postgres_menu() {
    while true; do
        show_postgres_menu
        read choice
        case $choice in
            1)
                CONFIG_POSTGRES_USER=$(read_input "Enter PostgreSQL username" "$CONFIG_POSTGRES_USER")
                save_installer_config
                ;;
            2)
                CONFIG_POSTGRES_PASSWORD=$(read_password "Enter PostgreSQL password" "$CONFIG_POSTGRES_PASSWORD") || continue
                save_installer_config
                ;;
            3)
                CONFIG_POSTGRES_DB=$(read_input "Enter PostgreSQL database name" "$CONFIG_POSTGRES_DB")
                save_installer_config
                ;;
            9)
                save_installer_config
                return
                ;;
            *)
                echo "❌ Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

handle_bitwarden_menu() {
    while true; do
        show_bitwarden_menu
        read choice
        case $choice in
            1)
                CONFIG_BITWARDEN_ADMIN_TOKEN=$(read_input "Enter Bitwarden admin token" "$CONFIG_BITWARDEN_ADMIN_TOKEN")
                save_installer_config
                ;;
            2)
                CONFIG_BITWARDEN_USERNAME=$(read_input "Enter Bitwarden username" "$CONFIG_BITWARDEN_USERNAME")
                save_installer_config
                ;;
            3)
                CONFIG_BITWARDEN_PASSWORD=$(read_password "Enter Bitwarden password" "$CONFIG_BITWARDEN_PASSWORD") || continue
                save_installer_config
                ;;
            9)
                save_installer_config
                return
                ;;
            *)
                echo "❌ Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

handle_msteams_menu() {
    while true; do
        show_msteams_menu
        read choice
        case $choice in
            1)
                CONFIG_MSTEAMS_WEBHOOK=$(read_input "Enter MS Teams general webhook URL" "$CONFIG_MSTEAMS_WEBHOOK" validate_url) || continue
                save_installer_config
                ;;
            2)
                CONFIG_MSTEAMS_CRITICAL_WEBHOOK=$(read_input "Enter MS Teams critical webhook URL" "$CONFIG_MSTEAMS_CRITICAL_WEBHOOK" validate_url) || continue
                save_installer_config
                ;;
            3)
                CONFIG_MSTEAMS_WARNING_WEBHOOK=$(read_input "Enter MS Teams warning webhook URL" "$CONFIG_MSTEAMS_WARNING_WEBHOOK" validate_url) || continue
                save_installer_config
                ;;
            9)
                save_installer_config
                return
                ;;
            *)
                echo "❌ Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

handle_security_menu() {
    while true; do
        show_security_menu
        read choice
        case $choice in
            1)
                CONFIG_JWT_SECRET=$(read_input "Enter JWT secret (leave empty for auto-generate)" "$CONFIG_JWT_SECRET")
                if [ -z "$CONFIG_JWT_SECRET" ]; then
                    CONFIG_JWT_SECRET=$(generate_secret)
                    echo "🔑 Generated JWT secret: $(echo "$CONFIG_JWT_SECRET" | cut -c1-20)..."
                fi
                save_installer_config
                ;;
            2)
                if [ "$CONFIG_DEPLOY_MODE" = "ssl" ]; then
                    CONFIG_DEPLOY_MODE="basic"
                else
                    CONFIG_DEPLOY_MODE="ssl"
                fi
                echo "🔄 Deploy mode changed to: $CONFIG_DEPLOY_MODE"
                save_installer_config
                read -p "Press Enter to continue..."
                ;;
            9)
                save_installer_config
                return
                ;;
            *)
                echo "❌ Invalid option"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

validate_all_config() {
    local errors=()

    # Validate domains
    validate_domain "$CONFIG_DOMAIN_MAIN" || errors+=("Invalid main domain: $CONFIG_DOMAIN_MAIN")
    validate_domain "$CONFIG_DOMAIN_VAULT" || errors+=("Invalid vault domain: $CONFIG_DOMAIN_VAULT")

    # Validate passwords
    validate_password "$CONFIG_GRAFANA_PASSWORD" || errors+=("Grafana password too short")
    validate_password "$CONFIG_POSTGRES_PASSWORD" || errors+=("PostgreSQL password too short")

    # Validate URLs (optional - can be empty)
    if [ -n "$CONFIG_MSTEAMS_WEBHOOK" ]; then
        validate_url "$CONFIG_MSTEAMS_WEBHOOK" || errors+=("Invalid MS Teams general webhook")
    fi
    if [ -n "$CONFIG_MSTEAMS_CRITICAL_WEBHOOK" ]; then
        validate_url "$CONFIG_MSTEAMS_CRITICAL_WEBHOOK" || errors+=("Invalid MS Teams critical webhook")
    fi
    if [ -n "$CONFIG_MSTEAMS_WARNING_WEBHOOK" ]; then
        validate_url "$CONFIG_MSTEAMS_WARNING_WEBHOOK" || errors+=("Invalid MS Teams warning webhook")
    fi

    # Validate required fields for Bitwarden
    [ -z "$CONFIG_BITWARDEN_ADMIN_TOKEN" ] && errors+=("Bitwarden admin token is required")
    [ -z "$CONFIG_BITWARDEN_USERNAME" ] && errors+=("Bitwarden username is required")
    [ -z "$CONFIG_BITWARDEN_PASSWORD" ] && errors+=("Bitwarden password is required")
    [ -z "$CONFIG_JWT_SECRET" ] && errors+=("JWT secret is required")

    # For fresh installs, warn about default passwords
    if [ ! -f "$INSTALLER_ENV_FILE" ]; then
        if [ "$CONFIG_GRAFANA_PASSWORD" = "admin123" ]; then
            errors+=("Please change the default Grafana password (currently 'admin123')")
        fi
        if [ "$CONFIG_POSTGRES_PASSWORD" = "monitoring_pass" ]; then
            errors+=("Please change the default PostgreSQL password (currently 'monitoring_pass')")
        fi
    fi

    if [ ${#errors[@]} -gt 0 ]; then
        echo "❌ Configuration validation failed:"
        for error in "${errors[@]}"; do
            echo "  - $error"
        done
        echo ""
        if [ ! -f "$INSTALLER_ENV_FILE" ]; then
            echo "💡 Tip: Use the menu options above to configure these settings"
        fi
        echo ""
        return 1
    fi

    return 0
}

perform_installation() {
    echo ""
    echo "🚀 Starting Installation..."
    echo ""

    # Handle SSL certificates
    if [ "$CONFIG_SSL_GENERATE_CERTS" = "yes" ]; then
        echo "🔐 SSL Certificate Configuration..."
        if [ -f "ssl-certificates/server.crt" ] && [ -f "ssl-certificates/server.key" ]; then
            echo "✅ Using existing SSL certificates from ssl-certificates/ directory"
            cp ssl-certificates/server.crt configs/nginx/ssl/
            cp ssl-certificates/server.key configs/nginx/ssl/
            cp ssl-certificates/server.csr configs/nginx/ssl/ 2>/dev/null || true
        else
            echo "🔐 Generating new SSL certificates..."
            echo "   - Private key: RSA 4096-bit"
            echo "   - Certificate: Self-signed for $CONFIG_DOMAIN_MAIN, $CONFIG_DOMAIN_VAULT"
            echo "   - Validity: $CONFIG_SSL_VALIDITY days"

            # Generate SSL private key
            openssl genrsa -out configs/nginx/ssl/server.key 4096 2>/dev/null

            # Generate Certificate Signing Request (CSR)
            openssl req -new -key configs/nginx/ssl/server.key -out configs/nginx/ssl/server.csr \
              -subj "/C=$CONFIG_SSL_COUNTRY/ST=$CONFIG_SSL_STATE/L=$CONFIG_SSL_CITY/O=$CONFIG_SSL_ORG/CN=$CONFIG_DOMAIN_MAIN" 2>/dev/null

            # Generate self-signed certificate with Subject Alternative Names
            openssl x509 -req -in configs/nginx/ssl/server.csr \
              -signkey configs/nginx/ssl/server.key \
              -out configs/nginx/ssl/server.crt \
              -days $CONFIG_SSL_VALIDITY \
              -extfile <(printf "subjectAltName=DNS:$CONFIG_DOMAIN_MAIN,DNS:$CONFIG_DOMAIN_VAULT") 2>/dev/null

            echo "✅ SSL certificates generated"

            # Also save to ssl-certificates directory for future reference
            mkdir -p ssl-certificates
            cp configs/nginx/ssl/server.crt ssl-certificates/
            cp configs/nginx/ssl/server.key ssl-certificates/
            cp configs/nginx/ssl/server.csr ssl-certificates/ 2>/dev/null || true
        fi
    else
        echo "⚠️  SSL certificate generation disabled. Using basic HTTP configuration."
        echo "   Enable SSL in the menu if you want HTTPS support."
    fi

    # Generate .env file
    echo "📝 Generating environment configuration..."
    cat > .env << EOF
# Grafana Admin Password
GF_ADMIN_PASSWORD=$CONFIG_GRAFANA_PASSWORD

# Bitwarden Configuration
BITWARDEN_ADMIN_TOKEN=$CONFIG_BITWARDEN_ADMIN_TOKEN
BITWARDEN_USERNAME=$CONFIG_BITWARDEN_USERNAME
BITWARDEN_PASSWORD=$CONFIG_BITWARDEN_PASSWORD

# Microsoft Teams Webhook URLs for Alertmanager
MSTEAMS_WEBHOOK_URL=$CONFIG_MSTEAMS_WEBHOOK
MSTEAMS_CRITICAL_WEBHOOK_URL=$CONFIG_MSTEAMS_CRITICAL_WEBHOOK
MSTEAMS_WARNING_WEBHOOK_URL=$CONFIG_MSTEAMS_WARNING_WEBHOOK

# Keypair Service Configuration
JWT_SECRET=$CONFIG_JWT_SECRET

# PostgreSQL Configuration (internal)
POSTGRES_USER=$CONFIG_POSTGRES_USER
POSTGRES_PASSWORD=$CONFIG_POSTGRES_PASSWORD
POSTGRES_DB=$CONFIG_POSTGRES_DB
EOF
    echo "✅ Environment file created"

    # Continue with normal installation process
    echo "📁 Creating directory structure..."
    echo "   - Configuration directories for all services"
    echo "   - Data directories for persistent storage"

    mkdir -p configs/alertmanager
    mkdir -p configs/grafana/provisioning/datasources
    mkdir -p configs/grafana/provisioning/dashboards
    mkdir -p configs/grafana/dashboards
    mkdir -p configs/loki
    mkdir -p configs/nginx/ssl
    mkdir -p configs/postgres
    mkdir -p configs/prometheus
    mkdir -p configs/web
    mkdir -p data/alertmanager
    mkdir -p data/bitwarden
    mkdir -p data/etcd
    mkdir -p data/grafana
    mkdir -p data/loki
    mkdir -p data/postgres
    mkdir -p data/prometheus
    mkdir -p keypair-service
    mkdir -p scanner

    echo "📝 Creating configuration files..."
    echo "   - Prometheus: metrics collection & service discovery"
    echo "   - Grafana: dashboards & Loki datasource"
    echo "   - Alertmanager: MS Teams webhook notifications"
    echo "   - Loki: syslog ingestion on port 1514"
    echo "   - Nginx: reverse proxy with SSL support"

    # Create Prometheus configuration
    cat > configs/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'bitwarden'
    static_configs:
      - targets: ['bitwarden:80']

  - job_name: 'keypair-service'
    static_configs:
      - targets: ['keypair-service:3001']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']

  - job_name: 'etcd'
    static_configs:
      - targets: ['etcd:2379']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # Dynamic targets from etcd (managed by Bitwarden scanner)
  - job_name: 'bitwarden-targets'
    etcd_sd_configs:
      - server: 'etcd:2379'
        prefix: '/prometheus/targets/'
    relabel_configs:
      - source_labels: ['__meta_etcd_key']
        regex: '/prometheus/targets/(.+)/(.+)'
        replacement: '\${1}'
        target_label: 'job'
      - source_labels: ['__meta_etcd_value']
        regex: '(.+)'
        replacement: '\${1}'
        target_label: '__address__'
EOF

    # Create Alertmanager configuration
    cat > configs/alertmanager/alertmanager.yml << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alertmanager@$CONFIG_DOMAIN_MAIN'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'msteams-notifications'
  routes:
  - match:
      alertname: Watchdog
    receiver: 'devnull'
  - match:
      severity: 'critical'
    receiver: 'msteams-critical'
  - match:
      severity: 'warning'
    receiver: 'msteams-warning'

receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'admin@$CONFIG_DOMAIN_MAIN'
    send_resolved: true

- name: 'msteams-notifications'
  webhook_configs:
  - url: 'MSTEAMS_WEBHOOK_URL_PLACEHOLDER'
    send_resolved: true
    http_config:
      content_type: 'application/json'

- name: 'msteams-critical'
  webhook_configs:
  - url: 'MSTEAMS_CRITICAL_WEBHOOK_URL_PLACEHOLDER'
    send_resolved: true
    http_config:
      content_type: 'application/json'

- name: 'msteams-warning'
  webhook_configs:
  - url: 'MSTEAMS_WARNING_WEBHOOK_URL_PLACEHOLDER'
    send_resolved: true
    http_config:
      content_type: 'application/json'

- name: 'devnull'
EOF

    # Create Alertmanager entrypoint script
    cat > configs/alertmanager/entrypoint.sh << 'EOF'
#!/bin/bash

# Alertmanager entrypoint script with MS Teams webhook configuration
# This script substitutes environment variables into the alertmanager.yml config

set -e

CONFIG_FILE="/etc/alertmanager/alertmanager.yml"
TEMP_CONFIG="/tmp/alertmanager.yml"

# Copy the config file
cp "$CONFIG_FILE" "$TEMP_CONFIG"

# Substitute webhook URLs if environment variables are set
if [ -n "$MSTEAMS_WEBHOOK_URL" ]; then
    sed -i "s|MSTEAMS_WEBHOOK_URL_PLACEHOLDER|$MSTEAMS_WEBHOOK_URL|g" "$TEMP_CONFIG"
fi

if [ -n "$MSTEAMS_CRITICAL_WEBHOOK_URL" ]; then
    sed -i "s|MSTEAMS_CRITICAL_WEBHOOK_URL_PLACEHOLDER|$MSTEAMS_CRITICAL_WEBHOOK_URL|g" "$TEMP_CONFIG"
fi

if [ -n "$MSTEAMS_WARNING_WEBHOOK_URL" ]; then
    sed -i "s|MSTEAMS_WARNING_WEBHOOK_URL_PLACEHOLDER|$MSTEAMS_WARNING_WEBHOOK_URL|g" "$TEMP_CONFIG"
fi

# Replace the original config with the processed one
mv "$TEMP_CONFIG" "$CONFIG_FILE"

# Start Alertmanager with the processed configuration
exec /bin/alertmanager "$@"
EOF

    # Create Grafana datasource provisioning
    cat > configs/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
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
    "timezone": "Australia/Sydney",
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
    cat > configs/nginx/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

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
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=auth:10m rate=5r/s;

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
        server_name $CONFIG_DOMAIN_MAIN $CONFIG_DOMAIN_VAULT;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # Grafana
        location /grafana/ {
            proxy_pass http://grafana_backend/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Port \$server_port;

            # WebSocket support for live dashboards
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Prometheus
        location /prometheus/ {
            proxy_pass http://prometheus_backend/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Alert Manager
        location /alertmanager/ {
            proxy_pass http://alertmanager_backend/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Bitwarden Password Manager
        location /vault/ {
            proxy_pass http://bitwarden:80/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Port \$server_port;

            # WebSocket support for real-time sync
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";

            # Additional headers for Bitwarden
            proxy_buffering off;
            proxy_request_buffering off;
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

    # Bitwarden Server Block (HTTP)
    server {
        listen 80;
        server_name $CONFIG_DOMAIN_VAULT;

        # Redirect to HTTPS
        return 301 https://\$host\$request_uri;
    }

    # Bitwarden Server Block (HTTPS)
    server {
        listen 443 ssl http2;
        server_name $CONFIG_DOMAIN_VAULT;

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # Proxy all requests to Bitwarden
        location / {
            proxy_pass http://bitwarden:80/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Port \$server_port;

            # WebSocket support for real-time sync
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";

            # Additional headers for Bitwarden
            proxy_buffering off;
            proxy_request_buffering off;
        }
    }
}
EOF

    echo "🔒 Setting file permissions..."
    echo "   - Configuration files: readable by all"
    echo "   - SSL certificates: secure permissions (key: 600, certs: 644)"
    echo "   - Scripts: executable where needed"

    chmod 600 configs/nginx/ssl/server.key
    chmod 644 configs/nginx/ssl/server.crt
    chmod 644 configs/nginx/ssl/server.csr
    chmod 644 configs/prometheus/prometheus.yml
    chmod 644 configs/alertmanager/alertmanager.yml
    chmod 755 configs/alertmanager/entrypoint.sh
    chmod 644 configs/grafana/provisioning/datasources/prometheus.yml
    chmod 644 configs/grafana/provisioning/dashboards/dashboard.yml
    chmod 644 configs/grafana/dashboards/system-overview.json
    chmod 644 configs/loki/loki-config.yml
    chmod 644 configs/nginx/nginx.conf
    chmod 644 .env.example
    chmod 644 docker-compose.ssl.yml

    echo ""
    echo "📜 Installation Files:"
    echo "   Configuration: $INSTALLER_ENV_FILE (saved for future updates)"
    if [ "$CONFIG_SSL_GENERATE_CERTS" = "yes" ]; then
        echo "   SSL Certificates: configs/nginx/ssl/"
        echo "   ├── server.key (private key - restricted permissions)"
        echo "   ├── server.crt (certificate)"
        echo "   └── server.csr (certificate signing request)"
        echo "   Backup Location: ssl-certificates/"
    fi
    echo ""
    echo "🎉 Installation complete!"
    echo ""
    echo "🚀 Starting services..."

    if [ "$CONFIG_DEPLOY_MODE" = "ssl" ]; then
        echo "🔒 Starting with SSL support..."
        docker-compose -f docker-compose.yml -f docker-compose.ssl.yml up -d
    else
        echo "🌐 Starting in basic mode..."
        docker-compose up -d
    fi

    echo ""
    echo "✅ Deployment complete!"
    echo ""
    echo "🌐 Access your services:"
    echo "   - Grafana: https://$CONFIG_DOMAIN_MAIN/grafana/"
    echo "   - Prometheus: https://$CONFIG_DOMAIN_MAIN/prometheus/"
    echo "   - Alert Manager: https://$CONFIG_DOMAIN_MAIN/alertmanager/"
    echo "   - Loki: http://$CONFIG_DOMAIN_MAIN:3100/"
    echo "   - Bitwarden: https://$CONFIG_DOMAIN_VAULT/"
    echo ""
    echo "📋 Don't forget to update your DNS or /etc/hosts file!"
    echo ""
    echo "🔑 Default credentials:"
    echo "   - Grafana: admin / $CONFIG_GRAFANA_PASSWORD"
    echo "   - Bitwarden: $CONFIG_BITWARDEN_USERNAME / $CONFIG_BITWARDEN_PASSWORD"
    echo ""
    echo "📖 See README.md for detailed documentation"
}

show_fresh_install_welcome() {
    clear
    echo "========================================================================================"
    echo "🏗️  Welcome to Swayn Monitoring Stack Installer"
    echo "========================================================================================"
    echo ""
    echo "This installer will guide you through setting up a complete monitoring stack including:"
    echo ""
    echo "📊 Core Services:"
    echo "   • Prometheus     - Metrics collection & alerting"
    echo "   • Grafana        - Visualization & dashboards"
    echo "   • Alert Manager  - Alert routing & notifications"
    echo "   • Loki          - Log aggregation with syslog support"
    echo ""
    echo "🔧 Supporting Services:"
    echo "   • PostgreSQL     - Database backend"
    echo "   • Bitwarden      - Password management"
    echo "   • etcd           - Service discovery"
    echo "   • Keypair Service- SSH/API key management"
    echo "   • Nginx          - Reverse proxy & SSL termination"
    echo ""
    echo "⚙️  What you'll configure:"
    echo "   • Domain names and SSL certificates"
    echo "   • Service credentials and secrets"
    echo "   • MS Teams notification webhooks"
    echo "   • Deployment mode (SSL or basic)"
    echo ""
    echo "💾 Your configuration will be saved to: installer.env"
    echo "   You can resume this installation at any time."
    echo ""
    echo "Let's get started!"
    echo ""
    read -p "Press Enter to begin configuration..."
}

# Main menu loop
main_menu_loop() {
    # Load existing configuration if available
    local is_resume=$(load_installer_config)

    if [ "$is_resume" -eq 1 ]; then
        # Fresh installation - show welcome screen
        show_fresh_install_welcome
    fi

    while true; do
        show_main_menu
        read choice
        case $choice in
            1) handle_domain_menu ;;
            2) handle_ssl_menu ;;
            3) handle_grafana_menu ;;
            4) handle_postgres_menu ;;
            5) handle_bitwarden_menu ;;
            6) handle_msteams_menu ;;
            7) handle_security_menu ;;
            8)
                # Save configuration before review if this is a fresh install
                if [ ! -f "$INSTALLER_ENV_FILE" ]; then
                    save_installer_config
                    echo "💾 Configuration saved to $INSTALLER_ENV_FILE"
                    echo ""
                fi
                show_review_menu
                read review_choice
                case $review_choice in
                    1)
                        if validate_all_config; then
                            echo ""
                            echo -n "🚀 Are you sure you want to proceed with installation? (y/N): "
                            read confirm
                            if [[ $confirm =~ ^[Yy]$ ]]; then
                                perform_installation
                            fi
                        else
                            echo ""
                            read -p "Press Enter to return to menu..."
                        fi
                        ;;
                    9) ;; # Continue loop
                    *) echo "❌ Invalid option" ;;
                esac
                ;;
            9)
                # Save configuration before installation if this is a fresh install
                if [ ! -f "$INSTALLER_ENV_FILE" ]; then
                    save_installer_config
                    echo "💾 Configuration saved to $INSTALLER_ENV_FILE"
                    echo ""
                fi
                echo "🚀 Proceeding with installation..."
                if validate_all_config; then
                    perform_installation
                else
                    echo ""
                    read -p "Press Enter to return to menu..."
                fi
                ;;
            0)
                echo "👋 Goodbye!"
                exit 0
                ;;
            *)
                echo "❌ Invalid option. Please choose 0-9."
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Start the interactive installer
main_menu_loop
echo "🚀 Setting up Swayn Monitoring directory structure..."

# Create directory structure
echo "📁 Creating directory structure..."
echo "   - Configuration directories for all services"
echo "   - Data directories for persistent storage"
mkdir -p configs/alertmanager
mkdir -p configs/grafana/provisioning/datasources
mkdir -p configs/grafana/provisioning/dashboards
mkdir -p configs/grafana/dashboards
mkdir -p configs/loki
mkdir -p configs/nginx/ssl
mkdir -p configs/postgres
mkdir -p configs/prometheus
mkdir -p configs/web
mkdir -p data/alertmanager
mkdir -p data/bitwarden
mkdir -p data/etcd
mkdir -p data/grafana
mkdir -p data/loki
mkdir -p data/postgres
mkdir -p data/prometheus
mkdir -p keypair-service
mkdir -p scanner
mkdir -p web

echo "🔐 Generating SSL certificates..."
echo "   - Private key: RSA 4096-bit"
echo "   - Certificate: Self-signed for giants.corp.swayn.com, vault.corp.swayn.com"
echo "   - Validity: 365 days"

# Generate SSL private key
openssl genrsa -out configs/nginx/ssl/server.key 4096

# Generate Certificate Signing Request (CSR)
openssl req -new -key configs/nginx/ssl/server.key -out configs/nginx/ssl/server.csr \
  -subj "/C=AU/ST=NSW/L=Sydney/O=Swayn Enterprises/CN=giants.corp.swayn.com"

# Generate self-signed certificate with Subject Alternative Names
openssl x509 -req -in configs/nginx/ssl/server.csr \
  -signkey configs/nginx/ssl/server.key \
  -out configs/nginx/ssl/server.crt \
  -days 365 \
  -extfile <(printf "subjectAltName=DNS:giants.corp.swayn.com,DNS:vault.corp.swayn.com")

echo "✅ SSL certificates generated successfully"

echo "📝 Creating configuration files..."
echo "   - Prometheus: metrics collection & service discovery"
echo "   - Grafana: dashboards & Loki datasource"
echo "   - Alertmanager: MS Teams webhook notifications"
echo "   - Loki: syslog ingestion on port 1514"
echo "   - Nginx: reverse proxy with SSL support"

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
      - targets: ['prometheus:9090']

  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']

  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  - job_name: 'bitwarden'
    static_configs:
      - targets: ['bitwarden:80']

  - job_name: 'keypair-service'
    static_configs:
      - targets: ['keypair-service:3001']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']

  - job_name: 'etcd'
    static_configs:
      - targets: ['etcd:2379']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  # Dynamic targets from etcd (managed by Bitwarden scanner)
  - job_name: 'bitwarden-targets'
    etcd_sd_configs:
      - server: 'etcd:2379'
        prefix: '/prometheus/targets/'
    relabel_configs:
      - source_labels: ['__meta_etcd_key']
        regex: '/prometheus/targets/(.+)/(.+)'
        replacement: '${1}'
        target_label: 'job'
      - source_labels: ['__meta_etcd_value']
        regex: '(.+)'
        replacement: '${1}'
        target_label: '__address__'
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
  receiver: 'msteams-notifications'
  routes:
  - match:
      alertname: Watchdog
    receiver: 'devnull'
  - match:
      severity: 'critical'
    receiver: 'msteams-critical'
  - match:
      severity: 'warning'
    receiver: 'msteams-warning'

receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'admin@swayn-monitoring.local'
    send_resolved: true

- name: 'msteams-notifications'
  webhook_configs:
  - url: 'MSTEAMS_WEBHOOK_URL_PLACEHOLDER'
    send_resolved: true
    http_config:
      content_type: 'application/json'

- name: 'msteams-critical'
  webhook_configs:
  - url: 'MSTEAMS_CRITICAL_WEBHOOK_URL_PLACEHOLDER'
    send_resolved: true
    http_config:
      content_type: 'application/json'

- name: 'msteams-warning'
  webhook_configs:
  - url: 'MSTEAMS_WARNING_WEBHOOK_URL_PLACEHOLDER'
    send_resolved: true
    http_config:
      content_type: 'application/json'

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

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
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
        server_name giants.corp.swayn.com vault.corp.swayn.com;

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

        # Bitwarden Password Manager
        location /vault/ {
            proxy_pass http://bitwarden:80/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;

            # WebSocket support for real-time sync
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            # Additional headers for Bitwarden
            proxy_buffering off;
            proxy_request_buffering off;
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

    # Bitwarden Server Block (HTTP)
    server {
        listen 80;
        server_name vault.corp.swayn.com;

        # Redirect to HTTPS
        return 301 https://$host$request_uri;
    }

    # Bitwarden Server Block (HTTPS)
    server {
        listen 443 ssl http2;
        server_name vault.corp.swayn.com;

        # SSL configuration
        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

        # Proxy all requests to Bitwarden
        location / {
            proxy_pass http://bitwarden:80/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;

            # WebSocket support for real-time sync
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            # Additional headers for Bitwarden
            proxy_buffering off;
            proxy_request_buffering off;
        }
    }
}
EOF

    # Create Loki configuration
    cat > configs/loki/loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://alertmanager:9093

analytics:
  reporting_enabled: false

# Syslog configuration for TCP and UDP on port 1514
syslog:
  enabled: true
  listen_address: 0.0.0.0:1514
  listen_protocol: tcp
  mode: syslog
  label_structured_data: yes
  label_client_info: yes

# Additional syslog listener for UDP
syslog_udp:
  enabled: true
  listen_address: 0.0.0.0:1514
  listen_protocol: udp
  mode: syslog
  label_structured_data: yes
  label_client_info: yes
EOF

    # Create .env file with configured values
    cat > .env << EOF
# Grafana Admin Password
GF_ADMIN_PASSWORD=$CONFIG_GRAFANA_PASSWORD

# Bitwarden Configuration
BITWARDEN_ADMIN_TOKEN=$CONFIG_BITWARDEN_ADMIN_TOKEN
BITWARDEN_USERNAME=$CONFIG_BITWARDEN_USERNAME
BITWARDEN_PASSWORD=$CONFIG_BITWARDEN_PASSWORD

# Microsoft Teams Webhook URLs for Alertmanager
MSTEAMS_WEBHOOK_URL=$CONFIG_MSTEAMS_WEBHOOK
MSTEAMS_CRITICAL_WEBHOOK_URL=$CONFIG_MSTEAMS_CRITICAL_WEBHOOK
MSTEAMS_WARNING_WEBHOOK_URL=$CONFIG_MSTEAMS_WARNING_WEBHOOK

# Keypair Service Configuration
JWT_SECRET=$CONFIG_JWT_SECRET

# SSL certificates are automatically generated
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
echo "🔒 Setting file permissions..."
echo "   - Configuration files: readable by all"
echo "   - SSL certificates: secure permissions (key: 600, certs: 644)"
echo "   - Scripts: executable where needed"

# SSL certificate permissions (private key should be restricted)
chmod 600 configs/nginx/ssl/server.key
chmod 644 configs/nginx/ssl/server.crt
chmod 644 configs/nginx/ssl/server.csr

# Configuration files
chmod 644 configs/prometheus/prometheus.yml
chmod 644 configs/alertmanager/alertmanager.yml
chmod 755 configs/alertmanager/entrypoint.sh
chmod 644 configs/grafana/provisioning/datasources/prometheus.yml
chmod 644 configs/grafana/provisioning/dashboards/dashboard.yml
chmod 644 configs/grafana/dashboards/system-overview.json
chmod 644 configs/loki/loki-config.yml
chmod 644 configs/nginx/nginx.conf
chmod 644 .env.example
chmod 644 docker-compose.ssl.yml

echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo ""
echo "🔧 Domain Setup:"
echo "Add to /etc/hosts (replace 127.0.0.1 with your server IP if remote):"
echo "127.0.0.1 giants.corp.swayn.com vault.corp.swayn.com"
echo ""
echo "⚙️ Configuration:"
echo "1. Copy .env.example to .env and configure your settings:"
echo "   cp .env.example .env"
echo ""
echo "   SSL certificates are automatically generated:"
echo "   - RSA 4096-bit private key"
echo "   - Self-signed certificate for giants.corp.swayn.com and vault.corp.swayn.com"
echo "   - Valid for 365 days"
echo ""
echo "2. Generate secure tokens and passwords:"
echo "   - BITWARDEN_ADMIN_TOKEN: openssl rand -base64 32"
echo "   - JWT_SECRET: openssl rand -base64 32"
echo "   - Set secure passwords for Grafana admin and PostgreSQL"
echo ""
echo "3. Configure Bitwarden credentials for the scanner:"
echo "   - BITWARDEN_USERNAME: your_bitwarden_username"
echo "   - BITWARDEN_PASSWORD: your_bitwarden_password"
echo ""
echo "🚀 Start Services:"
echo "# Start with SSL (recommended):"
echo "docker-compose -f docker-compose.yml -f docker-compose.ssl.yml up -d"
echo ""
echo "# Or start without SSL (development only):"
echo "docker-compose up -d"
echo ""
echo "🌐 Access Services:"
echo "📊 Monitoring Stack:"
echo "   - Grafana: https://giants.corp.swayn.com/grafana/"
echo "   - Prometheus: https://giants.corp.swayn.com/prometheus/"
echo "   - Alert Manager: https://giants.corp.swayn.com/alertmanager/"
echo "   - Loki: http://giants.corp.swayn.com:3100/"
echo ""
echo "🔐 Security & Management:"
echo "   - Bitwarden: https://vault.corp.swayn.com/"
echo "   - Keypair Service API: http://giants.corp.swayn.com:3001/api/"
echo ""
echo "💾 Databases (internal access):"
echo "   - PostgreSQL: giants.corp.swayn.com:5432 (monitoring/monitoring_user/monitoring_pass)"
echo "   - etcd: giants.corp.swayn.com:2379"
echo ""
echo "🔍 Health Check:"
echo "curl https://giants.corp.swayn.com/health"
echo ""
echo "📖 Documentation:"
echo "See README.md for detailed configuration and usage instructions"
echo ""
echo "⚠️  Security Notes:"
echo "- Change all default passwords in production"
echo "- SSL certificates are self-signed for development"
echo "- Configure proper DNS for production deployment"
echo ""
echo "📜 Generated Files:"
echo "   SSL Certificates: configs/nginx/ssl/"
echo "   ├── server.key (private key - restricted permissions)"
echo "   ├── server.crt (certificate)"
echo "   └── server.csr (certificate signing request)"
echo ""
echo "🔍 Certificate Details:"
echo "   - Algorithm: RSA 4096-bit"
echo "   - Domains: giants.corp.swayn.com, vault.corp.swayn.com"
echo "   - Validity: 365 days"
echo "   - Type: Self-signed (development)"
echo ""
echo "🎉 Setup complete! Your monitoring stack is ready."