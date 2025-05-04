# DIY Cloud Platform

A self-hosted resource sharing platform that allows you to turn any Linux server into a multi-user cloud environment. Share your CPU, RAM, GPU, and disk resources with others through JupyterHub notebooks and Docker containers. Compatible with multiple Linux distributions including Ubuntu, Debian, CentOS/RHEL, Fedora, Arch Linux, and OpenSUSE.

## Project Status

This project is currently in active development. We have completed Phase 0 (Distribution Abstraction Layer), Phase 1 (Core Platform Module), and Phase 2 (User & Resource Management). The next step is to implement Phase 3 (Service Modules).

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
│   │   ├── nginx.conf          # Base Nginx configuration
│   │   ├── ssl-params.conf     # SSL parameters
│   │   └── portal.conf         # Virtual host for the portal
│   └── portal/                 # Web portal files
│       ├── index.html          # Main portal page
│       ├── css/                # CSS files
│       │   └── style.css       # Main stylesheet
│       ├── js/                 # JavaScript files
│       │   └── scripts.js      # Main script file
│       └── assets/             # Images and other assets
│           └── logo.svg        # DIY Cloud Platform logo
│
├── usermgmt/                   # User Management Module (Phase 2)
│   ├── create_user.sh          # User creation script
│   ├── set_quota.sh            # Set user quotas
│   ├── user_management.py      # Python API for user management
│   ├── db/                     # Database files
│   │   ├── init_db.sh          # Database initialization script
│   │   └── schema.sql          # Database schema
│   └── auth/                   # Authentication files
│       └── pam_config.sh       # PAM configuration script
│
├── resources/                  # Resource Management Module (Phase 2)
│   ├── cpu_manager.sh          # CPU resource management
│   ├── mem_manager.sh          # Memory resource management
│   ├── disk_manager.sh         # Disk quota management
│   ├── gpu_manager.sh          # GPU access management
│   └── apply_limits.sh         # Apply resource limits to user
│
├── jupyterhub/                 # JupyterHub files (Phase 3)
├── docker/                     # Docker/Portainer files (Phase 3)
├── monitoring/                 # Monitoring files (Phase 4)
│
├── test_distribution_abstraction.sh  # Test script for the Distribution Abstraction Layer
├── test_core_platform.sh             # Test script for the Core Platform Module
├── test_phase2.sh                    # Test script for Phase 2
├── install.sh                        # Main installation script
└── README.md                         # This file
```

## Development Status

- **Phase 0: Distribution Abstraction**: ✓ Completed
  - Distribution detection ✓
  - Package management ✓
  - Service management ✓
  - Path resolution ✓
  - Resource management adaptation ✓
  - Testing framework ✓

- **Phase 1: Foundation**: ✓ Completed
  - Base system setup ✓
  - Web portal implementation ✓
  - Nginx configuration ✓
  - Cross-distribution compatibility ✓

- **Phase 2: User & Resource Management**: ✓ Completed
  - User creation and management ✓
  - Authentication and role-based access control ✓
  - Resource allocation and limits ✓
  - RESTful API for user management ✓
  - Database integration with SQLite ✓

- **Phase 3: Service Modules**: 🔄 In Progress
  - JupyterHub integration
  - Docker with Portainer setup
  - Container templates and networks
  - Service authentication integration

- **Phase 4: Monitoring & Refinement**: Not started
- **Phase 5: Documentation & Release**: Not started

## Development Setup

### Prerequisites

- Any of the following Linux distributions:
  - Ubuntu 20.04+ LTS
  - Debian 11+ (Bullseye)
  - CentOS/RHEL 8+
  - Fedora 35+
  - Arch Linux (Rolling)
  - OpenSUSE Leap 15.3+
- Git
- Bash 4.0+
- Nginx
- SQLite (for Phase 2)
- Python 3.8+ with Flask (for Phase 2)
- Docker and Docker Compose (for Phase 3)
- JupyterHub and dependencies (for Phase 3)

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/diy-cloud-platform.git
   cd diy-cloud-platform
   ```

2. Run the test scripts to verify compatibility:
   ```bash
   # Test Distribution Abstraction Layer
   sudo ./test_distribution_abstraction.sh
   
   # Test Core Platform Module
   sudo ./test_core_platform.sh
   
   # Test Phase 2 (User & Resource Management)
   sudo ./test_phase2.sh
   ```

3. To install the system:
   ```bash
   sudo ./install.sh
   ```

4. Access the web portal:
   ```
   http://localhost/diycloud/
   ```

## Using the Distribution Abstraction Layer

The Distribution Abstraction Layer allows your code to work across multiple Linux distributions by abstracting distribution-specific differences:

```bash
# Source the Distribution Abstraction Layer scripts
source lib/detect_distro.sh
source lib/package_manager.sh
source lib/service_manager.sh
source lib/path_resolver.sh
source lib/resource_adapter.sh
source lib/common.sh

# Install a package (works across distributions)
install_package "nginx"

# Start a service (works with systemd or SysV)
start_service "nginx"

# Get configuration path (handles distribution differences)
nginx_config=$(get_config_path "nginx")

# Apply resource limits (works with cgroups v1 or v2)
apply_cpu_limit "username" "1.0"
```

## Working on Phase 3

Phase 3 focuses on implementing the service modules:

### JupyterHub Module
- Installation and configuration
- User authentication integration
- Resource limits integration
- Notebook environment setup

### Docker/Portainer Module
- Docker installation and configuration
- Portainer setup
- Container templates and networks
- User authentication integration

See the Phase 3 Planning Document for detailed instructions on implementing these modules.

## User Management API

The User Management API provides a RESTful interface for managing users and resources:

```bash
# Health check
curl http://localhost:5000/api/health

# Login with admin user
curl -X POST -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your_password"}' \
  http://localhost:5000/api/auth/login

# List users (with authentication token)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/users

# Get resource allocations
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/api/resources/1
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

The Apache License 2.0 is a permissive license that allows you to:
- Use the software for commercial purposes
- Modify the software and create derivative works
- Distribute original or modified versions of the software
- Sublicense the software

While requiring you to:
- Include the license and copyright notice with redistributions
- Document significant changes made to the software
- Not use the names of contributors for promotion without permission

Additionally, the license provides an express grant of patent rights from contributors to users.