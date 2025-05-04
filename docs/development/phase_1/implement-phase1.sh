#!/usr/bin/env bash

# DIY Cloud Platform - Phase 1 Implementation Script
# This script implements Phase 1 (Foundation) of the DIY Cloud Platform

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Set the base directory for the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"

# Source the Distribution Abstraction Layer
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/package_manager.sh"
source "${BASE_DIR}/service_manager.sh"
source "${BASE_DIR}/path_resolver.sh"
source "${BASE_DIR}/common.sh"

# Set up directories
CORE_DIR="/opt/diycloud/core"
NGINX_DIR="${CORE_DIR}/nginx"
PORTAL_DIR="${CORE_DIR}/portal"
SSL_DIR="${CORE_DIR}/ssl"
WEB_ROOT="/var/www/diycloud"

# Print header
echo "=== DIY Cloud Platform - Phase 1 Implementation ==="
echo "Distribution: ${DISTRO} ${DISTRO_VERSION} (${DISTRO_FAMILY} family)"
echo "Package manager: ${PACKAGE_MANAGER}"
echo "Service manager: ${SERVICE_MANAGER}"
echo "Running on: $(hostname) ($(get_primary_ip))"
echo "Date: $(date)"
echo ""

# Function to run a specific implementation step
run_step() {
    local step_name="$1"
    local step_function="$2"
    
    echo -e "\nStep: ${step_name}"
    echo "Running ${step_name}..."
    
    # Run the step function
    ${step_function}
    local result=$?
    
    # Check the result
    if [[ ${result} -eq 0 ]]; then
        echo "✓ Step completed successfully: ${step_name}"
        return 0
    else
        echo "✗ Step failed: ${step_name}"
        return 1
    fi
}

# Step 1: Create directories
create_directories() {
    log_message "Creating directories..." "info"
    
    # Create core directories
    ensure_directory "${CORE_DIR}" "root:root" "755"
    ensure_directory "${NGINX_DIR}" "root:root" "755"
    ensure_directory "${PORTAL_DIR}" "root:root" "755"
    ensure_directory "${SSL_DIR}" "root:root" "755"
    
    # Create subdirectories
    ensure_directory "${PORTAL_DIR}/css" "root:root" "755"
    ensure_directory "${PORTAL_DIR}/js" "root:root" "755"
    ensure_directory "${PORTAL_DIR}/assets" "root:root" "755"
    
    return 0
}

# Step 2: Setup base system
setup_base_system() {
    log_message "Setting up base system..." "info"
    
    # Update package lists
    log_message "Updating package lists..." "info"
    update_package_lists
    check_result $? "Package lists updated successfully" "Failed to update package lists"
    
    # Install required packages
    log_message "Installing required packages..." "info"
    
    log_message "Installing Nginx..." "info"
    install_package "nginx"
    check_result $? "Nginx installed successfully" "Failed to install Nginx"
    
    log_message "Installing OpenSSL..." "info"
    install_package "openssl"
    check_result $? "OpenSSL installed successfully" "Failed to install OpenSSL"
    
    log_message "Installing cURL..." "info"
    install_package "curl"
    check_result $? "cURL installed successfully" "Failed to install cURL"
    
    log_message "Installing CA Certificates..." "info"
    install_package "ca-certificates"
    check_result $? "CA Certificates installed successfully" "Failed to install CA Certificates"
    
    log_message "Installing Logrotate..." "info"
    install_package "logrotate"
    check_result $? "Logrotate installed successfully" "Failed to install Logrotate"
    
    # Create necessary directories
    log_message "Creating necessary directories..." "info"
    
    log_message "Creating ${WEB_ROOT}..." "info"
    ensure_directory "${WEB_ROOT}" "www-data:www-data" "755"
    check_result $? "${WEB_ROOT} created successfully" "Failed to create ${WEB_ROOT}"
    
    log_message "Creating /etc/diycloud..." "info"
    ensure_directory "/etc/diycloud" "root:root" "755"
    check_result $? "/etc/diycloud created successfully" "Failed to create /etc/diycloud"
    
    log_message "Creating /var/log/diycloud..." "info"
    ensure_directory "/var/log/diycloud" "root:root" "755"
    check_result $? "/var/log/diycloud created successfully" "Failed to create /var/log/diycloud"
    
    # Configure firewall if available
    log_message "Configuring firewall..." "info"
    
    if command_exists "ufw"; then
        log_message "Configuring UFW firewall..." "info"
        ufw allow 80/tcp
        ufw allow 443/tcp
        check_result $? "UFW configured successfully" "Failed to configure UFW"
    elif command_exists "firewalld"; then
        log_message "Configuring FirewallD..." "info"
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        check_result $? "FirewallD configured successfully" "Failed to configure FirewallD"
    elif command_exists "iptables"; then
        log_message "Configuring iptables..." "info"
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        check_result $? "iptables configured successfully" "Failed to configure iptables"
    else
        log_message "No supported firewall found, skipping firewall configuration" "warning"
    fi
    
    # Create logrotate configuration
    log_message "Setting up logrotate configuration..." "info"
    cat > "/etc/logrotate.d/diycloud" << EOF
/var/log/diycloud/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 \$(cat /var/run/nginx.pid)
        fi
    endscript
}
EOF
    check_result $? "Logrotate configuration created successfully" "Failed to create logrotate configuration"
    
    # Create setup-base.sh script
    log_message "Creating setup-base.sh script..." "info"
    cat > "${CORE_DIR}/setup-base.sh" << 'EOF'
#!/usr/bin/env bash

# DIY Cloud Platform - Base System Setup Script
# This script sets up the base system for the DIY Cloud Platform

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Set the base directory for the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"

# Source the Distribution Abstraction Layer
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/package_manager.sh"
source "${BASE_DIR}/service_manager.sh"
source "${BASE_DIR}/path_resolver.sh"
source "${BASE_DIR}/common.sh"

# Function to setup base system
setup_base_system() {
    log_message "Setting up base system..." "info"
    log_message "Distribution: ${DISTRO} ${DISTRO_VERSION} (${DISTRO_FAMILY} family)" "info"
    
    # Update package lists
    log_message "Updating package lists..." "info"
    update_package_lists
    check_result $? "Package lists updated successfully" "Failed to update package lists"
    
    # Install required packages
    log_message "Installing required packages..." "info"
    
    log_message "Installing Nginx..." "info"
    install_package "nginx"
    check_result $? "Nginx installed successfully" "Failed to install Nginx"
    
    log_message "Installing OpenSSL..." "info"
    install_package "openssl"
    check_result $? "OpenSSL installed successfully" "Failed to install OpenSSL"
    
    log_message "Installing cURL..." "info"
    install_package "curl"
    check_result $? "cURL installed successfully" "Failed to install cURL"
    
    log_message "Installing CA Certificates..." "info"
    install_package "ca-certificates"
    check_result $? "CA Certificates installed successfully" "Failed to install CA Certificates"
    
    log_message "Installing Logrotate..." "info"
    install_package "logrotate"
    check_result $? "Logrotate installed successfully" "Failed to install Logrotate"
    
    # Create necessary directories
    log_message "Creating necessary directories..." "info"
    
    log_message "Creating /var/www/diycloud..." "info"
    ensure_directory "/var/www/diycloud" "www-data:www-data" "755"
    check_result $? "/var/www/diycloud created successfully" "Failed to create /var/www/diycloud"
    
    log_message "Creating /etc/diycloud..." "info"
    ensure_directory "/etc/diycloud" "root:root" "755"
    check_result $? "/etc/diycloud created successfully" "Failed to create /etc/diycloud"
    
    log_message "Creating /var/log/diycloud..." "info"
    ensure_directory "/var/log/diycloud" "root:root" "755"
    check_result $? "/var/log/diycloud created successfully" "Failed to create /var/log/diycloud"
    
    # Configure firewall if available
    log_message "Configuring firewall..." "info"
    
    if command_exists "ufw"; then
        log_message "Configuring UFW firewall..." "info"
        ufw allow 80/tcp
        ufw allow 443/tcp
        check_result $? "UFW configured successfully" "Failed to configure UFW"
    elif command_exists "firewalld"; then
        log_message "Configuring FirewallD..." "info"
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
        check_result $? "FirewallD configured successfully" "Failed to configure FirewallD"
    elif command_exists "iptables"; then
        log_message "Configuring iptables..." "info"
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        check_result $? "iptables configured successfully" "Failed to configure iptables"
    else
        log_message "No supported firewall found, skipping firewall configuration" "warning"
    fi
    
    # Create logrotate configuration
    log_message "Setting up logrotate configuration..." "info"
    cat > "/etc/logrotate.d/diycloud" << EOF
/var/log/diycloud/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        if [ -f /var/run/nginx.pid ]; then
            kill -USR1 \$(cat /var/run/nginx.pid)
        fi
    endscript
}
EOF
    check_result $? "Logrotate configuration created successfully" "Failed to create logrotate configuration"
    
    log_message "Base system setup completed successfully" "info"
    return 0
}

# Execute the function
setup_base_system
exit $?
EOF
    chmod +x "${CORE_DIR}/setup-base.sh"
    check_result $? "setup-base.sh script created successfully" "Failed to create setup-base.sh script"
    
    log_message "Base system setup completed successfully" "info"
    return 0
}

# Step 3: Configure Nginx
configure_nginx() {
    log_message "Configuring Nginx..." "info"
    
    # Get Nginx configuration paths
    NGINX_CONF=$(get_config_path "nginx")
    NGINX_SITES=$(get_config_path "nginx_sites")
    NGINX_ENABLED=$(get_config_path "nginx_enabled")
    
    log_message "Nginx config path: ${NGINX_CONF}" "info"
    log_message "Nginx sites path: ${NGINX_SITES}" "info"
    log_message "Nginx enabled path: ${NGINX_ENABLED}" "info"
    
    # Create Nginx configuration files
    log_message "Creating Nginx configuration files..." "info"
    
    # Backup original nginx.conf if it exists
    if [[ -f "${NGINX_CONF}/nginx.conf" ]]; then
        backup_file "${NGINX_CONF}/nginx.conf"
        check_result $? "Original nginx.conf backed up successfully" "Failed to backup original nginx.conf"
    fi
    
    # Create main Nginx configuration
    log_message "Creating main Nginx configuration..." "info"
    cat > "${NGINX_DIR}/nginx.conf" << EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include ${NGINX_CONF}/modules-enabled/*.conf;

events {
    worker_connections 768;
    # multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # MIME
    include ${NGINX_CONF}/mime.types;
    default_type application/octet-stream;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Logging Settings
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip Settings
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Virtual Host Configs
    include ${NGINX_CONF}/conf.d/*.conf;
    include ${NGINX_CONF}/sites-enabled/*;
}
EOF
    check_result $? "Main Nginx configuration created successfully" "Failed to create main Nginx configuration"
    
    # Copy main Nginx configuration
    cp "${NGINX_DIR}/nginx.conf" "${NGINX_CONF}/nginx.conf"
    check_result $? "Main Nginx configuration copied successfully" "Failed to copy main Nginx configuration"
    
    # Create SSL parameters configuration
    log_message "Creating SSL parameters configuration..." "info"
    cat > "${NGINX_DIR}/ssl-params.conf" << EOF
# SSL parameters
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;

# HSTS (comment out if not using HTTPS only)
add_header Strict-Transport-Security "max-age=63072000" always;

# Security headers
add_header X-Frame-Options SAMEORIGIN;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy no-referrer-when-downgrade;
EOF
    check_result $? "SSL parameters configuration created successfully" "Failed to create SSL parameters configuration"
    
    # Copy SSL parameters configuration
    cp "${NGINX_DIR}/ssl-params.conf" "${NGINX_CONF}/ssl-params.conf"
    check_result $? "SSL parameters configuration copied successfully" "Failed to copy SSL parameters configuration"
    
    # Create web portal virtual host configuration
    log_message "Creating web portal virtual host configuration..." "info"
    cat > "${NGINX_DIR}/diycloud.conf" << EOF
server {
    listen 80;
    server_name _;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/diycloud.crt;
    ssl_certificate_key /etc/ssl/private/diycloud.key;
    include ${NGINX_CONF}/ssl-params.conf;
    
    root /var/www/diycloud;
    index index.html;
    
    # Web portal location
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Placeholder for JupyterHub (future phase)
    location /jupyter/ {
        return 503;
    }
    
    # Placeholder for Portainer (future phase)
    location /portainer/ {
        return 503;
    }
    
    # Placeholder for Monitoring (future phase)
    location /monitoring/ {
        return 503;
    }
    
    # Custom error pages
    error_page 503 /503.html;
    location = /503.html {
        root /var/www/diycloud;
    }
}
EOF
    check_result $? "Web portal virtual host configuration created successfully" "Failed to create web portal virtual host configuration"
    
    # Copy web portal virtual host configuration
    cp "${NGINX_DIR}/diycloud.conf" "${NGINX_SITES}/diycloud.conf"
    check_result $? "Web portal virtual host configuration copied successfully" "Failed to copy web portal virtual host configuration"
    
    # Create configure-nginx.sh script
    log_message "Creating configure-nginx.sh script..." "info"
    cat > "${NGINX_DIR}/configure-nginx.sh" << 'EOF'
#!/usr/bin/env bash

# DIY Cloud Platform - Nginx Configuration Script
# This script configures Nginx for the DIY Cloud Platform

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Set the base directory for the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"

# Source the Distribution Abstraction Layer
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/package_manager.sh"
source "${BASE_DIR}/service_manager.sh"
source "${BASE_DIR}/path_resolver.sh"
source "${BASE_DIR}/common.sh"

# Get Nginx configuration paths
NGINX_CONF=$(get_config_path "nginx")
NGINX_SITES=$(get_config_path "nginx_sites")
NGINX_ENABLED=$(get_config_path "nginx_enabled")

# Function to configure Nginx
configure_nginx() {
    log_message "Configuring Nginx..." "info"
    log_message "Nginx config path: ${NGINX_CONF}" "info"
    log_message "Nginx sites path: ${NGINX_SITES}" "info"
    log_message "Nginx enabled path: ${NGINX_ENABLED}" "info"
    
    # Create Nginx configuration files
    log_message "Creating Nginx configuration files..." "info"
    
    # Backup original nginx.conf if it exists
    if [[ -f "${NGINX_CONF}/nginx.conf" ]]; then
        backup_file "${NGINX_CONF}/nginx.conf"
        check_result $? "Original nginx.conf backed up successfully" "Failed to backup original nginx.conf"
    fi
    
    # Create main Nginx configuration
    log_message "Creating main Nginx configuration..." "info"
    cat > "${NGINX_CONF}/nginx.conf" << EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include ${NGINX_CONF}/modules-enabled/*.conf;

events {
    worker_connections 768;
    # multi_accept on;
}

http {
    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # MIME
    include ${NGINX_CONF}/mime.types;
    default_type application/octet-stream;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Logging Settings
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip Settings
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Virtual Host Configs
    include ${NGINX_CONF}/conf.d/*.conf;
    include ${NGINX_CONF}/sites-enabled/*;
}
EOF
    check_result $? "Main Nginx configuration created successfully" "Failed to create main Nginx configuration"
    
    # Create SSL parameters configuration
    log_message "Creating SSL parameters configuration..." "info"
    cat > "${NGINX_CONF}/ssl-params.conf" << EOF
# SSL parameters
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;

# HSTS (comment out if not using HTTPS only)
add_header Strict-Transport-Security "max-age=63072000" always;

# Security headers
add_header X-Frame-Options SAMEORIGIN;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy no-referrer-when-downgrade;
EOF
    check_result $? "SSL parameters configuration created successfully" "Failed to create SSL parameters configuration"
    
    # Create web portal virtual host configuration
    log_message "Creating web portal virtual host configuration..." "info"
    cat > "${NGINX_SITES}/diycloud.conf" << EOF
server {
    listen 80;
    server_name _;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/diycloud.crt;
    ssl_certificate_key /etc/ssl/private/diycloud.key;
    include ${NGINX_CONF}/ssl-params.conf;
    
    root /var/www/diycloud;
    index index.html;
    
    # Web portal location
    location / {
        try_files \$uri \$uri/ =404;
    }
    
    # Placeholder for JupyterHub (future phase)
    location /jupyter/ {
        return 503;
    }
    
    # Placeholder for Portainer (future phase)
    location /portainer/ {
        return 503;
    }
    
    # Placeholder for Monitoring (future phase)
    location /monitoring/ {
        return 503;
    }
    
    # Custom error pages
    error_page 503 /503.html;
    location = /503.html {
        root /var/www/diycloud;
    }
}
EOF
    check_result $? "Web portal virtual host configuration created successfully" "Failed to create web portal virtual host configuration"
    
    # Enable the portal site
    log_message "Enabling portal site..." "info"
    if [[ "${NGINX_SITES}" != "${NGINX_ENABLED}" ]]; then
        # For Debian-style with sites-available and sites-enabled
        if [[ -L "${NGINX_ENABLED}/default" ]]; then
            log_message "Disabling default site..." "info"
            rm -f "${NGINX_ENABLED}/default"
        fi
        ln -sf "${NGINX_SITES}/diycloud.conf" "${NGINX_ENABLED}/diycloud.conf"
        check_result $? "Portal site enabled successfully" "Failed to enable portal site"
    fi
    
    # Test Nginx configuration
    log_message "Testing Nginx configuration..." "info"
    nginx -t
    check_result $? "Nginx configuration test passed" "Nginx configuration test failed"
    
    # Restart Nginx
    log_message "Restarting Nginx..." "info"
    restart_service "nginx"
    check_result $? "Nginx restarted successfully" "Failed to restart Nginx"
    
    # Check if Nginx is running
    if is_service_active "nginx"; then
        log_message "Nginx is running successfully" "info"
    else
        log_message "Nginx is not running" "error"
        return 1
    fi
    
    log_message "Nginx configuration completed successfully" "info"
    return 0
}

# Execute the function
configure_nginx
exit $?
EOF
    chmod +x "${NGINX_DIR}/configure-nginx.sh"
    check_result $? "configure-nginx.sh script created successfully" "Failed to create configure-nginx.sh script"
    
    # Enable the portal site
    log_message "Enabling portal site..." "info"
    if [[ "${NGINX_SITES}" != "${NGINX_ENABLED}" ]]; then
        # For Debian-style with sites-available and sites-enabled
        if [[ -L "${NGINX_ENABLED}/default" ]]; then
            log_message "Disabling default site..." "info"
            rm -f "${NGINX_ENABLED}/default"
        fi
        ln -sf "${NGINX_SITES}/diycloud.conf" "${NGINX_ENABLED}/diycloud.conf"
        check_result $? "Portal site enabled successfully" "Failed to enable portal site"
    fi
    
    log_message "Nginx configuration completed successfully" "info"
    return 0
}

# Step 4: Setup SSL certificates
setup_ssl_certificates() {
    log_message "Setting up SSL certificates..." "info"
    
    # Create SSL certificate generation script
    log_message "Creating SSL certificate generation script..." "info"
    cat > "${SSL_DIR}/generate-ssl.sh" << 'EOF'
#!/usr/bin/env bash

# DIY Cloud Platform - SSL Certificate Generation Script
# This script generates SSL certificates for the DIY Cloud Platform

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Set the base directory for the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"

# Source the Distribution Abstraction Layer
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/common.sh"

# Default values
DOMAIN=$(hostname -f)
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
DAYS=365
USE_LETSENCRYPT=false
EMAIL=""

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate SSL certificates for DIY Cloud Platform"
    echo ""
    echo "Options:"
    echo "  --domain DOMAIN       Domain name for the certificate (default: $(hostname -f))"
    echo "  --days DAYS           Validity period in days (default: 365)"
    echo "  --lets-encrypt        Use Let's Encrypt instead of self-signed certificate"
    echo "  --email EMAIL         Email address for Let's Encrypt registration"
    echo "  --help                Show this help message"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --domain)
        DOMAIN="$2"
        shift
        shift
        ;;
        --days)
        DAYS="$2"
        shift
        shift
        ;;
        --lets-encrypt)
        USE_LETSENCRYPT=true
        shift
        ;;
        --email)
        EMAIL="$2"
        shift
        shift
        ;;
        --help)
        usage
        ;;
        *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

# Function to generate self-signed certificate
generate_self_signed() {
    log_message "Generating self-signed SSL certificate for ${DOMAIN}" "info"
    
    # Create directories if they don't exist
    ensure_directory "${CERT_DIR}" "root:root" "755"
    ensure_directory "${KEY_DIR}" "root:root" "710"
    
    # Generate self-signed certificate
    log_message "Running OpenSSL to generate certificate..." "info"
    openssl req -x509 -nodes -days ${DAYS} -newkey rsa:2048 \
        -keyout "${KEY_DIR}/diycloud.key" \
        -out "${CERT_DIR}/diycloud.crt" \
        -subj "/CN=${DOMAIN}" \
        -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost,IP:127.0.0.1"
    
    check_result $? "Certificate generated successfully" "Failed to generate certificate"
    
    # Set appropriate permissions
    chmod 600 "${KEY_DIR}/diycloud.key"
    chmod 644 "${CERT_DIR}/diycloud.crt"
    
    # Verify certificate
    log_message "Verifying certificate..." "info"
    openssl x509 -in "${CERT_DIR}/diycloud.crt" -text -noout | grep -E 'Subject:|Issuer:|Not Before:|Not After :|DNS:'
    
    log_message "Self-signed SSL certificate generation completed" "info"
    log_message "Certificate: ${CERT_DIR}/diycloud.crt" "info"
    log_message "Private key: ${KEY_DIR}/diycloud.key" "info"
    
    return 0
}

# Function to generate Let's Encrypt certificate
generate_letsencrypt() {
    log_message "Setting up Let's Encrypt SSL certificate for ${DOMAIN}" "info"
    
    # Check if email is provided
    if [[ -z "${EMAIL}" ]]; then
        log_message "Email address is required for Let's Encrypt" "error"
        return 1
    fi
    
    # Install certbot based on the distribution
    log_message "Installing certbot..." "info"
    case "${DISTRO_FAMILY}" in
        debian)
            install_package "certbot"
            install_package "python3-certbot-nginx"
            ;;
        redhat)
            install_package "certbot"
            install_package "python3-certbot-nginx"
            ;;
        arch)
            install_package "certbot"
            install_package "certbot-nginx"
            ;;
        suse)
            install_package "certbot"
            install_package "python-certbot-nginx"
            ;;
        *)
            log_message "Unsupported distribution family: ${DISTRO_FAMILY}" "error"
            return 1
            ;;
    esac
    
    # Check if Nginx is installed and running
    if ! is_package_installed "nginx"; then
        log_message "Nginx is not installed" "error"
        return 1
    fi
    
    if ! is_service_active "nginx"; then
        log_message "Nginx is not running" "error"
        return 1
    fi
    
    # Obtain and install certificate
    log_message "Obtaining certificate for ${DOMAIN}..." "info"
    certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --email "${EMAIL}" --redirect
    
    # Verify certificate installation
    if [[ $? -eq 0 ]]; then
        log_message "Let's Encrypt certificate installed successfully" "info"
    else
        log_message "Failed to install Let's Encrypt certificate" "error"
        return 1
    fi
    
    # Set up automatic renewal
    log_message "Setting up automatic renewal..." "info"
    echo "0 3 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew
    chmod 644 /etc/cron.d/certbot-renew
    
    log_message "Let's Encrypt setup completed" "info"
    return 0
}

# Main function
main() {
    log_message "Starting SSL certificate generation..." "info"
    
    # Check if OpenSSL is installed
    if ! command_exists "openssl"; then
        log_message "OpenSSL is not installed" "error"
        exit 1
    fi
    
    # Generate certificate based on settings
    if [[ "${USE_LETSENCRYPT}" == "true" ]]; then
        generate_letsencrypt
    else
        generate_self_signed
    fi
    
    exit $?
}

# Run the main function
main
EOF
    chmod +x "${SSL_DIR}/generate-ssl.sh"
    check_result $? "SSL certificate generation script created successfully" "Failed to create SSL certificate generation script"
    
    # Generate self-signed certificate
    log_message "Generating self-signed SSL certificate..." "info"
    "${SSL_DIR}/generate-ssl.sh" --domain "$(hostname -f)"
    check_result $? "SSL certificate generated successfully" "Failed to generate SSL certificate"
    
    log_message "SSL certificate setup completed successfully" "info"
    return 0
}

# Step 5: Setup web portal
setup_web_portal() {
    log_message "Setting up web portal..." "info"
    
    # Create web portal files
    log_message "Creating web portal files..." "info"
    
    # Create index.html
    log_message "Creating index.html..." "info"
    cat > "${PORTAL_DIR}/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DIY Cloud Platform</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <header>
        <div class="logo">
            <img src="assets/logo.png" alt="DIY Cloud Platform">
            <h1>DIY Cloud Platform</h1>
        </div>
        <nav>
            <ul>
                <li><a href="/" class="active">Home</a></li>
                <li><a href="/jupyter/">JupyterHub</a></li>
                <li><a href="/portainer/">Portainer</a></li>
                <li><a href="/monitoring/">Monitoring</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <section class="hero">
            <h2>Welcome to your self-hosted cloud platform</h2>
            <p>Share your computational resources with others through JupyterHub notebooks and Docker containers.</p>
        </section>
        
        <section class="services">
            <div class="service-card">
                <h3>JupyterHub</h3>
                <p>Python notebooks for data science and machine learning.</p>
                <a href="/jupyter/" class="button">Access JupyterHub</a>
            </div>
            
            <div class="service-card">
                <h3>Docker & Portainer</h3>
                <p>Container management for your applications.</p>
                <a href="/portainer/" class="button">Access Portainer</a>
            </div>
            
            <div class="service-card">
                <h3>Monitoring</h3>
                <p>System and user activity monitoring.</p>
                <a href="/monitoring/" class="button">View Monitoring</a>
            </div>
        </section>
        
        <section class="system-status">
            <h3>System Status</h3>
            <div id="status-indicators">
                <!-- JavaScript will populate this section -->
            </div>
        </section>
    </main>
    
    <footer>
        <p>&copy; 2025 DIY Cloud Platform</p>
    </footer>
    
    <script src="js/scripts.js"></script>
</body>
</html>
EOF
    check_result $? "index.html created successfully" "Failed to create index.html"
    
    # Create style.css
    log_message "Creating style.css..." "info"
    cat > "${PORTAL_DIR}/css/style.css" << 'EOF'
/* Reset and Base Styles */
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    line-height: 1.6;
    color: #333;
    background-color: #f9f9f9;
}

a {
    color: #0066cc;
    text-decoration: none;
}

a:hover {
    text-decoration: underline;
}

/* Header Styles */
header {
    background-color: #fff;
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
    padding: 1rem 2rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.logo {
    display: flex;
    align-items: center;
}

.logo img {
    height: 40px;
    margin-right: 1rem;
}

.logo h1 {
    font-size: 1.5rem;
    color: #333;
}

nav ul {
    display: flex;
    list-style: none;
}

nav ul li {
    margin-left: 2rem;
}

nav ul li a {
    color: #666;
    font-weight: 500;
    transition: color 0.3s;
}

nav ul li a:hover, nav ul li a.active {
    color: #0066cc;
    text-decoration: none;
}

/* Main Content Styles */
main {
    max-width: 1200px;
    margin: 0 auto;
    padding: 2rem;
}

.hero {
    text-align: center;
    margin-bottom: 3rem;
}

.hero h2 {
    font-size: 2.5rem;
    margin-bottom: 1rem;
    color: #222;
}

.hero p {
    font-size: 1.2rem;
    color: #666;
    max-width: 800px;
    margin: 0 auto;
}

/* Service Cards */
.services {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 2rem;
    margin-bottom: 3rem;
}

.service-card {
    background-color: #fff;
    border-radius: 8px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
    padding: 2rem;
    text-align: center;
    transition: transform 0.3s, box-shadow 0.3s;
}

.service-card:hover {
    transform: translateY(-5px);
    box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1);
}

.service-card h3 {
    margin-bottom: 1rem;
    color: #0066cc;
}

.service-card p {
    margin-bottom: 1.5rem;
    color: #666;
}

.button {
    display: inline-block;
    background-color: #0066cc;
    color: white;
    padding: 0.5rem 1.5rem;
    border-radius: 4px;
    font-weight: 500;
    transition: background-color 0.3s;
}

.button:hover {
    background-color: #0055aa;
    text-decoration: none;
}

/* System Status Section */
.system-status {
    background-color: #fff;
    border-radius: 8px;
    box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
    padding: 2rem;
}

.system-status h3 {
    margin-bottom: 1.5rem;
    color: #333;
}

#status-indicators {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
}

.status-item {
    display: flex;
    align-items: center;
    margin-bottom: 0.5rem;
}

.status-indicator {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    margin-right: 8px;
}

.status-green {
    background-color: #4CAF50;
}

.status-yellow {
    background-color: #FFC107;
}

.status-red {
    background-color: #F44336;
}

/* Footer Styles */
footer {
    background-color: #333;
    color: #fff;
    text-align: center;
    padding: 1.5rem;
    margin-top: 3rem;
}

/* Responsive Styles */
@media (max-width: 768px) {
    header {
        flex-direction: column;
        padding: 1rem;
    }
    
    .logo {
        margin-bottom: 1rem;
    }
    
    nav ul {
        flex-wrap: wrap;
        justify-content: center;
    }
    
    nav ul li {
        margin: 0.5rem;
    }
    
    .hero h2 {
        font-size: 2rem;
    }
    
    .services {
        grid-template-columns: 1fr;
    }
}

/* Error Page Styles */
.error-container {
    text-align: center;
    padding: 3rem 1rem;
}

.error-code {
    font-size: 6rem;
    color: #0066cc;
    margin-bottom: 1rem;
}

.error-message {
    font-size: 1.5rem;
    margin-bottom: 2rem;
}

.back-button {
    display: inline-block;
    background-color: #0066cc;
    color: white;
    padding: 0.75rem 2rem;
    border-radius: 4px;
    font-weight: 500;
    transition: background-color 0.3s;
}

.back-button:hover {
    background-color: #0055aa;
    text-decoration: none;
}
EOF
    check_result $? "style.css created successfully" "Failed to create style.css"
    
    # Create scripts.js
    log_message "Creating scripts.js..." "info"
    cat > "${PORTAL_DIR}/js/scripts.js" << 'EOF'
// Wait for the DOM to load
document.addEventListener('DOMContentLoaded', function() {
    // Initialize system status indicators
    initSystemStatus();
    
    // Set active navigation item
    setActiveNavItem();
});

// Function to initialize system status indicators
function initSystemStatus() {
    const statusContainer = document.getElementById('status-indicators');
    if (!statusContainer) return;
    
    // System components to display status for
    const components = [
        { name: 'Web Server', status: 'green' },
        { name: 'JupyterHub', status: 'yellow', message: 'Not configured' },
        { name: 'Docker', status: 'yellow', message: 'Not configured' },
        { name: 'Monitoring', status: 'yellow', message: 'Not configured' },
        { name: 'Disk Space', status: 'green' },
        { name: 'Memory', status: 'green' },
        { name: 'CPU Load', status: 'green' }
    ];
    
    // Create status indicators
    components.forEach(component => {
        const statusItem = document.createElement('div');
        statusItem.className = 'status-item';
        
        const statusIndicator = document.createElement('span');
        statusIndicator.className = `status-indicator status-${component.status}`;
        
        const statusText = document.createElement('span');
        statusText.className = 'status-text';
        statusText.textContent = `${component.name}: ${component.message || (component.status === 'green' ? 'OK' : component.status === 'yellow' ? 'Warning' : 'Error')}`;
        
        statusItem.appendChild(statusIndicator);
        statusItem.appendChild(statusText);
        statusContainer.appendChild(statusItem);
    });
}

// Function to set the active navigation item
function setActiveNavItem() {
    const currentPath = window.location.pathname;
    const navItems = document.querySelectorAll('nav ul li a');
    
    navItems.forEach(item => {
        // Remove active class from all items
        item.classList.remove('active');
        
        // Get the path from href attribute
        const itemPath = new URL(item.href).pathname;
        
        // Check if this is the current page
        if (currentPath === itemPath || 
            (itemPath !== '/' && currentPath.startsWith(itemPath))) {
            item.classList.add('active');
        } else if (currentPath === '/' && itemPath === '/') {
            item.classList.add('active');
        }
    });
}

// Future: Add AJAX function to fetch real system status
function fetchSystemStatus() {
    // This will be implemented in Phase 4: Monitoring & Refinement
    console.log('System status fetching not yet implemented');
}
EOF
    check_result $? "scripts.js created successfully" "Failed to create scripts.js"
    
    # Create 503.html
    log_message "Creating 503.html..." "info"
    cat > "${PORTAL_DIR}/503.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Service Unavailable - DIY Cloud Platform</title>
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <header>
        <div class="logo">
            <img src="/assets/logo.png" alt="DIY Cloud Platform">
            <h1>DIY Cloud Platform</h1>
        </div>
        <nav>
            <ul>
                <li><a href="/">Home</a></li>
                <li><a href="/jupyter/">JupyterHub</a></li>
                <li><a href="/portainer/">Portainer</a></li>
                <li><a href="/monitoring/">Monitoring</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <div class="error-container">
            <div class="error-code">503</div>
            <h2 class="error-message">Service Unavailable</h2>
            <p>This service is not yet configured. It will be available in a future phase of the DIY Cloud Platform.</p>
            <a href="/" class="back-button">Return to Home</a>
        </div>
    </main>
    
    <footer>
        <p>&copy; 2025 DIY Cloud Platform</p>
    </footer>
    
    <script src="/js/scripts.js"></script>
</body>
</html>
EOF
    check_result $? "503.html created successfully" "Failed to create 503.html"
    
    # Create a simple logo (SVG)
    log_message "Creating logo.svg..." "info"
    cat > "${PORTAL_DIR}/assets/logo.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <circle cx="50" cy="50" r="40" fill="#0066cc" />
  <rect x="30" y="35" width="40" height="30" fill="white" />
  <rect x="35" y="65" width="30" height="10" fill="white" />
</svg>
EOF
    check_result $? "logo.svg created successfully" "Failed to create logo.svg"
    
    # Copy logo.svg to web root as logo.png (as a fallback)
    cp "${PORTAL_DIR}/assets/logo.svg" "${PORTAL_DIR}/assets/logo.png"
    check_result $? "logo.png created successfully" "Failed to create logo.png"
    
    # Create setup-portal.sh script
    log_message "Creating setup-portal.sh script..." "info"
    cat > "${PORTAL_DIR}/setup-portal.sh" << 'EOF'
#!/usr/bin/env bash

# DIY Cloud Platform - Web Portal Setup Script
# This script sets up the web portal for the DIY Cloud Platform

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Set the base directory for the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"
PORTAL_DIR="/var/www/diycloud"

# Source the Distribution Abstraction Layer
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/common.sh"

# Function to setup web portal
setup_web_portal() {
    log_message "Setting up web portal..." "info"
    
    # Create portal directories
    log_message "Creating portal directories..." "info"
    ensure_directory "${PORTAL_DIR}" "www-data:www-data" "755"
    ensure_directory "${PORTAL_DIR}/css" "www-data:www-data" "755"
    ensure_directory "${PORTAL_DIR}/js" "www-data:www-data" "755"
    ensure_directory "${PORTAL_DIR}/assets" "www-data:www-data" "755"
    
    # Copy web portal files from the source directory
    log_message "Copying web portal files..." "info"
    cp -f "/opt/diycloud/core/portal/index.html" "${PORTAL_DIR}/"
    cp -f "/opt/diycloud/core/portal/503.html" "${PORTAL_DIR}/"
    cp -f "/opt/diycloud/core/portal/css/style.css" "${PORTAL_DIR}/css/"
    cp -f "/opt/diycloud/core/portal/js/scripts.js" "${PORTAL_DIR}/js/"
    cp -f "/opt/diycloud/core/portal/assets/logo.svg" "${PORTAL_DIR}/assets/"
    cp -f "/opt/diycloud/core/portal/assets/logo.png" "${PORTAL_DIR}/assets/"
    
    # Set appropriate permissions
    log_message "Setting appropriate permissions..." "info"
    chown -R www-data:www-data "${PORTAL_DIR}"
    find "${PORTAL_DIR}" -type d -exec chmod 755 {} \;
    find "${PORTAL_DIR}" -type f -exec chmod 644 {} \;
    
    log_message "Web portal setup completed successfully" "info"
    return 0
}

# Execute the function
setup_web_portal
exit $?
EOF
    chmod +x "${PORTAL_DIR}/setup-portal.sh"
    check_result $? "setup-portal.sh script created successfully" "Failed to create setup-portal.sh script"
    
    # Copy web portal files to web root
    log_message "Copying web portal files to web root..." "info"
    cp -f "${PORTAL_DIR}/index.html" "${WEB_ROOT}/"
    cp -f "${PORTAL_DIR}/503.html" "${WEB_ROOT}/"
    
    ensure_directory "${WEB_ROOT}/css" "www-data:www-data" "755"
    cp -f "${PORTAL_DIR}/css/style.css" "${WEB_ROOT}/css/"
    
    ensure_directory "${WEB_ROOT}/js" "www-data:www-data" "755"
    cp -f "${PORTAL_DIR}/js/scripts.js" "${WEB_ROOT}/js/"
    
    ensure_directory "${WEB_ROOT}/assets" "www-data:www-data" "755"
    cp -f "${PORTAL_DIR}/assets/logo.svg" "${WEB_ROOT}/assets/"
    cp -f "${PORTAL_DIR}/assets/logo.png" "${WEB_ROOT}/assets/"
    
    # Set appropriate permissions
    log_message "Setting appropriate permissions..." "info"
    chown -R www-data:www-data "${WEB_ROOT}"
    find "${WEB_ROOT}" -type d -exec chmod 755 {} \;
    find "${WEB_ROOT}" -type f -exec chmod 644 {} \;
    
    log_message "Web portal setup completed successfully" "info"
    return 0
}

# Step 6: Test Nginx configuration
test_nginx_configuration() {
    log_message "Testing Nginx configuration..." "info"
    
    # Test Nginx configuration
    nginx -t
    local nginx_test_result=$?
    
    if [[ ${nginx_test_result} -ne 0 ]]; then
        log_message "Nginx configuration test failed" "error"
        return 1
    fi
    
    # Restart Nginx
    log_message "Restarting Nginx..." "info"
    restart_service "nginx"
    local restart_result=$?
    
    if [[ ${restart_result} -ne 0 ]]; then
        log_message "Failed to restart Nginx" "error"
        return 1
    fi
    
    # Check if Nginx is running
    if ! is_service_active "nginx"; then
        log_message "Nginx is not running" "error"
        return 1
    fi
    
    log_message "Nginx is running successfully" "info"
    return 0
}

# Step 7: Create test script
create_test_script() {
    log_message "Creating test script..." "info"
    
    cat > "/opt/diycloud/test_core_platform.sh" << 'EOF'
#!/usr/bin/env bash

# DIY Cloud Platform - Core Platform Module Test Script
# This script tests the Core Platform Module implementation

# Ensure we're running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Source the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/package_manager.sh"
source "${BASE_DIR}/service_manager.sh"
source "${BASE_DIR}/path_resolver.sh"
source "${BASE_DIR}/common.sh"

# Print test header
echo "=== DIY Cloud Platform - Core Platform Module Tests ==="
echo "Running on: $(hostname) ($(get_primary_ip))"
echo "Distribution: ${DISTRO} ${DISTRO_VERSION} (${DISTRO_FAMILY} family)"
echo "Package manager: ${PACKAGE_MANAGER}"
echo "Service manager: ${SERVICE_MANAGER}"
echo "cgroups version: ${CGROUP_VERSION}"
echo "Date: $(date)"
echo ""

# Variables to track test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "\nTest: ${test_name}"
    echo "Testing ${test_name}..."
    
    # Increment total tests
    ((TOTAL_TESTS++))
    
    # Run the test function
    ${test_function}
    local result=$?
    
    # Check the result
    if [[ ${result} -eq 0 ]]; then
        echo "✓ Test passed: ${test_name}"
        ((PASSED_TESTS++))
        return 0
    else
        echo "✗ Test failed: ${test_name}"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Test 1: Base System Setup
test_base_system() {
    log_message "Checking if required packages are installed..." "info"
    
    # Check if required packages are installed
    local required_packages=("nginx" "openssl" "curl" "ca-certificates" "logrotate")
    local missing_packages=()
    
    for pkg in "${required_packages[@]}"; do
        if ! is_package_installed "${pkg}"; then
            missing_packages+=("${pkg}")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        log_message "Missing packages: ${missing_packages[*]}" "error"
        return 1
    fi
    
    log_message "All required packages are installed" "info"
    
    # Check if directories exist
    log_message "Checking if required directories exist..." "info"
    local required_dirs=("/var/www/diycloud" "/etc/diycloud" "/var/log/diycloud")
    local missing_dirs=()
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            missing_dirs+=("${dir}")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        log_message "Missing directories: ${missing_dirs[*]}" "error"
        return 1
    fi
    
    log_message "All required directories exist" "info"
    
    # Check if logrotate configuration exists
    log_message "Checking if logrotate configuration exists..." "info"
    if [[ ! -f "/etc/logrotate.d/diycloud" ]]; then
        log_message "Logrotate configuration not found: /etc/logrotate.d/diycloud" "error"
        return 1
    fi
    
    log_message "Logrotate configuration exists" "info"
    
    return 0
}

# Test 2: Nginx Configuration
test_nginx_config() {
    log_message "Checking if Nginx configuration files exist..." "info"
    
    # Get Nginx configuration paths
    NGINX_CONF=$(get_config_path "nginx")
    NGINX_SITES=$(get_config_path "nginx_sites")
    NGINX_ENABLED=$(get_config_path "nginx_enabled")
    
    log_message "Nginx config path: ${NGINX_CONF}" "info"
    log_message "Nginx sites path: ${NGINX_SITES}" "info"
    log_message "Nginx enabled path: ${NGINX_ENABLED}" "info"
    
    # Check if Nginx configuration files exist
    local config_files=("${NGINX_CONF}/nginx.conf" "${NGINX_CONF}/ssl-params.conf")
    local portal_conf="${NGINX_SITES}/diycloud.conf"
    local missing_files=()
    
    for file in "${config_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            missing_files+=("${file}")
        fi
    done
    
    if [[ ! -f "${portal_conf}" ]]; then
        missing_files+=("${portal_conf}")
    fi
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_message "Missing configuration files: ${missing_files[*]}" "error"
        return 1
    fi
    
    log_message "All Nginx configuration files exist" "info"
    
    # Test Nginx configuration
    log_message "Testing Nginx configuration..." "info"
    nginx -t
    local nginx_test_result=$?
    
    if [[ ${nginx_test_result} -ne 0 ]]; then
        log_message "Nginx configuration test failed" "error"
        return 1
    fi
    
    log_message "Nginx configuration is valid" "info"
    
    # Check if Nginx is running
    log_message "Checking if Nginx is running..." "info"
    if ! is_service_active "nginx"; then
        log_message "Nginx is not running" "error"
        return 1
    fi
    
    log_message "Nginx is running" "info"
    
    return 0
}

# Test 3: Web Portal
test_web_portal() {
    log_message "Checking if web portal files exist..." "info"
    
    # Check if web portal files exist
    local portal_files=(
        "/var/www/diycloud/index.html"
        "/var/www/diycloud/css/style.css"
        "/var/www/diycloud/js/scripts.js"
        "/var/www/diycloud/assets/logo.png"
        "/var/www/diycloud/503.html"
    )
    local missing_files=()
    
    for file in "${portal_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            missing_files+=("${file}")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_message "Missing web portal files: ${missing_files[*]}" "error"
        return 1
    fi
    
    log_message "All web portal files exist" "info"
    
    # Check file permissions
    log_message "Checking file permissions..." "info"
    local web_root="/var/www/diycloud"
    local incorrect_permissions=false
    
    # Check directory ownership
    local owner=$(stat -c "%U:%G" "${web_root}")
    if [[ "${owner}" != "www-data:www-data" ]]; then
        log_message "Incorrect ownership for ${web_root}: ${owner} (expected: www-data:www-data)" "error"
        incorrect_permissions=true
    fi
    
    # Check directory permissions
    local dir_perm=$(stat -c "%a" "${web_root}")
    if [[ "${dir_perm}" != "755" ]]; then
        log_message "Incorrect permissions for ${web_root}: ${dir_perm} (expected: 755)" "error"
        incorrect_permissions=true
    fi
    
    if [[ "${incorrect_permissions}" == "true" ]]; then
        log_message "File permission issues detected" "error"
        return 1
    fi
    
    log_message "File permissions are correct" "info"
    
    # Test HTTP redirect to HTTPS
    if command_exists "curl"; then
        log_message "Testing HTTP redirect to HTTPS..." "info"
        local http_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
        if [[ ${http_status} != "301" ]]; then
            log_message "HTTP redirect test failed: Expected 301, got ${http_status}" "error"
            return 1
        fi
        
        log_message "HTTP redirect to HTTPS works correctly" "info"
        
        # Test HTTPS access (ignore SSL certificate verification for self-signed cert)
        log_message "Testing HTTPS access..." "info"
        local https_status=$(curl -s -k -o /dev/null -w "%{http_code}" https://localhost)
        if [[ ${https_status} != "200" ]]; then
            log_message "HTTPS access test failed: Expected 200, got ${https_status}" "error"
            return 1
        fi
        
        log_message "HTTPS access works correctly" "info"
    else
        log_message "curl command not found, skipping HTTP/HTTPS tests" "warning"
    fi
    
    return 0
}

# Test 4: SSL Certificate
test_ssl_certificate() {
    log_message "Checking if SSL certificates exist..." "info"
    
    # Check if SSL certificate and key exist
    local cert_file="/etc/ssl/certs/diycloud.crt"
    local key_file="/etc/ssl/private/diycloud.key"
    
    if [[ ! -f "${cert_file}" ]]; then
        log_message "SSL certificate not found: ${cert_file}" "error"
        return 1
    fi
    
    if [[ ! -f "${key_file}" ]]; then
        log_message "SSL key not found: ${key_file}" "error"
        return 1
    fi
    
    log_message "SSL certificate and key exist" "info"
    
    # Check certificate validity
    log_message "Checking certificate validity..." "info"
    if ! openssl x509 -noout -in "${cert_file}" &> /dev/null; then
        log_message "Invalid SSL certificate" "error"
        return 1
    fi
    
    log_message "SSL certificate is valid" "info"
    
    # Check certificate permissions
    log_message "Checking certificate permissions..." "info"
    local cert_perm=$(stat -c "%a" "${cert_file}")
    local key_perm=$(stat -c "%a" "${key_file}")
    
    if [[ "${cert_perm}" != "644" ]]; then
        log_message "Incorrect permissions for ${cert_file}: ${cert_perm} (expected: 644)" "error"
        return 1
    fi
    
    if [[ "${key_perm}" != "600" ]]; then
        log_message "Incorrect permissions for ${key_file}: ${key_perm} (expected: 600)" "error"
        return 1
    fi
    
    log_message "Certificate permissions are correct" "info"
    
    # Get certificate information
    log_message "Getting certificate information..." "info"
    local cert_subject=$(openssl x509 -noout -subject -in "${cert_file}")
    local cert_issuer=$(openssl x509 -noout -issuer -in "${cert_file}")
    local cert_dates=$(openssl x509 -noout -dates -in "${cert_file}")
    
    echo "Certificate Subject: ${cert_subject}"
    echo "Certificate Issuer: ${cert_issuer}"
    echo "Certificate Dates: ${cert_dates}"
    
    return 0
}

# Run all tests
run_test "Base System Setup" test_base_system
run_test "Nginx Configuration" test_nginx_config
run_test "Web Portal" test_web_portal
run_test "SSL Certificate" test_ssl_certificate

# Print test summary
echo -e "\n=== Test Summary ==="
echo "Total tests: ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: ${FAILED_TESTS}"

if [[ ${FAILED_TESTS} -eq 0 ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed."
    exit 1
fi
EOF
    chmod +x "/opt/diycloud/test_core_platform.sh"
    check_result $? "test_core_platform.sh created successfully" "Failed to create test_core_platform.sh"
    
    log_message "Test script created successfully" "info"
    return 0
}

# Step 8: Update README.md
update_readme() {
    log_message "Updating README.md..." "info"
    
    # Check if README.md exists
    if [[ ! -f "/opt/diycloud/README.md" ]]; then
        log_message "README.md not found, creating a new one..." "info"
        cat > "/opt/diycloud/README.md" << 'EOF'
# DIY Cloud Platform

A self-hosted resource sharing platform that allows you to turn any Linux server into a multi-user cloud environment. Share your CPU, RAM, GPU, and disk resources with others through JupyterHub notebooks and Docker containers. Compatible with multiple Linux distributions including Ubuntu, Debian, CentOS/RHEL, Fedora, Arch Linux, and OpenSUSE.

## Project Status

This project is currently in active development.

- **Phase 0: Distribution Abstraction Layer** ✅ Completed
- **Phase 1: Foundation** ✅ Completed
- **Phase 2: User & Resource Management** 🔄 In Progress
- **Phase 3: Service Modules** 📅 Not Started
- **Phase 4: Monitoring & Refinement** 📅 Not Started
- **Phase 5: Documentation & Release** 📅 Not Started

## Features

- **Unified Web Portal**: Simple landing page for all services
- **JupyterHub Integration**: Python notebooks for data science/ML work
- **Docker with Portainer**: Container management for applications
- **Resource Management**: Control CPU, RAM, disk, and GPU allocation
- **User Activity Tracking**: Monitor resource usage with privacy in mind
- **Comprehensive Monitoring**: Prometheus and Grafana dashboards

## Project Structure

```
diy-cloud-platform/
├── docs/                       # Documentation
│   ├── RASD.md                 # Requirements Analysis and System Design
│   ├── DD.md                   # Detailed Design
│   └── Roadmap.md              # Implementation Roadmap
│
├── lib/                        # The Distribution Abstraction Layer
│   ├── detect_distro.sh        # Distribution detection script
│   ├── package_manager.sh      # Package management functions 
│   ├── service_manager.sh      # Service management functions
│   ├── path_resolver.sh        # Path resolution functions
│   ├── resource_adapter.sh     # Resource management adaptation
│   └── common.sh               # Common utilities
│
├── core/                       # Core Platform Module
│   ├── setup-base.sh           # Base system setup script
│   ├── nginx/                  # Nginx configurations
│   │   ├── nginx.conf          # Main Nginx configuration
│   │   ├── ssl-params.conf     # SSL parameters configuration
│   │   └── diycloud.conf       # Web portal virtual host configuration
│   ├── portal/                 # Web portal files
│   │   ├── index.html          # Main portal page
│   │   ├── css/                # CSS files
│   │   │   └── style.css       # Main stylesheet
│   │   ├── js/                 # JavaScript files
│   │   │   └── scripts.js      # Main script file
│   │   └── assets/             # Images and other assets
│   │       └── logo.png        # DIY Cloud Platform logo
│   └── ssl/                    # SSL certificate generation
│       └── generate-ssl.sh     # Script to generate SSL certificates
│
├── usermgmt/                   # User Management files (Phase 2)
├── jupyterhub/                 # JupyterHub files (Phase 3)
├── docker/                     # Docker/Portainer files (Phase 3)
├── resources/                  # Resource Management files (Phase 2)
├── monitoring/                 # Monitoring files (Phase 4)
│
├── test_distribution_abstraction.sh  # Test script for the Distribution Abstraction Layer
├── test_core_platform.sh             # Test script for the Core Platform Module
├── install.sh                  # Main installation script
└── README.md                   # This file
```

## Development Status

- **Phase 0: Distribution Abstraction Layer**: Completed ✅
  - Distribution detection ✅
  - Package management ✅
  - Service management ✅
  - Path resolution ✅
  - Resource management adaptation ✅
  - Testing framework ✅

- **Phase 1: Foundation**: Completed ✅
  - Base system setup ✅
  - Nginx configuration ✅
  - Web portal ✅
  - SSL certificates ✅
  - Testing framework ✅

- **Phase 2: User & Resource Management**: In Progress 🔄
- **Phase 3: Service Modules**: Not Started 📅
- **Phase 4: Monitoring & Refinement**: Not Started 📅
- **Phase 5: Documentation & Release**: Not Started 📅

## Quick Start

### Prerequisites
- Any of the following Linux distributions:
  - Ubuntu 20.04+ LTS
  - Debian 11+ (Bullseye)
  - CentOS/RHEL 8+
  - Fedora 35+
  - Arch Linux (Rolling)
  - OpenSUSE Leap 15.3+
- Minimum 2 CPU cores, 8GB RAM, 50GB disk space
- Root access

### Installation
```bash
# Clone the repository
git clone https://github.com/your-username/diy-cloud-platform.git
cd diy-cloud-platform

# Run the installation script
sudo ./install.sh
```

### Accessing the Platform

After installation, access the web portal at:
```
https://your-server-ip/
```

## Development Setup

### Prerequisites

- Any of the supported Linux distributions
- Git
- Bash 4.0+

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/diy-cloud-platform.git
   cd diy-cloud-platform
   ```

2. Run the test scripts to verify compatibility:
   ```bash
   sudo ./test_distribution_abstraction.sh
   sudo ./test_core_platform.sh
   ```

3. To install the system (optional):
   ```bash
   sudo ./install.sh
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
EOF
    else
        log_message "Updating existing README.md..." "info"
        # Update the README.md file with Phase 1 status
        sed -i 's/- \*\*Phase 1: Foundation\*\* 🔄 In Progress/- \*\*Phase 1: Foundation\*\* ✅ Completed/g' "/opt/diycloud/README.md"
        sed -i 's/- \*\*Phase 1: Foundation\*\*: Not started/- \*\*Phase 1: Foundation\*\*: Completed ✅/g' "/opt/diycloud/README.md"
        sed -i 's/- \*\*Phase 1: Foundation\*\*: In Progress/- \*\*Phase 1: Foundation\*\*: Completed ✅/g' "/opt/diycloud/README.md"
        
        # Update the README.md file with Phase 1 components
        if ! grep -q "- Base system setup" "/opt/diycloud/README.md"; then
            sed -i '/- \*\*Phase 1: Foundation\*\*: Completed ✅/a \  - Base system setup ✅\n  - Nginx configuration ✅\n  - Web portal ✅\n  - SSL certificates ✅\n  - Testing framework ✅' "/opt/diycloud/README.md"
        fi
        
        # Update the README.md file with Phase 2 status
        sed -i 's/- \*\*Phase 2: User & Resource Management\*\*: Not started/- \*\*Phase 2: User & Resource Management\*\*: In Progress 🔄/g' "/opt/diycloud/README.md"
    fi
    
    log_message "README.md updated successfully" "info"
    return 0
}

# Main function
main() {
    log_message "Starting Phase 1 implementation..." "info"
    
    # Run all steps
    run_step "Create directories" create_directories || return 1
    run_step "Setup base system" setup_base_system || return 1
    run_step "Configure Nginx" configure_nginx || return 1
    run_step "Setup SSL certificates" setup_ssl_certificates || return 1
    run_step "Setup web portal" setup_web_portal || return 1
    run_step "Test Nginx configuration" test_nginx_configuration || return 1
    run_step "Create test script" create_test_script || return 1
    run_step "Update README.md" update_readme || return 1
    
    log_message "Phase 1 implementation completed successfully" "info"
    
    # Print access information
    local ip_address=$(get_primary_ip)
    echo ""
    echo "===================================================================="
    echo "Phase 1: Foundation has been implemented successfully!"
    echo "===================================================================="
    echo ""
    echo "You can access the DIY Cloud Platform at:"
    echo "  https://${ip_address}/"
    echo ""
    echo "You can test the implementation with:"
    echo "  sudo /opt/diycloud/test_core_platform.sh"
    echo ""
    echo "Next steps: Proceed to Phase 2: User & Resource Management"
    echo "===================================================================="
    
    return 0
}

# Run the main function
main
exit $?