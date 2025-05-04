#!/usr/bin/env bash
#
# DIY Cloud Platform - Core Platform Module
# Base System Setup Script - Ubuntu Specific Version
#
# This script sets up the base system for the DIY Cloud Platform on Ubuntu.

# Exit on error
set -e

# Get the script directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source the Distribution Abstraction Layer
source "$PROJECT_DIR/lib/detect_distro.sh"
source "$PROJECT_DIR/lib/package_manager.sh"
source "$PROJECT_DIR/lib/service_manager.sh"
source "$PROJECT_DIR/lib/path_resolver.sh"
source "$PROJECT_DIR/lib/resource_adapter.sh"
source "$PROJECT_DIR/lib/common.sh"

# Configuration variables
DIYCLOUD_HOME="/opt/diycloud"
DIYCLOUD_LOG="/var/log/diycloud"
DIYCLOUD_CONFIG="/etc/diycloud"
DIYCLOUD_WEB="/var/www/diycloud"
DIYCLOUD_SSL="/etc/ssl/diycloud"
PORTAL_USER="diycloud"
PORTAL_GROUP="diycloud"
SERVER_NAME="localhost"

# Function to install base packages
install_base_packages() {
    log_message "Installing base packages..."
    
    # Update package lists
    update_package_lists
    
    # Install required packages
    install_package "nginx"
    install_package "openssl"
    install_package "curl"
    install_package "ca-certificates"
    install_package "ufw"
    
    log_message "Base packages installed successfully."
}

# Function to create user and group
create_user_and_group() {
    log_message "Creating user and group..."
    
    # Check if group exists
    if ! getent group "$PORTAL_GROUP" > /dev/null; then
        groupadd "$PORTAL_GROUP"
    fi
    
    # Check if user exists
    if ! getent passwd "$PORTAL_USER" > /dev/null; then
        useradd -r -g "$PORTAL_GROUP" -s /bin/false "$PORTAL_USER"
    fi
    
    log_message "User and group created successfully."
}

# Function to create required directories
create_directories() {
    log_message "Creating required directories..."
    
    # Create DIY Cloud Platform directories
    create_directory "$DIYCLOUD_HOME" "root:root" "755"
    create_directory "$DIYCLOUD_LOG" "root:root" "755"
    create_directory "$DIYCLOUD_CONFIG" "root:root" "755"
    create_directory "$DIYCLOUD_WEB" "$PORTAL_USER:$PORTAL_GROUP" "755"
    create_directory "$DIYCLOUD_SSL" "root:root" "700"
    
    # Create web portal directories
    create_directory "$DIYCLOUD_WEB/portal" "$PORTAL_USER:$PORTAL_GROUP" "755"
    create_directory "$DIYCLOUD_WEB/portal/css" "$PORTAL_USER:$PORTAL_GROUP" "755"
    create_directory "$DIYCLOUD_WEB/portal/js" "$PORTAL_USER:$PORTAL_GROUP" "755"
    create_directory "$DIYCLOUD_WEB/portal/assets" "$PORTAL_USER:$PORTAL_GROUP" "755"
    
    log_message "Directories created successfully."
}

# Function to generate SSL certificates
generate_ssl_certificates() {
    log_message "Generating SSL certificates..."
    
    # Generate a self-signed certificate
    if [[ ! -f "$DIYCLOUD_SSL/diycloud.key" ]] || [[ ! -f "$DIYCLOUD_SSL/diycloud.crt" ]]; then
        log_message "Generating self-signed SSL certificate for $SERVER_NAME..."
        
        # Create OpenSSL configuration file
        cat > "$DIYCLOUD_SSL/openssl.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $SERVER_NAME

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $SERVER_NAME
DNS.2 = www.$SERVER_NAME
IP.1 = 127.0.0.1
EOF
        
        # Generate private key and certificate
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$DIYCLOUD_SSL/diycloud.key" \
            -out "$DIYCLOUD_SSL/diycloud.crt" \
            -config "$DIYCLOUD_SSL/openssl.cnf"
        
        # Set correct permissions
        chmod 600 "$DIYCLOUD_SSL/diycloud.key"
        chmod 644 "$DIYCLOUD_SSL/diycloud.crt"
    else
        log_message "SSL certificates already exist. Skipping generation."
    fi
    
    log_message "SSL certificates generated successfully."
}

# Function to deploy Nginx configuration
deploy_nginx_configuration() {
    log_message "Deploying Nginx configuration..."
    
    # Get Nginx configuration paths
    nginx_sites_dir=$(get_config_path "nginx_sites")
    nginx_enabled_dir=$(get_config_path "nginx_enabled")
    
    # Copy and customize the portal configuration
    cp "$SCRIPT_DIR/nginx/diycloud-portal.conf" "$nginx_sites_dir/diycloud-portal.conf"
    
    # Replace variables in the portal configuration
    sed -i "s|SERVER_NAME|$SERVER_NAME|g" "$nginx_sites_dir/diycloud-portal.conf"
    sed -i "s|DIYCLOUD_WEB|$DIYCLOUD_WEB|g" "$nginx_sites_dir/diycloud-portal.conf"
    sed -i "s|DIYCLOUD_SSL|$DIYCLOUD_SSL|g" "$nginx_sites_dir/diycloud-portal.conf"
    
    # Enable the site
    if [[ -d "$nginx_enabled_dir" ]]; then
        # For Debian-style with sites-available and sites-enabled
        if [[ -f "$nginx_enabled_dir/diycloud-portal.conf" ]]; then
            rm "$nginx_enabled_dir/diycloud-portal.conf"
        fi
        ln -sf "$nginx_sites_dir/diycloud-portal.conf" "$nginx_enabled_dir/diycloud-portal.conf"
        log_message "Enabled DIY Cloud Platform Nginx site"
    fi
    
    # Test the Nginx configuration
    if nginx -t; then
        log_message "Nginx configuration test successful"
    else
        log_message "Nginx configuration test failed" "error"
        return 1
    fi
    
    log_message "Nginx configuration deployed successfully"
    return 0
}

# Function to deploy web portal
deploy_web_portal() {
    log_message "Deploying web portal..."
    
    # Copy web portal files
    cp "$SCRIPT_DIR/portal/index.html" "$DIYCLOUD_WEB/portal/"
    cp "$SCRIPT_DIR/portal/css/style.css" "$DIYCLOUD_WEB/portal/css/"
    cp "$SCRIPT_DIR/portal/js/scripts.js" "$DIYCLOUD_WEB/portal/js/"
    cp "$SCRIPT_DIR/portal/assets/logo.svg" "$DIYCLOUD_WEB/portal/assets/"
    
    # Set correct ownership and permissions
    chown -R "$PORTAL_USER:$PORTAL_GROUP" "$DIYCLOUD_WEB"
    find "$DIYCLOUD_WEB" -type d -exec chmod 755 {} \;
    find "$DIYCLOUD_WEB" -type f -exec chmod 644 {} \;
    
    log_message "Web portal deployed successfully."
}

# Function to configure firewall
configure_firewall() {
    log_message "Configuring firewall..."
    
    # Configure UFW (Ubuntu's default firewall)
    ufw allow ssh
    ufw allow http
    ufw allow https
    
    # Enable UFW if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        log_message "Enabling UFW firewall..."
        echo "y" | ufw enable
    fi
    
    log_message "Firewall configured successfully."
}

# Function to restart Nginx service
restart_nginx() {
    log_message "Restarting Nginx service..."
    
    # Restart Nginx
    restart_service "nginx"
    
    # Enable Nginx to start at boot
    enable_service "nginx"
    
    log_message "Nginx service restarted successfully."
}

# Main function to execute all steps
main() {
    log_message "Starting DIY Cloud Platform base system setup..."
    
    install_base_packages
    create_user_and_group
    create_directories
    generate_ssl_certificates
    deploy_nginx_configuration
    deploy_web_portal
    configure_firewall
    restart_nginx
    
    log_message "DIY Cloud Platform base system setup completed successfully."
    
    # Print access information
    log_message "You can now access the DIY Cloud Platform at: https://$SERVER_NAME"
}

# Run the main function
main