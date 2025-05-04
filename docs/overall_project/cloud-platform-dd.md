# DIY Cloud Platform: Detailed Design (DD)

## 1. Introduction

This Detailed Design (DD) document specifies the technical implementation of the DIY Cloud Platform described in the Requirements Analysis and System Design (RASD) document. It provides comprehensive guidance for independent development of each module while ensuring they integrate into a cohesive system. The design enables compatibility across multiple Linux distributions through abstraction layers and distribution-specific adaptations.

## 2. System Architecture

### 2.1 Layered Architecture

The DIY Cloud Platform follows a layered architecture pattern with a distribution abstraction layer:

```
┌───────────────────────────────────────────────────────┐
│                   Presentation Layer                  │
│   (Web Portal, JupyterHub UI, Portainer UI, Grafana)  │
└───────────────────────┬───────────────────────────────┘
                        │
┌───────────────────────▼───────────────────────────────┐
│                   Integration Layer                   │
│         (Nginx, Authentication, API Gateway)          │
└───────────────────────┬───────────────────────────────┘
                        │
┌───────────────────────▼───────────────────────────────┐
│               Distribution Abstraction Layer          │
│  (Package Management, Service Management, File Paths)  │
└───────────────────────┬───────────────────────────────┘
                        │
                ┌───────┴────────┐
                ▼                ▼
┌───────────────────────┐  ┌─────────────────────┐
│    Service Layer      │  │   Monitoring Layer   │
│ (JupyterHub, Docker)  │  │(Prometheus, Grafana) │
└───────────────────────┘  └─────────────────────┘
                │                      │
                └──────────┬───────────┘
                           │
┌──────────────────────────▼──────────────────────────┐
│                   Resource Layer                    │
│     (cgroups v1/v2, quotas, system resources)       │
└───────────────────────────────────────────────────┘
```

### 2.2 Modular Design

The system is divided into seven independent modules, each responsible for specific functionality:

1. **Distribution Abstraction Layer**
2. **Core Platform Module**
3. **User Management Module**
4. **JupyterHub Module**
5. **Docker/Portainer Module** 
6. **Resource Management Module**
7. **Monitoring Module**

### 2.3 Communication Between Modules

```
                     ┌─────────────────────┐
                     │   Distribution      │
                     │  Abstraction Layer  │
                     └─────────┬───────────┘
                               │
                               ▼
┌───────────────┐      ┌────────────────┐      ┌───────────────┐
│  Core         │      │  User          │      │  JupyterHub   │
│  Platform     │◄────►│  Management    │◄────►│  Module       │
└───────┬───────┘      └────────────────┘      └───────┬───────┘
        │                       ▲                      │
        │                       │                      │
        ▼                       │                      ▼
┌───────────────┐      ┌────────┴───────┐      ┌───────────────┐
│  Docker       │      │  Resource      │      │  Monitoring   │
│  Module       │◄────►│  Management    │◄────►│  Module       │
└───────────────┘      └────────────────┘      └───────────────┘
```

## 3. Module Specifications

### 3.1 Distribution Abstraction Layer

#### 3.1.1 Responsibilities
- Distribution detection and identification
- Package management abstraction
- Service management abstraction
- File path resolution across distributions
- Handling distribution-specific configurations

#### 3.1.2 Components

```
┌───────────────────────────────────────────────────┐
│         Distribution Abstraction Layer            │
│                                                   │
│   ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │
│   │ Distribution│  │  Package    │  │ Service  │  │
│   │  Detector   │  │  Manager    │  │ Manager  │  │
│   └─────────────┘  └─────────────┘  └──────────┘  │
│                                                   │
│   ┌─────────────┐  ┌─────────────┐               │
│   │   Path      │  │  Resource   │               │
│   │  Resolver   │  │  Adapter    │               │
│   └─────────────┘  └─────────────┘               │
└───────────────────────────────────────────────────┘
```

#### 3.1.3 Key Files

| File | Purpose |
|------|---------|
| `/opt/diycloud/lib/detect_distro.sh` | Distribution detection script |
| `/opt/diycloud/lib/package_manager.sh` | Package management functions |
| `/opt/diycloud/lib/service_manager.sh` | Service management functions |
| `/opt/diycloud/lib/path_resolver.sh` | Path resolution functions |
| `/opt/diycloud/lib/resource_adapter.sh` | Resource management adaptation |

#### 3.1.4 Key Functions

**`detect_distribution()`**
- Identifies the Linux distribution and version
- Sets global variables for distribution information
- Returns distribution ID and version

**`install_package(package_name)`**
- Installs software packages using appropriate package manager
- Handles package name differences across distributions
- Reports installation success or failure

**`get_package_name(generic_name)`**
- Translates generic package names to distribution-specific ones
- Handles different naming conventions across distributions

**`start_service(service_name)`**
- Starts services using appropriate service manager
- Supports systemd, SysV init, and others

**`enable_service(service_name)`**
- Enables services to start at boot
- Handles different service management systems

**`get_config_path(service)`**
- Returns correct configuration path for services
- Accounts for distribution-specific file locations

**`get_cgroup_path()`**
- Detects and returns appropriate cgroup path
- Supports both cgroups v1 and v2

#### 3.1.5 Dependencies

- Bash 4.0+
- Core Unix utilities
- Access to system information files

### 3.2 Core Platform Module

#### 3.1.1 Responsibilities
- Base system setup
- Web portal interface
- Nginx configuration
- Integration of all modules

#### 3.1.2 Components

```
┌───────────────────────────────────────────────────┐
│                Core Platform Module               │
│                                                   │
│   ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │
│   │  Web Portal │  │    Nginx    │  │   SSL    │  │
│   │  Frontend   │  │   Server    │  │  Manager │  │
│   └─────────────┘  └─────────────┘  └──────────┘  │
│                                                   │
└───────────────────────────────────────────────────┘
```

#### 3.1.3 Key Files

| File | Purpose |
|------|---------|
| `/var/www/html/portal/index.html` | Main portal landing page |
| `/var/www/html/portal/style.css` | Portal styling |
| `/var/www/html/portal/scripts.js` | Portal functionality |
| `/etc/nginx/sites-available/portal` | Nginx virtual host configuration |
| `/opt/diycloud/setup-base.sh` | Base system setup script |

#### 3.1.4 Key Functions

**`setup_base_system()`**
- Updates system packages
- Installs base dependencies
- Configures firewall
- Sets up Nginx

**`configure_nginx()`**
- Sets up reverse proxy for components
- Configures SSL if enabled
- Sets up location blocks for services

**`install_web_portal()`**
- Deploys web portal files
- Configures portal settings

#### 3.1.5 APIs/Interfaces

The Core Platform Module does not expose APIs but integrates with other modules through:
- File system configuration
- Nginx reverse proxy configuration
- Web portal integration points

#### 3.1.6 Dependencies

- Ubuntu 20.04 LTS or newer
- Nginx
- SSL certificates (Let's Encrypt recommended)

### 3.2 User Management Module

#### 3.2.1 Responsibilities
- User creation and management
- Authentication
- Role-based access control
- User profile management

#### 3.2.2 Components

```
┌───────────────────────────────────────────────────┐
│              User Management Module               │
│                                                   │
│   ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │
│   │  User       │  │ Authentication│ │  RBAC    │  │
│   │  Creation   │  │   Service    │  │  Service │  │
│   └─────────────┘  └─────────────┘  └──────────┘  │
│                                                   │
└───────────────────────────────────────────────────┘
```

#### 3.2.3 Key Files

| File | Purpose |
|------|---------|
| `/opt/diycloud/usermgmt/create_user.sh` | User creation script |
| `/opt/diycloud/usermgmt/set_quota.sh` | Set user quotas |
| `/opt/diycloud/usermgmt/user_db.sqlite` | User database (SQLite) |
| `/opt/diycloud/usermgmt/user_management.py` | Python API for user management |

#### 3.2.4 Key Functions

**`create_user(username, password, cpu_limit, mem_limit, disk_quota)`**
- Creates system user
- Sets initial password
- Applies resource limits
- Creates home directory structure

**`modify_user(username, attributes)`**
- Updates user attributes
- Applies new resource limits

**`delete_user(username)`**
- Removes user account
- Cleans up associated resources

**`authenticate(username, password)`**
- Authenticates user credentials
- Returns authentication token

#### 3.2.5 APIs/Interfaces

**User Management API:**
- `POST /api/users` - Create user
- `GET /api/users/:username` - Get user details
- `PUT /api/users/:username` - Update user
- `DELETE /api/users/:username` - Delete user

**Authentication API:**
- `POST /api/auth/login` - Login
- `POST /api/auth/logout` - Logout

#### 3.2.6 Database Schema

**Users Table:**
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    role TEXT DEFAULT 'user',
    is_active BOOLEAN DEFAULT 1
);
```

**Resource Allocations Table:**
```sql
CREATE TABLE resource_allocations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    cpu_limit REAL NOT NULL DEFAULT 1,
    mem_limit TEXT NOT NULL DEFAULT '2G',
    disk_quota TEXT NOT NULL DEFAULT '5G',
    gpu_access BOOLEAN DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

#### 3.2.7 Dependencies

- PAM authentication
- SQLite (or PostgreSQL)
- Python 3.8+

### 3.3 JupyterHub Module

#### 3.3.1 Responsibilities
- JupyterHub installation and configuration
- Jupyter notebook environments
- Python packages management
- JupyterHub extensions

#### 3.3.2 Components

```
┌───────────────────────────────────────────────────────┐
│                  JupyterHub Module                    │
│                                                       │
│   ┌─────────────┐  ┌─────────────┐  ┌───────────────┐ │
│   │ JupyterHub  │  │  Notebook   │  │   Extension   │ │
│   │   Server    │  │ Environments│  │   Manager     │ │
│   └─────────────┘  └─────────────┘  └───────────────┘ │
│                                                       │
└───────────────────────────────────────────────────────┘
```

#### 3.3.3 Key Files

| File | Purpose |
|------|---------|
| `/opt/jupyterhub/jupyterhub_config.py` | JupyterHub configuration |
| `/etc/systemd/system/jupyterhub.service` | JupyterHub service definition |
| `/opt/jupyterhub/notebooks-template/` | Template notebooks for new users |
| `/opt/diycloud/jupyterhub/setup_jupyterhub.sh` | JupyterHub installation script |
| `/opt/diycloud/jupyterhub/extensions.sh` | JupyterHub extensions installation |

#### 3.3.4 Key Functions

**`install_jupyterhub()`**
- Installs JupyterHub and dependencies
- Configures JupyterHub
- Sets up systemd service

**`configure_jupyter_user(username)`**
- Sets up notebook directory for user
- Configures notebook kernel
- Applies extensions

**`install_extensions()`**
- Installs nbresuse
- Installs jupyter-activity-tracker
- Configures extensions

**`backup_notebooks(username)`**
- Creates backup of user notebooks

#### 3.3.5 JupyterHub Configuration

```python
# Key configuration settings
c.JupyterHub.ip = '0.0.0.0'
c.JupyterHub.port = 8000
c.JupyterHub.hub_ip = '0.0.0.0'

# Authentication - integrates with User Management Module
c.JupyterHub.authenticator_class = 'jupyterhub.auth.PAMAuthenticator'
c.Authenticator.admin_users = {'admin'}
c.LocalAuthenticator.create_system_users = False  # Managed by User Management Module

# Spawner - integrates with Resource Management Module
c.JupyterHub.spawner_class = 'jupyterhub.spawner.LocalProcessSpawner'
c.Spawner.notebook_dir = '~/notebooks'
c.Spawner.default_url = '/lab'  # Use JupyterLab as default

# Resource limits
c.Spawner.cpu_limit = 1.0  # Default, overridden by user settings
c.Spawner.mem_limit = '2G'  # Default, overridden by user settings

# Activity monitoring - integrates with Monitoring Module
c.JupyterHub.log_level = 'INFO'
c.JupyterHub.last_activity_interval = 300
c.NotebookApp.nbserver_extensions = {
    'nbresuse': True,
    'jupyter_activity_tracker': True
}
```

#### 3.3.6 Dependencies

- Python 3.8+
- nodejs/npm
- JupyterHub
- JupyterLab
- nbresuse extension
- jupyter-activity-tracker

### 3.4 Docker/Portainer Module

#### 3.4.1 Responsibilities
- Docker installation and configuration
- Portainer setup
- Container templates
- Container networking
- Container resource limits

#### 3.4.2 Components

```
┌───────────────────────────────────────────────────┐
│              Docker/Portainer Module              │
│                                                   │
│   ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │
│   │   Docker    │  │  Portainer  │  │ Template │  │
│   │   Engine    │  │   Service   │  │ Manager  │  │
│   └─────────────┘  └─────────────┘  └──────────┘  │
│                                                   │
└───────────────────────────────────────────────────┘
```

#### 3.4.3 Key Files

| File | Purpose |
|------|---------|
| `/etc/docker/daemon.json` | Docker configuration |
| `/etc/systemd/system/portainer.service` | Portainer service definition |
| `/opt/diycloud/docker/setup_docker.sh` | Docker installation script |
| `/opt/diycloud/docker/templates/` | Container templates |
| `/opt/diycloud/docker/networks.sh` | Network configuration script |

#### 3.4.4 Key Functions

**`install_docker()`**
- Installs Docker engine
- Configures Docker daemon
- Sets up container logging

**`install_portainer()`**
- Deploys Portainer container
- Configures Portainer settings
- Sets up admin user

**`setup_container_networks()`**
- Creates isolated Docker networks
- Configures network policies

**`setup_templates()`**
- Installs predefined container templates
- Configures template settings

#### 3.4.5 Docker Configuration

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "cgroup-parent": "docker.slice",
  "storage-driver": "overlay2",
  "userland-proxy": false,
  "metrics-addr": "0.0.0.0:9323"
}
```

#### 3.4.6 Dependencies

- Docker CE 20.10+
- Portainer CE
- cgroups v2

### 3.5 Resource Management Module

#### 3.5.1 Responsibilities
- CPU resource allocation
- Memory limits
- Disk quotas
- GPU access (if available)
- Resource monitoring integration
- Cross-distribution resource management compatibility
- Support for both cgroups v1 and v2

#### 3.5.2 Components

```
┌───────────────────────────────────────────────────┐
│             Resource Management Module            │
│                                                   │
│   ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │
│   │   CPU/Mem   │  │    Disk     │  │   GPU    │  │
│   │  Manager    │  │   Manager   │  │  Manager │  │
│   └─────────────┘  └─────────────┘  └──────────┘  │
│                                                   │
└───────────────────────────────────────────────────┘
```

#### 3.5.3 Key Files

| File | Purpose |
|------|---------|
| `/opt/diycloud/resources/cpu_manager.sh` | CPU resource management |
| `/opt/diycloud/resources/mem_manager.sh` | Memory resource management |
| `/opt/diycloud/resources/disk_manager.sh` | Disk quota management |
| `/opt/diycloud/resources/gpu_manager.sh` | GPU access management |
| `/opt/diycloud/resources/apply_limits.sh` | Applies resource limits to user |

#### 3.5.4 Key Functions

**`apply_cpu_limit(username, limit)`**
- Sets CPU shares/limits for user
- Updates cgroups configuration

**`apply_memory_limit(username, limit)`**
- Sets memory limits for user
- Updates cgroups configuration

**`apply_disk_quota(username, quota)`**
- Sets disk quotas for user
- Updates quota database

**`apply_gpu_access(username, enabled)`**
- Configures GPU access for user (if available)
- Sets up NVIDIA Docker integration

**`get_resource_usage(username)`**
- Returns current resource usage for user
- Integrates with Monitoring Module

#### 3.5.5 cgroups Configuration

The system supports both cgroups v1 and v2 based on distribution:

For cgroups v1 (CPU limits):
```bash
# Create user cgroup
mkdir -p /sys/fs/cgroup/cpu/user/$USERNAME
# Set CPU shares (relative weight)
echo $CPU_SHARES > /sys/fs/cgroup/cpu/user/$USERNAME/cpu.shares
# Set CPU quota (absolute limit in microseconds)
echo $CPU_QUOTA > /sys/fs/cgroup/cpu/user/$USERNAME/cpu.cfs_quota_us
# Add user processes to cgroup
echo $USERNAME > /sys/fs/cgroup/cpu/user/$USERNAME/tasks
```

For cgroups v1 (memory limits):
```bash
# Create user cgroup
mkdir -p /sys/fs/cgroup/memory/user/$USERNAME
# Set memory limit
echo $MEM_LIMIT > /sys/fs/cgroup/memory/user/$USERNAME/memory.limit_in_bytes
# Add user processes to cgroup
echo $USERNAME > /sys/fs/cgroup/memory/user/$USERNAME/tasks
```

For cgroups v2 (unified hierarchy):
```bash
# Create user cgroup
mkdir -p /sys/fs/cgroup/user/$USERNAME
# Enable controllers
echo "+cpu +memory" > /sys/fs/cgroup/cgroup.subtree_control
# Set CPU weight (equivalent to shares)
echo $CPU_WEIGHT > /sys/fs/cgroup/user/$USERNAME/cpu.weight
# Set CPU max (quota and period)
echo "$CPU_MAX $CPU_PERIOD" > /sys/fs/cgroup/user/$USERNAME/cpu.max
# Set memory limit
echo $MEM_LIMIT > /sys/fs/cgroup/user/$USERNAME/memory.max
# Add user processes to cgroup
echo $ > /sys/fs/cgroup/user/$USERNAME/cgroup.procs
```

The system uses the Distribution Abstraction Layer to determine which cgroup version is in use and apply the appropriate configuration.

#### 3.5.6 Disk Quota Configuration

```bash
# Enable quota on filesystem
apt install -y quota
quotacheck -ugm /home
quotaon -v /home

# Set user quota (in blocks and inodes)
setquota -u $USERNAME $SOFT_LIMIT $HARD_LIMIT $SOFT_INODES $HARD_INODES /home
```

#### 3.5.7 Dependencies

- cgroups (v1 or v2 depending on distribution)
- quota tools (implementation varies by distribution)
- NVIDIA Docker (for GPU support)
- Distribution Abstraction Layer

### 3.6 Monitoring Module

#### 3.6.1 Responsibilities
- System resource monitoring
- User activity logging
- Alerting
- Dashboard visualization
- Log aggregation

#### 3.6.2 Components

```
┌───────────────────────────────────────────────────┐
│               Monitoring Module                   │
│                                                   │
│   ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │
│   │  Prometheus │  │   Grafana   │  │ Activity │  │
│   │   Server    │  │  Dashboards │  │  Logger  │  │
│   └─────────────┘  └─────────────┘  └──────────┘  │
│                                                   │
└───────────────────────────────────────────────────┘
```

#### 3.6.3 Key Files

| File | Purpose |
|------|---------|
| `/etc/prometheus/prometheus.yml` | Prometheus configuration |
| `/etc/grafana/provisioning/dashboards/` | Grafana dashboards |
| `/opt/diycloud/monitoring/setup_monitoring.sh` | Monitoring setup script |
| `/opt/diycloud/monitoring/activity_logger.py` | User activity logger |
| `/opt/diycloud/monitoring/alert_rules.yml` | Prometheus alert rules |

#### 3.6.4 Key Functions

**`install_prometheus()`**
- Installs Prometheus server
- Configures data sources
- Sets up retention policy

**`install_grafana()`**
- Installs Grafana server
- Configures data sources
- Deploys dashboards

**`setup_activity_logger()`**
- Installs activity logging service
- Configures log rotation
- Sets up log aggregation

**`configure_alerts()`**
- Sets up alerting rules
- Configures notification channels

#### 3.6.5 Prometheus Configuration

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
  
  - job_name: 'jupyterhub'
    static_configs:
      - targets: ['localhost:8000']
  
  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']
  
  - job_name: 'activity_logger'
    static_configs:
      - targets: ['localhost:8001']
```

#### 3.6.6 Activity Logger

```python
#!/usr/bin/env python3
import json
import time
import logging
from datetime import datetime
from prometheus_client import Gauge, start_http_server

# Configure logging
logging.basicConfig(
    filename='/var/log/activity-logger.log',
    level=logging.INFO,
    format='%(asctime)s - %(message)s'
)

# Set up Prometheus metrics
user_activity = Gauge('user_activity', 'User Activity', ['username', 'service'])
resource_usage = Gauge('resource_usage', 'Resource Usage', ['username', 'resource_type'])

def log_jupyterhub_activity():
    """Parse JupyterHub logs and extract activity data"""
    try:
        with open('/var/log/jupyterhub.log', 'r') as f:
            for line in f.readlines():
                if 'notebook started' in line or 'cell executed' in line:
                    # Extract username and log activity
                    username = line.split(' ')[3]
                    logging.info(f"JupyterHub activity: {username}")
                    user_activity.labels(username=username, service='jupyterhub').set(1)
    except Exception as e:
        logging.error(f"Error processing JupyterHub logs: {e}")

def log_docker_activity():
    """Monitor Docker activity"""
    try:
        # Use Docker API to get container events
        # This is a simplified example
        pass
    except Exception as e:
        logging.error(f"Error processing Docker logs: {e}")

def collect_resource_metrics():
    """Collect resource usage metrics"""
    try:
        # Get CPU, memory, disk usage per user
        # This is a simplified example
        pass
    except Exception as e:
        logging.error(f"Error collecting resource metrics: {e}")

if __name__ == "__main__":
    # Start Prometheus metrics server
    start_http_server(8001)
    
    while True:
        log_jupyterhub_activity()
        log_docker_activity()
        collect_resource_metrics()
        time.sleep(60)
```

#### 3.6.7 Dependencies

- Prometheus
- Grafana
- Node Exporter
- Python 3.8+
- prometheus_client Python package

## 4. Integration Points

### 4.1 Module Integration Matrix

| From \ To | Core Platform | User Management | JupyterHub | Docker | Resource Mgmt | Monitoring |
|-----------|---------------|-----------------|------------|--------|---------------|------------|
| **Core Platform** | - | Config | Proxy | Proxy | Config | Proxy |
| **User Management** | User Info | - | Auth | Auth | Resource Limits | User Data |
| **JupyterHub** | Status | User Status | - | - | Resource Usage | Metrics |
| **Docker** | Status | User Status | - | - | Resource Usage | Metrics |
| **Resource Mgmt** | Status | Limit Status | Apply Limits | Apply Limits | - | Usage Data |
| **Monitoring** | Alerts | User Activity | JupyterHub Metrics | Docker Metrics | Resource Metrics | - |

### 4.2 Integration Interfaces

#### 4.2.1 Core Platform to Other Modules
- Nginx reverse proxy configuration
- Web portal API integration

#### 4.2.2 User Management to Other Modules
- Authentication API for JupyterHub and Portainer
- User creation hooks for JupyterHub environment setup
- Resource allocation instructions to Resource Management module

#### 4.2.3 Resource Management to Service Modules
- Apply resource limits to JupyterHub spawners
- Apply resource limits to Docker containers

#### 4.2.4 Monitoring Integration
- Metrics collection from all modules
- Activity logging API

## 5. File and Directory Structure

```
/opt/diycloud/
│
├── install.sh                  # Main installation script
│
├── lib/                        # Distribution Abstraction Layer
│   ├── detect_distro.sh        # Distribution detection
│   ├── package_manager.sh      # Package management functions
│   ├── service_manager.sh      # Service management functions
│   ├── path_resolver.sh        # Path resolution functions
│   └── resource_adapter.sh     # Resource management adaptation
│
├── core/                       # Core Platform Module
│   ├── setup-base.sh           # Base system setup
│   ├── nginx/                  # Nginx configurations
│   └── portal/                 # Web portal files
│
├── usermgmt/                   # User Management Module
│   ├── create_user.sh          # User creation script
│   ├── set_quota.sh            # Set user quotas
│   ├── user_management.py      # Python API for user management
│   └── db/                     # Database files
│
├── jupyterhub/                 # JupyterHub Module
│   ├── setup_jupyterhub.sh     # JupyterHub installation
│   ├── jupyterhub_config.py    # JupyterHub configuration
│   ├── extensions.sh           # Extensions installation
│   └── notebooks-template/     # Template notebooks
│
├── docker/                     # Docker/Portainer Module
│   ├── setup_docker.sh         # Docker installation
│   ├── setup_portainer.sh      # Portainer installation
│   ├── networks.sh             # Network configuration
│   └── templates/              # Container templates
│
├── resources/                  # Resource Management Module
│   ├── cpu_manager.sh          # CPU resource management
│   ├── mem_manager.sh          # Memory resource management
│   ├── disk_manager.sh         # Disk quota management
│   ├── gpu_manager.sh          # GPU access management
│   └── cgroups/                # cgroups configurations for v1 and v2
│
├── monitoring/                 # Monitoring Module
│   ├── setup_monitoring.sh     # Monitoring setup
│   ├── prometheus/             # Prometheus configurations
│   ├── grafana/                # Grafana dashboards
│   └── activity_logger.py      # User activity logger
│
└── docs/                       # Documentation
    ├── README.md               # Project documentation
    ├── RASD.md                 # Requirements and System Design
    ├── DD.md                   # Detailed Design
    └── distro/                 # Distribution-specific documentation
        ├── ubuntu.md           # Ubuntu-specific notes
        ├── debian.md           # Debian-specific notes
        ├── rhel.md             # RHEL/CentOS-specific notes
        ├── fedora.md           # Fedora-specific notes
        ├── arch.md             # Arch Linux-specific notes
        └── opensuse.md         # OpenSUSE-specific notes
```

## 6. Development Workflow

### 6.1 Module Development Sequence

1. **Setup Development Environment**
   - Multiple Linux distribution VMs or containers
     - Ubuntu 20.04+ LTS
     - Debian 11+ (Bullseye)
     - CentOS/RHEL 8+
     - Fedora 35+
     - Arch Linux
     - OpenSUSE Leap 15.3+
   - Git repository for code management
   - Module-specific development tools

2. **Module Development Order**
   - Distribution Abstraction Layer (first priority)
   - Core Platform Module
   - User Management Module
   - Resource Management Module
   - Service Modules (JupyterHub and Docker can be developed in parallel)
   - Monitoring Module

3. **Integration Testing**
   - Test each module independently
   - Test integration points between modules
   - Full system testing

### 6.2 Development Standards

#### 6.2.1 Coding Standards
- Bash: Follow Google Shell Style Guide
- Python: Follow PEP 8
- JavaScript: Follow Airbnb JavaScript Style Guide

#### 6.2.2 Documentation Standards
- Document all functions and scripts
- Include usage examples
- Document configuration options

#### 6.2.3 Testing Standards
- Write unit tests for key functions
- Create integration tests for module interactions
- Document testing procedures

### 6.3 Git Workflow

- Use feature branches for development
- Create pull requests for code review
- Tag releases with semantic versioning

## 7. Deployment

### 7.1 Installation Script

The main `install.sh` script will:
1. Detect Linux distribution and version
2. Check system requirements
3. Set up the Distribution Abstraction Layer
4. Install base dependencies using appropriate package managers
5. Set up each module in sequence with distribution-specific adaptations
6. Configure integration points
7. Start services using the correct service management system
8. Verify installation on the specific distribution

### 7.2 Configuration

- Use YAML configuration files for each module
- Store configurations in `/etc/diycloud/`
- Use environment variables for sensitive information

### 7.3 Backup and Recovery

- Document backup procedures for each module
- Provide scripts for backup automation
- Test recovery procedures

## 8. Security Considerations

### 8.1 Authentication

- Use PAM authentication as default
- Support LDAP/OAuth extensions
- Implement proper session management

### 8.2 Authorization

- Implement role-based access control
- Restrict resource access based on user roles
- Audit access logs

### 8.3 Data Protection

- Use encrypted communications (HTTPS)
- Implement proper file permissions
- Protect sensitive configuration data

### 8.4 Network Security

- Configure firewall rules
- Implement network isolation between containers
- Monitor for suspicious activity

## 9. Extension Points

### 9.1 Authentication Extensions
- LDAP integration
- OAuth provider integration
- Multi-factor authentication

### 9.2 Storage Extensions
- S3-compatible storage integration
- Network file system support
- Backup solutions

### 9.3 Monitoring Extensions
- Email alerting
- Slack/Teams integration
- Advanced analytics

## 10. Conclusion

This Detailed Design document provides comprehensive guidance for implementing the DIY Cloud Platform. The modular approach allows for independent development while ensuring integration into a cohesive system. By following this design, developers can create a robust platform for sharing computational resources in an Ubuntu environment.
