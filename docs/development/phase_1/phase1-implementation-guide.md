# Phase 1: Foundation - Implementation Guide

This guide provides detailed instructions for implementing the Core Platform Module in the DIY Cloud Platform. The Core Platform Module establishes the foundation upon which all other components will be built.

## 1. Introduction

The Core Platform Module handles:

- Base system setup and configuration
- Web server (Nginx) installation and configuration
- Web portal for user interface
- SSL/TLS security

By implementing the Core Platform Module, you will create a solid foundation that works across all supported Linux distributions while maintaining a consistent user experience.

## 2. Directory Structure

```
/opt/diycloud/core/
├── setup-base.sh          # Base system setup script
├── nginx/                 # Nginx configurations
│   ├── nginx.conf         # Main Nginx configuration
│   ├── ssl-params.conf    # SSL security parameters
│   └── portal.conf        # Web portal virtual host
├── portal/                # Web portal files
│   ├── index.html         # Landing page
│   ├── css/               # Stylesheets
│   │   └── style.css      # Main CSS file
│   ├── js/                # JavaScript
│   │   └── scripts.js     # Main JS file
│   └── assets/            # Images and other assets
│       └── logo.png       # DIY Cloud Platform logo
└── ssl/                   # SSL certificate generation
    └── generate-cert.sh   # Script to generate self-signed certificates
```

## 3. Base System Setup

### 3.1 Creating the Base Setup Script

The `setup-base.sh` script is responsible for setting up the base system. It will:

1. Install required packages
2. Configure the firewall
3. Create necessary directories
4. Set appropriate permissions
5. Configure system parameters

Here's a detailed implementation of the `setup-base.sh` script:

```bash
#!/usr/bin/env bash

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
    
    # Update package lists
    log_message "Updating package lists..." "info"
    update_package_lists
    
    # Install required packages
    log_message "Installing required packages..." "info"
    install_package "nginx"
    install_package "openssl"
    install_package "curl"
    install_package "ca-certificates"
    install_package "logrotate"
    
    # Create necessary directories
    log_message "Creating necessary directories..." "info"
    ensure_directory "/var/www/diycloud" "www-data:www-data" "755"
    ensure_directory "/etc/diycloud" "root:root" "755"
    ensure_directory "/var/log/diycloud" "root:root" "755"
    
    # Configure firewall if available
    if command_exists "ufw"; then
        log_message "Configuring UFW firewall..." "info"
        ufw allow 80/tcp
        ufw allow 443/tcp
    elif command_exists "firewalld"; then
        log_message "Configuring FirewallD..." "info"
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    elif command_exists "iptables"; then
        log_message "Configuring iptables..." "info"
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
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
    
    # Set system parameters if needed
    log_message "Setting system parameters..." "info"
    # Add any system parameters here
    
    log_message "Base system setup completed successfully" "info"
    return 0
}

# Execute the function
setup_base_system
exit $?
```

### 3.2 Installing and Running the Base Setup Script

To install and run the base setup script:

```bash
# Copy the script to the correct location
cp setup-base.sh /opt/diycloud/core/setup-base.sh
chmod +x /opt/diycloud/core/setup-base.sh

# Run the script
sudo /opt/diycloud/core/setup-base.sh
```

## 4. Nginx Configuration

### 4.1 Main Nginx Configuration

Create the main Nginx configuration file (`nginx.conf`):

```
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

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
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Logging Settings
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip Settings
    gzip on;

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

### 4.2 SSL Parameters Configuration

Create the SSL parameters configuration file (`ssl-params.conf`):

```
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
```

### 4.3 Web Portal Virtual Host Configuration

Create the web portal virtual host configuration file (`portal.conf`):

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
    
    # Custom error pages
    error_page 503 /503.html;
    location = /503.html {
        root /var/www/diycloud;
    }
}
```

### 4.4 Installing and Activating Nginx Configuration

To install and activate the Nginx configuration:

```bash
# Get Nginx configuration paths using the Distribution Abstraction Layer
source /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/path_resolver.sh

NGINX_CONF=$(get_config_path "nginx")
NGINX_SITES=$(get_config_path "nginx_sites")
NGINX_ENABLED=$(get_config_path "nginx_enabled")

# Copy the Nginx configuration files
cp /opt/diycloud/core/nginx/nginx.conf ${NGINX_CONF}/nginx.conf
cp /opt/diycloud/core/nginx/ssl-params.conf ${NGINX_CONF}/ssl-params.conf
cp /opt/diycloud/core/nginx/portal.conf ${NGINX_SITES}/portal.conf

# Enable the portal site
if [[ "${NGINX_SITES}" != "${NGINX_ENABLED}" ]]; then
    # For Debian-style with sites-available and sites-enabled
    ln -sf "${NGINX_SITES}/portal.conf" "${NGINX_ENABLED}/portal.conf"
fi

# Test the configuration
nginx -t

# Restart Nginx to apply changes
source /opt/diycloud/lib/service_manager.sh
restart_service "nginx"
```

## 5. Web Portal Development

### 5.1 HTML Structure (index.html)

Create the main HTML file for the web portal:

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
```

### 5.2 CSS Styling (style.css)

Create the main CSS file for the web portal:

```css
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
```

### 5.3 JavaScript Functionality (scripts.js)

Create the main JavaScript file for the web portal:

```javascript
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
```

### 5.4 Creating Error Pages

Create a 503 error page (`503.html`) for the services that are not yet implemented:

```html
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
```

### 5.5 Installing Web Portal Files

To install the web portal files:

```bash
# Copy web portal files
cp -r /opt/diycloud/core/portal/* /var/www/diycloud/

# Set appropriate permissions
chown -R www-data:www-data /var/www/diycloud
find /var/www/diycloud -type d -exec chmod 755 {} \;
find /var/www/diycloud -type f -exec chmod 644 {} \;
```

## 6. SSL Certificate Management

### 6.1 Creating the Certificate Generation Script

Create a script to generate self-signed SSL certificates:

```bash
#!/usr/bin/env bash

# Source the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/common.sh"

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

### 6.2 Let's Encrypt Integration (Optional)

If you want to implement Let's Encrypt integration, you can create a separate script:

```bash
#!/usr/bin/env bash

# Source the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/package_manager.sh"
source "${BASE_DIR}/service_manager.sh"
source "${BASE_DIR}/common.sh"

# Default values
DOMAIN=$(hostname -f)
EMAIL=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --domain)
        DOMAIN="$2"
        shift
        shift
        ;;
        --email)
        EMAIL="$2"
        shift
        shift
        ;;
        *)
        shift
        ;;
    esac
done

# Check if domain and email are provided
if [[ -z "${DOMAIN}" ]]; then
    log_message "Domain name is required" "error"
    exit 1
fi

if [[ -z "${EMAIL}" ]]; then
    log_message "Email address is required" "error"
    exit 1
fi

log_message "Setting up Let's Encrypt SSL certificate for ${DOMAIN}" "info"

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
        exit 1
        ;;
esac

# Obtain and install certificate
log_message "Obtaining certificate for ${DOMAIN}..." "info"
certbot --nginx -d "${DOMAIN}" --non-interactive --agree-tos --email "${EMAIL}" --redirect

# Verify certificate installation
if [[ $? -eq 0 ]]; then
    log_message "Let's Encrypt certificate installed successfully" "info"
else
    log_message "Failed to install Let's Encrypt certificate" "error"
    exit 1
fi

# Set up automatic renewal
log_message "Setting up automatic renewal..." "info"
echo "0 3 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew
chmod 644 /etc/cron.d/certbot-renew

log_message "Let's Encrypt setup completed" "info"
```

### 6.3 Installing the SSL Scripts

To install the SSL scripts:

```bash
# Copy the SSL scripts
cp /opt/diycloud/core/ssl/generate-cert.sh /opt/diycloud/core/ssl/generate-cert.sh
chmod +x /opt/diycloud/core/ssl/generate-cert.sh

# Generate self-signed certificate
/opt/diycloud/core/ssl/generate-cert.sh --domain $(hostname -f)
```

## 7. Testing the Core Platform Module

### 7.1 Creating a Test Script

Create a test script (`test_core_platform.sh`) to verify that all components of the Core Platform Module are working correctly:

```bash
#!/usr/bin/env bash

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
echo "Date: $(date)"
echo ""

# Function to run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "\nTest: ${test_name}"
    echo "Testing ${test_name}..."
    
    # Run the test function
    ${test_function}
    local result=$?
    
    # Check the result
    if [[ ${result} -eq 0 ]]; then
        echo "✓ Test passed: ${test_name}"
        return 0
    else
        echo "✗ Test failed: ${test_name}"
        return 1
    fi
}

# Test base system setup
test_base_system() {
    # Check if required packages are installed
    is_package_installed "nginx" || return 1
    is_package_installed "openssl" || return 1
    is_package_installed "curl" || return 1
    
    # Check if directories exist
    [ -d "/var/www/diycloud" ] || return 1
    [ -d "/etc/diycloud" ] || return 1
    [ -d "/var/log/diycloud" ] || return 1
    
    # Check if logrotate configuration exists
    [ -f "/etc/logrotate.d/diycloud" ] || return 1
    
    return 0
}

# Test Nginx configuration
test_nginx_config() {
    # Check if Nginx configuration files exist
    NGINX_CONF=$(get_config_path "nginx")
    [ -f "${NGINX_CONF}/nginx.conf" ] || return 1
    [ -f "${NGINX_CONF}/ssl-params.conf" ] || return 1
    
    # Check if Nginx sites configuration exists
    NGINX_SITES=$(get_config_path "nginx_sites")
    [ -f "${NGINX_SITES}/portal.conf" ] || return 1
    
    # Test Nginx configuration
    nginx -t &> /dev/null || return 1
    
    # Check if Nginx is running
    is_service_active "nginx" || return 1
    
    return 0
}

# Test web portal
test_web_portal() {
    # Check if web portal files exist
    [ -f "/var/www/diycloud/index.html" ] || return 1
    [ -f "/var/www/diycloud/css/style.css" ] || return 1
    [ -f "/var/www/diycloud/js/scripts.js" ] || return 1
    [ -f "/var/www/diycloud/503.html" ] || return 1
    
    # Test HTTP redirect to HTTPS
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
    if [[ ${http_status} != "301" ]]; then
        echo "HTTP redirect test failed: Expected 301, got ${http_status}"
        return 1
    fi
    
    # Test HTTPS access (ignore SSL certificate verification for self-signed cert)
    local https_status=$(curl -s -k -o /dev/null -w "%{http_code}" https://localhost)
    if [[ ${https_status} != "200" ]]; then
        echo "HTTPS access test failed: Expected 200, got ${https_status}"
        return 1
    fi
    
    return 0
}

# Test SSL certificate
test_ssl_certificate() {
    # Check if SSL certificate and key exist
    [ -f "/etc/ssl/certs/diycloud.crt" ] || return 1
    [ -f "/etc/ssl/private/diycloud.key" ] || return 1
    
    # Check certificate validity
    openssl x509 -noout -in /etc/ssl/certs/diycloud.crt &> /dev/null || return 1
    
    # Get certificate information
    local cert_subject=$(openssl x509 -noout -subject -in /etc/ssl/certs/diycloud.crt)
    local cert_issuer=$(openssl x509 -noout -issuer -in /etc/ssl/certs/diycloud.crt)
    local cert_dates=$(openssl x509 -noout -dates -in /etc/ssl/certs/diycloud.crt)
    
    echo "Certificate Subject: ${cert_subject}"
    echo "Certificate Issuer: ${cert_issuer}"
    echo "Certificate Dates: ${cert_dates}"
    
    return 0
}

# Run all tests
run_test "Base System Setup" test_base_system
BASE_RESULT=$?

run_test "Nginx Configuration" test_nginx_config
NGINX_RESULT=$?

run_test "Web Portal" test_web_portal
PORTAL_RESULT=$?

run_test "SSL Certificate" test_ssl_certificate
SSL_RESULT=$?

# Print test summary
echo -e "\n=== Test Summary ==="
echo "Base System Setup: $([ ${BASE_RESULT} -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "Nginx Configuration: $([ ${NGINX_RESULT} -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "Web Portal: $([ ${PORTAL_RESULT} -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "SSL Certificate: $([ ${SSL_RESULT} -eq 0 ] && echo "PASSED" || echo "FAILED")"

# Calculate overall result
TOTAL_TESTS=4
PASSED_TESTS=0
[ ${BASE_RESULT} -eq 0 ] && ((PASSED_TESTS++))
[ ${NGINX_RESULT} -eq 0 ] && ((PASSED_TESTS++))
[ ${PORTAL_RESULT} -eq 0 ] && ((PASSED_TESTS++))
[ ${SSL_RESULT} -eq 0 ] && ((PASSED_TESTS++))

echo "Total tests: ${TOTAL_TESTS}"
echo "Passed: ${PASSED_TESTS}"
echo "Failed: $((TOTAL_TESTS - PASSED_TESTS))"

if [[ ${PASSED_TESTS} -eq ${TOTAL_TESTS} ]]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed."
    exit 1
fi
```

### 7.2 Running the Test Script

To run the test script:

```bash
# Copy the test script
cp test_core_platform.sh /opt/diycloud/test_core_platform.sh
chmod +x /opt/diycloud/test_core_platform.sh

# Run the test script
sudo /opt/diycloud/test_core_platform.sh
```

## 8. Complete Implementation Script

Here's a complete implementation script that combines all components:

```bash
#!/usr/bin/env bash

# Set the base directory for the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"

# Source the Distribution Abstraction Layer
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/package_manager.sh"
source "${BASE_DIR}/service_manager.sh"
source "${BASE_DIR}/path_resolver.sh"
source "${BASE_DIR}/resource_adapter.sh"
source "${BASE_DIR}/common.sh"

# Directory paths
CORE_DIR="/opt/diycloud/core"
NGINX_DIR="${CORE_DIR}/nginx"
PORTAL_DIR="${CORE_DIR}/portal"
SSL_DIR="${CORE_DIR}/ssl"

# Function to run a specific implementation step
run_step() {
    local step_name="$1"
    local step_function="$2"
    
    log_message "Running step: ${step_name}" "info"
    
    # Run the step function
    ${step_function}
    local result=$?
    
    # Check the result
    if [[ ${result} -eq 0 ]]; then
        log_message "Step completed successfully: ${step_name}" "info"
        return 0
    else
        log_message "Step failed: ${step_name}" "error"
        return 1
    fi
}

# Step 1: Setup base system
setup_base_system() {
    log_message "Setting up base system..." "info"
    
    # Update package lists
    log_message "Updating package lists..." "info"
    update_package_lists
    
    # Install required packages
    log_message "Installing required packages..." "info"
    install_package "nginx"
    install_package "openssl"
    install_package "curl"
    install_package "ca-certificates"
    install_package "logrotate"
    
    # Create necessary directories
    log_message "Creating necessary directories..." "info"
    ensure_directory "/var/www/diycloud" "www-data:www-data" "755"
    ensure_directory "/etc/diycloud" "root:root" "755"
    ensure_directory "/var/log/diycloud" "root:root" "755"
    
    # Configure firewall if available
    if command_exists "ufw"; then
        log_message "Configuring UFW firewall..." "info"
        ufw allow 80/tcp
        ufw allow 443/tcp
    elif command_exists "firewalld"; then
        log_message "Configuring FirewallD..." "info"
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    elif command_exists "iptables"; then
        log_message "Configuring iptables..." "info"
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
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
    
    return 0
}

# Step 2: Configure Nginx
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
    
    # Create main Nginx configuration
    cat > "${NGINX_DIR}/nginx.conf" << EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

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
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Logging Settings
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip Settings
    gzip on;

    # Virtual Host Configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF
    
    # Create SSL parameters configuration
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
    
    # Create web portal virtual host configuration
    cat > "${NGINX_DIR}/portal.conf" << EOF
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
    
    # Custom error pages
    error_page 503 /503.html;
    location = /503.html {
        root /var/www/diycloud;
    }
}
EOF
    
    # Copy Nginx configuration files
    log_message "Copying Nginx configuration files..." "info"
    cp "${NGINX_DIR}/nginx.conf" "${NGINX_CONF}/nginx.conf"
    cp "${NGINX_DIR}/ssl-params.conf" "${NGINX_CONF}/ssl-params.conf"
    cp "${NGINX_DIR}/portal.conf" "${NGINX_SITES}/portal.conf"
    
    # Enable the portal site
    log_message "Enabling portal site..." "info"
    if [[ "${NGINX_SITES}" != "${NGINX_ENABLED}" ]]; then
        # For Debian-style with sites-available and sites-enabled
        ln -sf "${NGINX_SITES}/portal.conf" "${NGINX_ENABLED}/portal.conf"
    fi
    
    return 0
}

# Step 3: Create web portal
create_web_portal() {
    log_message "Creating web portal..." "info"
    
    # Create portal directories
    ensure_directory "${PORTAL_DIR}/css" "root:root" "755"
    ensure_directory "${PORTAL_DIR}/js" "root:root" "755"
    ensure_directory "${PORTAL_DIR}/assets" "root:root" "755"
    
    # Create index.html
    cat > "${PORTAL_DIR}/index.html" << EOF
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
    
    # Create style.css
    cat > "${PORTAL_DIR}/css/style.css" << EOF
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
a {
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
nav ul li a, nav ul li a.active {
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
.service-card {
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
.button {
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
.back-button {
background-color: #0055aa;
text-decoration: none;
}
EOF
# Create scripts.js
cat > "${PORTAL_DIR}/js/scripts.js" << EOF
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
# Create 503.html
cat > "${PORTAL_DIR}/503.html" << EOF
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
# Create a simple logo (placeholder)
if command_exists "base64"; then
    # Base64 encoded simple SVG logo
    local logo_base64="PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAgMTAwIj48cGF0aCBmaWxsPSIjMDA2NmNjIiBkPSJNNTAsMTBjLTIyLjYsMC00MSwyMi40LTQxLDQ1YzAsMjIuNiwxOC40LDM1LDQxLDM1czQxLTEyLjQsNDEtMzVDOTEsMzIuNCw3Mi42LDEwLDUwLDEweiIvPjxwYXRoIGZpbGw9IiNGRkYiIGQ9Ik0zNSw0MGgyNXYyNUgzNVY0MHoiLz48cGF0aCBmaWxsPSIjRkZGIiBkPSJNNDAsNjVoMzB2MTJINDB2LTEyeiIvPjxwYXRoIGZpbGw9IiNGRkYiIGQ9Ik02MCw0MGgxNXYyNUg2MFY0MHoiLz48L3N2Zz4="
    echo "${logo_base64}" | base64 -d > "${PORTAL_DIR}/assets/logo.png"
else
    log_message "base64 command not found, skipping logo creation" "warning"
    # Create an empty file as a placeholder
    touch "${PORTAL_DIR}/assets/logo.png"
fi

# Copy web portal files to web root
log_message "Copying web portal files to web root..." "info"
cp -r "${PORTAL_DIR}"/* "/var/www/diycloud/"

# Set appropriate permissions
chown -R www-data:www-data "/var/www/diycloud"
find "/var/www/diycloud" -type d -exec chmod 755 {} \;
find "/var/www/diycloud" -type f -exec chmod 644 {} \;

return 0
}
Step 4: Setup SSL certificates
setup_ssl_certificates() {
log_message "Setting up SSL certificates..." "info"
# Create SSL directory
ensure_directory "${SSL_DIR}" "root:root" "755"

# Create SSL certificate generation script
cat > "${SSL_DIR}/generate-cert.sh" << EOF
#!/usr/bin/env bash
Source the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/common.sh"
Default values
DOMAIN=$(hostname -f)
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
DAYS=365
Parse arguments
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
Create directories if they don't exist
ensure_directory "${CERT_DIR}" "root" "755"
ensure_directory "${KEY_DIR}" "root" "710"
Generate self-signed certificate
openssl req -x509 -nodes -days ${DAYS} -newkey rsa:2048 \
-keyout "${KEY_DIR}/diycloud.key" \
-out "${CERT_DIR}/diycloud.crt" \
-subj "/CN=${DOMAIN}" \
-addext "subjectAltName=DNS:${DOMAIN},DNS,IP:127.0.0.1"
Set appropriate permissions
chmod 600 "${KEY_DIR}/diycloud.key"
chmod 644 "${CERT_DIR}/diycloud.crt"
log_message "SSL certificate generation completed" "info"
log_message "Certificate: ${CERT_DIR}/diycloud.crt" "info"
log_message "Private key: ${KEY_DIR}/diycloud.key" "info"
EOF
# Make the script executable
chmod +x "${SSL_DIR}/generate-cert.sh"

# Generate self-signed certificate
log_message "Generating self-signed SSL certificate..." "info"
"${SSL_DIR}/generate-cert.sh" --domain "$(hostname -f)"

return 0
}
Step 5: Test Nginx configuration
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
Main function
main() {
log_message "Starting Core Platform Module implementation..." "info"
log_message "Distribution: ${DISTRO} ${DISTRO_VERSION} (${DISTRO_FAMILY} family)" "info"
# Create necessary directories
ensure_directory "${CORE_DIR}" "root:root" "755"
ensure_directory "${NGINX_DIR}" "root:root" "755"
ensure_directory "${PORTAL_DIR}" "root:root" "755"
ensure_directory "${SSL_DIR}" "root:root" "755"

# Run all steps
run_step "Setup Base System" setup_base_system || return 1
run_step "Configure Nginx" configure_nginx || return 1
run_step "Create Web Portal" create_web_portal || return 1
run_step "Setup SSL Certificates" setup_ssl_certificates || return 1
run_step "Test Nginx Configuration" test_nginx_configuration || return 1

log_message "Core Platform Module implemented successfully" "info"

# Print access information
local ip_address=$(get_primary_ip)
log_message "You can access the DIY Cloud Platform at:" "info"
log_message "  https://${ip_address}/" "info"

return 0
}
Run the main function
main
exit $?

## 9. Extension Points and Best Practices

### 9.1 Extension Points

The Core Platform Module is designed with several extension points for future phases:

1. **Web Portal Extensions**
   - Add user authentication in Phase 2
   - Integrate JupyterHub in Phase 3
   - Integrate Docker/Portainer in Phase 3
   - Add monitoring dashboards in Phase 4

2. **Nginx Configuration Extensions**
   - Add reverse proxy for JupyterHub
   - Add reverse proxy for Portainer
   - Add reverse proxy for Monitoring services

3. **SSL Certificate Extensions**
   - Implement Let's Encrypt for production environments
   - Add certificate renewal automation

### 9.2 Best Practices

When implementing the Core Platform Module, follow these best practices:

1. **Distribution Compatibility**
   - Always use the Distribution Abstraction Layer for operations
   - Test on all supported distributions
   - Document any distribution-specific behaviors

2. **Security**
   - Use strong SSL/TLS configurations
   - Implement appropriate security headers
   - Restrict file permissions
   - Configure firewall rules

3. **Error Handling**
   - Implement proper error checking for all operations
   - Provide helpful error messages and log entries
   - Create appropriate error pages for users

4. **Modularity**
   - Keep components independent and modular
   - Use clear interfaces between components
   - Avoid hardcoding paths or configuration values

5. **Documentation**
   - Document all components and their configurations
   - Include inline comments in scripts
   - Document installation and usage procedures

## 10. Troubleshooting Common Issues

### 10.1 Nginx Configuration Issues

**Problem**: Nginx fails to start or reports configuration errors.

**Solution**:
1. Check the configuration syntax:
   ```bash
   nginx -t

Review error messages in the Nginx error log:
bashcat /var/log/nginx/error.log

Ensure the SSL certificates exist and have the correct permissions:
bashls -la /etc/ssl/certs/diycloud.crt
ls -la /etc/ssl/private/diycloud.key

Verify that the configuration paths are correct for your distribution:
bashsource /opt/diycloud/lib/detect_distro.sh
source /opt/diycloud/lib/path_resolver.sh
echo "Nginx config path: $(get_config_path "nginx")"


10.2 SSL Certificate Issues
Problem: SSL certificate is not trusted by browsers.
Solution:

For development, add an exception in your browser for the self-signed certificate.
For production, consider using Let's Encrypt for trusted certificates.
Ensure the certificate's Common Name (CN) matches the server's hostname:
bashopenssl x509 -noout -subject -in /etc/ssl/certs/diycloud.crt
hostname -f


10.3 File Permission Issues
Problem: Web portal files are not accessible or show "Permission denied" errors.
Solution:

Ensure the web server has appropriate permissions:
bashchown -R www-data:www-data /var/www/diycloud
find /var/www/diycloud -type d -exec chmod 755 {} \;
find /var/www/diycloud -type f -exec chmod 644 {} \;

Check SELinux contexts (on systems with SELinux):
bashif command_exists "restorecon"; then
    restorecon -Rv /var/www/diycloud
fi


10.4 Distribution-Specific Issues
Problem: Implementation fails on specific distributions.
Solution:

Check if the Distribution Abstraction Layer properly detects your distribution:
bashsource /opt/diycloud/lib/detect_distro.sh
echo "Distribution: ${DISTRO} ${DISTRO_VERSION} (${DISTRO_FAMILY} family)"

Verify that the package, service, and path management functions work correctly on your distribution:
bashsource /opt/diycloud/lib/package_manager.sh
source /opt/diycloud/lib/service_manager.sh
source /opt/diycloud/lib/path_resolver.sh

# Test package management
echo "Nginx package name: $(get_package_name "nginx")"

# Test service management
echo "Service manager: ${SERVICE_MANAGER}"

# Test path resolution
echo "Nginx config path: $(get_config_path "nginx")"

Review logs for distribution-specific errors:
bashcat /var/log/diycloud/*.log


11. Conclusion
The Core Platform Module establishes the foundation for the DIY Cloud Platform. By implementing the base system, Nginx configuration, web portal, and SSL certificate management, you have created a solid foundation that will support all other modules in future phases.
This implementation guide provides detailed instructions for creating each component, but remember that the Distribution Abstraction Layer is key to ensuring compatibility across different Linux distributions. Always use the abstraction functions provided by the layer, and test your implementation on all target distributions.
With the Core Platform Module in place, you're ready to move on to Phase 2: User & Resource Management, where you'll implement user creation, authentication, and resource allocation.
Happy cloud building!