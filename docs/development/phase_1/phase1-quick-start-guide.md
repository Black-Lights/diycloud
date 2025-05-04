# Phase 1: Foundation - Quick Start Guide

This guide will help you get started with the development of Phase 1 of the DIY Cloud Platform project - the Core Platform Module. This module provides the foundation for all other components.

## Prerequisites

- Completed Phase 0 (Distribution Abstraction Layer)
- Git for version control
- Access to multiple Linux distributions for testing

## Getting Started

1. Make sure you have the Distribution Abstraction Layer installed:
   ```bash
   # Source the Distribution Abstraction Layer
   source /opt/diycloud/lib/detect_distro.sh
   source /opt/diycloud/lib/package_manager.sh
   source /opt/diycloud/lib/service_manager.sh
   source /opt/diycloud/lib/path_resolver.sh
   source /opt/diycloud/lib/resource_adapter.sh
   source /opt/diycloud/lib/common.sh
   
   # Verify installation
   echo "Distribution: $DISTRO $DISTRO_VERSION ($DISTRO_FAMILY family)"
   ```

2. Create the directory structure for Phase 1:
   ```bash
   mkdir -p /opt/diycloud/core/nginx
   mkdir -p /opt/diycloud/core/portal/{css,js,assets}
   mkdir -p /opt/diycloud/core/ssl
   ```

## Understanding the Core Platform Module

The Core Platform Module consists of several components:

1. **setup-base.sh**: Sets up the base system, installs required packages
2. **nginx/**: Contains Nginx configuration files
3. **portal/**: Contains the web portal files (HTML, CSS, JS)
4. **ssl/**: Contains scripts for SSL certificate management

## Developing the Core Platform Module

### 1. Base System Setup

Create a base system setup script (`/opt/diycloud/core/setup-base.sh`) that:

- Uses the Distribution Abstraction Layer to install required packages
- Sets up system-wide configurations
- Creates necessary directories
- Configures firewall rules

Example:
```bash
#!/usr/bin/env bash

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/service_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/common.sh

log_message "Setting up base system..." "info"

# Install required packages
install_package "nginx"
install_package "openssl"
install_package "curl"
# Add more packages as needed

# Configure firewall
if command_exists "ufw"; then
    log_message "Configuring UFW firewall..." "info"
    ufw allow 80/tcp
    ufw allow 443/tcp
    # Add more rules as needed
fi

# Create necessary directories
ensure_directory "/var/www/diycloud" "www-data:www-data" "755"
ensure_directory "/etc/diycloud" "root:root" "755"
ensure_directory "/var/log/diycloud" "root:root" "755"

# Set system parameters
log_message "Configuring system parameters..." "info"
# Add system parameters as needed

log_message "Base system setup completed successfully" "info"
```

### 2. Nginx Configuration

Create Nginx configuration files in the `/opt/diycloud/core/nginx/` directory:

- `nginx.conf`: Main Nginx configuration
- `ssl-params.conf`: SSL/TLS parameters
- `portal.conf`: Virtual host configuration for the web portal

Example for `portal.conf`:
```
server {
    listen 80;
    server_name _;
    
    # Redirect HTTP to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;
    
    ssl_certificate /etc/ssl/certs/diycloud.crt;
    ssl_certificate_key /etc/ssl/private/diycloud.key;
    include /etc/nginx/ssl-params.conf;
    
    root /var/www/diycloud;
    index index.html;
    
    # Web portal location
    location / {
        try_files $uri $uri/ =404;
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
}
```

### 3. Web Portal Development

Create a simple but effective web portal in the `/opt/diycloud/core/portal/` directory:

- `index.html`: Main landing page
- `css/style.css`: Main stylesheet
- `js/scripts.js`: JavaScript for interactivity
- `assets/`: Images and other assets

Example for `index.html`:
```html
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
                <li><a href="/">Home</a></li>
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
```

### 4. SSL Certificate Management

Create a script to generate self-signed SSL certificates in the `/opt/diycloud/core/ssl/` directory:

Example for `generate-cert.sh`:
```bash
#!/usr/bin/env bash

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/common.sh

# Default values
DOMAIN=$(hostname -f)
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
DAYS=365

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
        *)
        shift
        ;;
    esac
done

log_message "Generating self-signed SSL certificate for ${DOMAIN}" "info"

# Create directories if they don't exist
ensure_directory "${CERT_DIR}" "root:root" "755"
ensure_directory "${KEY_DIR}" "root:root" "710"

# Generate self-signed certificate
openssl req -x509 -nodes -days ${DAYS} -newkey rsa:2048 \
    -keyout "${KEY_DIR}/diycloud.key" \
    -out "${CERT_DIR}/diycloud.crt" \
    -subj "/CN=${DOMAIN}" \
    -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost,IP:127.0.0.1"

# Set appropriate permissions
chmod 600 "${KEY_DIR}/diycloud.key"
chmod 644 "${CERT_DIR}/diycloud.crt"

log_message "SSL certificate generation completed" "info"
log_message "Certificate: ${CERT_DIR}/diycloud.crt" "info"
log_message "Private key: ${KEY_DIR}/diycloud.key" "info"
```

## Testing the Core Platform Module

Create a test script (`test_core_platform.sh`) that verifies all components:

```bash
#!/usr/bin/env bash

# Source the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/service_manager.sh
source /opt/diycloud/lib/path_resolver.sh
source /opt/diycloud/lib/common.sh

# Print test header
echo "=== DIY Cloud Platform - Core Platform Module Tests ==="
echo "Running on: $(hostname) ($(get_primary_ip))"
echo "Distribution: ${DISTRO} ${DISTRO_VERSION} (${DISTRO_FAMILY} family)"

# Test base system setup
echo -e "\nTest: Base System Setup"
echo "Testing Base System Setup..."
# Add tests for base system setup

# Test Nginx configuration
echo -e "\nTest: Nginx Configuration"
echo "Testing Nginx Configuration..."
# Add tests for Nginx configuration

# Test web portal
echo -e "\nTest: Web Portal"
echo "Testing Web Portal..."
# Add tests for web portal

# Test SSL certificate
echo -e "\nTest: SSL Certificate"
echo "Testing SSL Certificate..."
# Add tests for SSL certificate

# Print test summary
echo -e "\n=== Test Summary ==="
# Add test summary
```

## Next Steps

Once you have implemented and tested the Core Platform Module, you'll be ready to move on to Phase 2: User & Resource Management.

## Help and Support

If you encounter any issues or have questions, please refer to the detailed documentation in the `docs` directory or contact the project maintainers.

Happy coding!
