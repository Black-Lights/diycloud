# Distribution Abstraction Layer: Implementation Guide

This guide provides detailed instructions for implementing and utilizing the Distribution Abstraction Layer (DAL) in the DIY Cloud Platform. The DAL enables your code to work across multiple Linux distributions by abstracting distribution-specific differences.

## 1. Introduction

The Distribution Abstraction Layer handles differences between Linux distributions in:

- Package management (apt, dnf, pacman, zypper)
- Service management (systemd, SysV init)
- File paths and configurations
- Resource management (cgroups v1 and v2)

By using the DAL, you can write code that works seamlessly across Ubuntu, Debian, CentOS/RHEL, Fedora, Arch Linux, and OpenSUSE without maintaining separate code paths.

## 2. Directory Structure

```
/opt/diycloud/lib/
├── detect_distro.sh       # Distribution detection script
├── package_manager.sh     # Package management functions
├── service_manager.sh     # Service management functions
├── path_resolver.sh       # Path resolution functions
├── resource_adapter.sh    # Resource management adaptation
└── common.sh              # Common utilities and variables
```

## 3. Using the Distribution Abstraction Layer

### 3.1 Including the DAL in Your Scripts

To use the DAL in your scripts, source the required components at the beginning of your script:

```bash
#!/usr/bin/env bash

# Set the base directory for the Distribution Abstraction Layer
BASE_DIR="/opt/diycloud/lib"

# Source the required components
source "${BASE_DIR}/detect_distro.sh"
source "${BASE_DIR}/package_manager.sh"  # If you need package management
source "${BASE_DIR}/service_manager.sh"  # If you need service management
source "${BASE_DIR}/path_resolver.sh"    # If you need path resolution
source "${BASE_DIR}/resource_adapter.sh" # If you need resource management
source "${BASE_DIR}/common.sh"           # Common utilities
```

Always source `detect_distro.sh` first, as other scripts depend on the variables it sets.

### 3.2 Distribution Detection

After sourcing `detect_distro.sh`, you have access to these variables:

- `DISTRO`: The distribution ID (e.g., "ubuntu", "debian", "centos")
- `DISTRO_VERSION`: The distribution version (e.g., "20.04", "11")
- `DISTRO_VERSION_ID`: The version ID (e.g., "20.04", "11")
- `DISTRO_CODENAME`: The distribution codename (e.g., "focal", "bullseye")
- `DISTRO_FAMILY`: The distribution family (e.g., "debian", "redhat", "arch", "suse")
- `PACKAGE_MANAGER`: The package manager (e.g., "apt", "dnf", "pacman", "zypper")
- `SERVICE_MANAGER`: The service manager (e.g., "systemd", "sysv")
- `CGROUP_VERSION`: The cgroups version (e.g., "v1", "v2", "hybrid")

You can use these variables to make distribution-specific decisions when needed:

```bash
if [[ "${DISTRO_FAMILY}" == "debian" ]]; then
    # Debian-specific code
elif [[ "${DISTRO_FAMILY}" == "redhat" ]]; then
    # RedHat-specific code
fi
```

However, it's better to use the abstraction functions whenever possible.

### 3.3 Package Management

The `package_manager.sh` script provides functions for managing packages across distributions:

#### Installing Packages

```bash
# Install a package
install_package "nginx"

# Install multiple packages
install_package "python3"
install_package "nodejs"
install_package "docker"
```

The function handles distribution-specific package names. For example, Docker might be called "docker.io" on Debian/Ubuntu but "docker-ce" on RHEL.

#### Checking for Installed Packages

```bash
# Check if a package is installed
if is_package_installed "nginx"; then
    echo "Nginx is installed"
else
    echo "Nginx is not installed"
    install_package "nginx"
fi
```

#### Managing Repositories

```bash
# Add a repository
add_repository "docker" "https://download.docker.com/linux/$DISTRO $DISTRO_CODENAME stable"

# Update package lists
update_package_lists
```

#### Other Package Management Functions

- `remove_package "package_name"` - Remove a package
- `upgrade_system` - Upgrade all packages
- `install_package_group "group_name"` - Install a package group
- `clean_package_cache` - Clean package cache

### 3.4 Service Management

The `service_manager.sh` script provides functions for managing services:

#### Managing Services

```bash
# Start a service
start_service "nginx"

# Stop a service
stop_service "nginx"

# Restart a service
restart_service "nginx"

# Enable a service to start at boot
enable_service "nginx"

# Disable a service at boot
disable_service "nginx"
```

#### Checking Service Status

```bash
# Check service status
service_status "nginx"

# Check if a service is active
if is_service_active "nginx"; then
    echo "Nginx is running"
else
    echo "Nginx is not running"
    start_service "nginx"
fi

# Check if a service is enabled at boot
if is_service_enabled "nginx"; then
    echo "Nginx is enabled at boot"
else
    echo "Nginx is not enabled at boot"
    enable_service "nginx"
fi
```

#### Creating Services

```bash
# Create a systemd service
create_systemd_service "myapp" "My Application" "/usr/bin/myapp" "myuser" "/opt/myapp"
```

### 3.5 Path Resolution

The `path_resolver.sh` script provides functions for resolving file paths:

#### Getting Configuration Paths

```bash
# Get configuration path for a service
nginx_config=$(get_config_path "nginx")
echo "Nginx configuration directory: ${nginx_config}"

# Get specific locations
nginx_sites=$(get_config_path "nginx_sites")
echo "Nginx sites directory: ${nginx_sites}"
```

#### Getting Log Paths

```bash
# Get log path for a service
nginx_log=$(get_log_path "nginx")
echo "Nginx log directory: ${nginx_log}"
```

#### Other Path Functions

- `get_lib_path "library_name"` - Get library path
- `get_bin_path "binary_name"` - Get binary path
- `get_service_name "service_identifier"` - Get service name
- `get_cgroup_path ["subsystem"]` - Get cgroup path
- `get_python_path` - Get Python executable path
- `get_pip_path` - Get pip executable path
- `ensure_directory "directory_path" ["owner:group"] ["permissions"]` - Create a directory if it doesn't exist

### 3.6 Resource Management

The `resource_adapter.sh` script provides functions for managing system resources:

#### Managing User Resources

```bash
# Apply resource limits for a user
apply_user_resource_limits "username" "1.0" "1024" "5120"
# This applies:
# - 1.0 CPU cores
# - 1024 MB memory
# - 5120 MB disk quota

# Apply individual limits
apply_cpu_limit "username" "0.5"        # Limit to 0.5 CPU cores
apply_memory_limit "username" "512"     # Limit to 512 MB memory
setup_disk_quota "username" "1024" "2048" # Soft limit: 1 GB, Hard limit: 2 GB
```

#### GPU Access

```bash
# Enable GPU access for a user
if is_nvidia_gpu_available; then
    enable_gpu_access "username"
fi

# Disable GPU access for a user
disable_gpu_access "username"
```

#### Resource Monitoring

```bash
# Get system resources
get_system_resources

# Get user's resource limits
get_user_resource_limits "username"

# Get user's resource usage
cpu_usage=$(get_user_cpu_usage "username")
memory_usage=$(get_user_memory_usage "username")
disk_usage=$(get_user_disk_usage "username")
```

### 3.7 Common Utilities

The `common.sh` script provides utility functions:

#### Logging

```bash
# Log messages
log_message "Installing package" "info"
log_message "Failed to start service" "error"
log_message "Resource limit not set" "warning"

# Check command result and log
install_package "nginx"
check_result $? "Nginx installed successfully" "Failed to install Nginx"
```

#### File and Directory Operations

```bash
# Create a directory
create_directory "/opt/myapp" "myuser:mygroup" "755"

# Backup a file before modifying it
backup_file "/etc/nginx/nginx.conf"
```

#### User Input and Validation

```bash
# Prompt for input
hostname=$(prompt_input "Enter hostname" "localhost")

# Prompt for password (masked)
password=$(prompt_password "Enter password")

# Prompt for yes/no
if prompt_yn "Install Nginx?"; then
    install_package "nginx"
fi

# Validate input
if is_valid_username "${username}"; then
    echo "Valid username"
else
    echo "Invalid username"
fi

if is_valid_ip "${ip_address}"; then
    echo "Valid IP address"
else
    echo "Invalid IP address"
fi
```

#### Other Utility Functions

- `generate_password [length]` - Generate a secure random password
- `is_port_available "port_number"` - Check if a port is available
- `generate_ssl_cert "domain" "output_dir"` - Generate a self-signed SSL certificate
- `get_primary_ip` - Get the primary IP address of the system
- `get_hostname` - Get the hostname of the system
- `get_fqdn` - Get the fully qualified domain name
- `command_exists "command_name"` - Check if a command exists
- `wait_for_service "host" "port" ["timeout_seconds"]` - Wait for a service to be ready

## 4. Best Practices

1. **Always source detect_distro.sh first**: This sets up the environment variables needed by other scripts.

2. **Use abstraction functions**: Instead of directly using commands like `apt-get install`, use the provided functions like `install_package`.

3. **Handle errors properly**: Check the return values of functions and handle errors gracefully.

4. **Test across distributions**: Test your code on all target distributions to ensure compatibility.

5. **Minimize distribution-specific code**: If you need distribution-specific code, isolate it and consider adding it to the abstraction layer.

6. **Document distribution-specific behavior**: If you find different behaviors across distributions, document them for others.

## 5. Examples

### Example 1: Installing and Configuring Nginx

```bash
#!/usr/bin/env bash

# Load the Distribution Abstraction Layer
source "/opt/diycloud/lib/detect_distro.sh"
source "/opt/diycloud/lib/package_manager.sh"
source "/opt/diycloud/lib/service_manager.sh"
source "/opt/diycloud/lib/path_resolver.sh"
source "/opt/diycloud/lib/common.sh"

# Install Nginx
log_message "Installing Nginx..."
install_package "nginx"
check_result $? "Nginx installed successfully" "Failed to install Nginx"

# Get Nginx configuration paths
nginx_conf=$(get_config_path "nginx")
nginx_sites=$(get_config_path "nginx_sites")
nginx_enabled=$(get_config_path "nginx_enabled")

# Backup the default configuration
backup_file "${nginx_conf}/nginx.conf"

# Create a new site configuration
cat > "${nginx_sites}/myapp.conf" << EOF
server {
    listen 80;
    server_name myapp.example.com;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Enable the site
if [[ "${nginx_sites}" != "${nginx_enabled}" ]]; then
    # For Debian-style with sites-available and sites-enabled
    ln -sf "${nginx_sites}/myapp.conf" "${nginx_enabled}/myapp.conf"
fi

# Test the configuration
nginx -t
check_result $? "Nginx configuration is valid" "Nginx configuration is invalid"

# Restart Nginx
restart_service "nginx"
check_result $? "Nginx restarted successfully" "Failed to restart Nginx"

# Enable Nginx to start at boot
enable_service "nginx"
check_result $? "Nginx enabled at boot" "Failed to enable Nginx at boot"

log_message "Nginx installation and configuration completed"
```

### Example 2: Creating a User with Resource Limits

```bash
#!/usr/bin/env bash

# Load the Distribution Abstraction Layer
source "/opt/diycloud/lib/detect_distro.sh"
source "/opt/diycloud/lib/path_resolver.sh"
source "/opt/diycloud/lib/resource_adapter.sh"
source "/opt/diycloud/lib/common.sh"

# User parameters
username="datauser"
password=$(generate_password 12)
cpu_limit="1.0"
memory_limit="2048"  # 2 GB
disk_quota="10240"   # 10 GB

# Create the user
log_message "Creating user: ${username}"
useradd -m -s /bin/bash "${username}"
check_result $? "User created successfully" "Failed to create user"

# Set user password
echo "${username}:${password}" | chpasswd
check_result $? "Password set successfully" "Failed to set password"

# Apply resource limits
log_message "Applying resource limits for user: ${username}"

# Setup user cgroup
setup_user_cgroup "${username}"
check_result $? "User cgroup setup completed" "Failed to setup user cgroup"

# Apply CPU limit
apply_cpu_limit "${username}" "${cpu_limit}"
check_result $? "CPU limit applied successfully" "Failed to apply CPU limit"

# Apply memory limit
apply_memory_limit "${username}" "${memory_limit}"
check_result $? "Memory limit applied successfully" "Failed to apply memory limit"

# Apply disk quota
setup_disk_quota "${username}" "${disk_quota}" "$((disk_quota * 2))"
check_result $? "Disk quota applied successfully" "Failed to apply disk quota"

# Check if GPU is available and grant access
if is_nvidia_gpu_available; then
    log_message "GPU detected, enabling GPU access for user: ${username}"
    enable_gpu_access "${username}"
    check_result $? "GPU access enabled successfully" "Failed to enable GPU access"
fi

# Print user information
log_message "User created with the following resource limits:"
get_user_resource_limits "${username}"

log_message "User creation completed"
echo "Username: ${username}"
echo "Password: ${password}"
```

## 6. Troubleshooting

### Common Issues

1. **Script not sourced correctly**: Ensure you're sourcing the scripts with the correct path.

2. **Permission denied**: Ensure your script is run with root privileges when needed.

3. **Command not found**: Some functions rely on external commands. Install required dependencies.

4. **Distribution not supported**: If you encounter an unsupported distribution, consider adding support to the abstraction layer.

### Testing

Use the provided `test_distribution_abstraction.sh` script to verify that the Distribution Abstraction Layer works correctly on your system:

```bash
sudo ./test_distribution_abstraction.sh
```

This script will test all components of the abstraction layer and report any issues.

## 7. Extending the Distribution Abstraction Layer

To add support for a new Linux distribution:

1. Update `detect_distro.sh` to recognize the new distribution
2. Add package name mappings in `package_manager.sh`
3. Add service management logic in `service_manager.sh` if needed
4. Add file path mappings in `path_resolver.sh`
5. Update resource management logic in `resource_adapter.sh` if needed
6. Test thoroughly on the new distribution

## 8. Conclusion

The Distribution Abstraction Layer provides a solid foundation for developing cross-distribution Linux applications. By leveraging this layer, you can focus on application logic rather than distribution-specific details, making your code more maintainable and portable.

For additional assistance, consult the test script or contact the DIY Cloud Platform development team.
