# Phase 0: Distribution Abstraction Layer - Quick Start Guide

This guide will help you get started with the development of Phase 0 of the DIY Cloud Platform project - the Distribution Abstraction Layer (DAL). The DAL is a crucial component that enables the platform to work across multiple Linux distributions.

## Prerequisites

- A Linux development environment (any of the supported distributions)
- Root or sudo access for testing
- Git for version control
- Basic knowledge of Bash scripting

## Getting the Code

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/diy-cloud-platform.git
   cd diy-cloud-platform
   ```

2. Explore the project structure:
   ```bash
   ls -la
   # You should see the lib/ directory which contains the DAL components
   ```

## Understanding the Distribution Abstraction Layer

The Distribution Abstraction Layer consists of several components:

1. **detect_distro.sh**: Detects the Linux distribution and sets up environment variables
2. **package_manager.sh**: Abstracts package management across distributions
3. **service_manager.sh**: Provides a unified interface for service management
4. **path_resolver.sh**: Resolves file paths that differ between distributions
5. **resource_adapter.sh**: Manages system resources with cgroups v1/v2 compatibility
6. **common.sh**: Common utility functions

## Testing the Distribution Abstraction Layer

Run the test script to verify that the Distribution Abstraction Layer works correctly:

```bash
sudo ./test_distribution_abstraction.sh
```

This will test all components of the layer and produce a summary report.

## Developing the Distribution Abstraction Layer

### 1. Distribution Detection

Ensure the script can detect all supported distributions:
- Ubuntu 20.04+ LTS
- Debian 11+ (Bullseye)
- CentOS/RHEL 8+
- Fedora 35+
- Arch Linux
- OpenSUSE Leap 15.3+

Add support for a new distribution by updating the `detect_distribution()` function in `lib/detect_distro.sh`.

### 2. Package Management

Extend package name mappings for different distributions in `lib/package_manager.sh`:

```bash
# Add mappings for a new package
PACKAGE_NAMES["debian:new_package"]="debian_package_name"
PACKAGE_NAMES["redhat:new_package"]="redhat_package_name"
PACKAGE_NAMES["arch:new_package"]="arch_package_name"
PACKAGE_NAMES["suse:new_package"]="suse_package_name"
```

### 3. Service Management

Ensure service management works across init systems (systemd and SysV) in `lib/service_manager.sh`.

### 4. Path Resolution

Add paths for new services or applications in `lib/path_resolver.sh`:

```bash
# Add configuration paths for a new service
CONFIG_PATHS["debian:new_service"]="/etc/new_service"
CONFIG_PATHS["redhat:new_service"]="/etc/new_service"
CONFIG_PATHS["arch:new_service"]="/etc/new_service"
CONFIG_PATHS["suse:new_service"]="/etc/new_service"
```

### 5. Resource Management

Ensure resource management works with both cgroups v1 and v2 in `lib/resource_adapter.sh`.

## Multi-Distribution Testing

Test on different distributions using virtual machines or containers:

```bash
# For Debian/Ubuntu
docker run -it --privileged ubuntu:20.04 /bin/bash

# For RHEL/CentOS
docker run -it --privileged rockylinux:8 /bin/bash

# For Fedora
docker run -it --privileged fedora:35 /bin/bash

# For Arch Linux
docker run -it --privileged archlinux:latest /bin/bash

# For OpenSUSE
docker run -it --privileged opensuse/leap:15.3 /bin/bash
```

Once inside the container, you can clone the repository and run the tests:

```bash
apt-get update && apt-get install -y git sudo # For Debian/Ubuntu
dnf install -y git sudo # For RHEL/Fedora
pacman -Sy --noconfirm git sudo # For Arch
zypper install -y git sudo # For OpenSUSE

git clone https://github.com/your-username/diy-cloud-platform.git
cd diy-cloud-platform
sudo ./test_distribution_abstraction.sh
```

## Debugging Tips

1. Enable verbose output by adding `set -x` at the beginning of scripts
2. Log messages using the `log_message` function from `common.sh`
3. Test individual functions by sourcing the scripts and calling them directly:

```bash
source lib/detect_distro.sh
detect_distribution
echo $DISTRO
```

## Documentation

Document all changes and additions to the Distribution Abstraction Layer:

1. Add comments to explain complex logic
2. Update function descriptions
3. Document distribution-specific behavior
4. Update the Implementation Guide

## Next Steps

Once the Distribution Abstraction Layer is complete and tested across all target distributions, you can move on to Phase 1: Foundation, which includes setting up the Core Platform Module, Nginx, and the web portal.

## Help and Support

If you encounter any issues or have questions, please:

1. Check the detailed documentation in the `docs` directory
2. Use the issue tracker on GitHub
3. Contact the project maintainers

Happy coding!
