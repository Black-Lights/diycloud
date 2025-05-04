# DIY Cloud Platform: Requirements Analysis and System Design (RASD)

## 1. Introduction

### 1.1 Purpose
This document outlines the requirements and system design for a DIY Cloud Platform that enables resource sharing (CPU, RAM, GPU, disk) across multiple Linux distributions. The platform combines JupyterHub for data science/ML workflows and Docker with Portainer for containerized applications, along with comprehensive monitoring capabilities. The system is designed to be distribution-agnostic, supporting Ubuntu, Debian, CentOS/RHEL, Fedora, Arch Linux, and OpenSUSE.

### 1.2 Scope
The DIY Cloud Platform will provide:
- A unified web portal for accessing resources
- JupyterHub for notebook-based computing
- Docker with Portainer for container management
- Resource allocation and monitoring
- User activity tracking with privacy considerations
- System administration tools

### 1.3 Definitions and Acronyms
- **JupyterHub**: Multi-user server for Jupyter notebooks
- **Portainer**: Web-based Docker management UI
- **RASD**: Requirements Analysis and System Design
- **DD**: Detailed Design
- **VM**: Virtual Machine
- **API**: Application Programming Interface
- **UI**: User Interface

## 2. System Overview

### 2.1 System Context
The DIY Cloud Platform operates on a single Linux server across multiple distributions to provide cloud-like services to multiple users. It serves as a private alternative to AWS, GCP, or Azure for individuals or small organizations with limited resources. The system includes built-in distribution detection and adaptation mechanisms to ensure consistent functionality regardless of the underlying Linux distribution.

```
                 ┌───────────────────────────┐
                 │                           │
                 │     External Users        │
                 │                           │
                 └───────────┬───────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                     Ubuntu Server                       │
│                                                         │
│   ┌─────────────┐      ┌───────────┐    ┌──────────┐   │
│   │ JupyterHub  │      │  Docker/  │    │Monitoring│   │
│   │  Notebooks  │      │ Portainer │    │  System  │   │
│   └─────────────┘      └───────────┘    └──────────┘   │
│                                                         │
│   ┌─────────────────────────────────────────────────┐   │
│   │             Resource Management                  │   │
│   │     (CPU, RAM, Disk, GPU Allocation)            │   │
│   └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 2.2 System Functions
The system will:
1. Provide isolated computational environments for users
2. Allow resource allocation and monitoring
3. Support both notebook-based workflows and containerized applications
4. Track user activity with appropriate privacy controls
5. Enable administrative management of users and resources

### 2.3 User Classes and Characteristics
1. **Administrator**: Manages the system, creates user accounts, allocates resources
2. **Data Scientists/ML Engineers**: Use JupyterHub for notebook-based workflows
3. **Application Developers**: Deploy containerized applications via Docker/Portainer
4. **General Users**: Access computational resources for various purposes

## 3. Functional Requirements

### 3.1 User Management

#### FR1.1: User Registration and Authentication
- System shall allow administrators to create user accounts
- System shall support PAM authentication (local users)
- System shall support extending authentication with LDAP/OAuth (optional)

#### FR1.2: Resource Allocation
- System shall allow administrators to set resource limits per user:
  - CPU cores/shares
  - Memory limits
  - Disk quota
  - GPU access (if available)

#### FR1.3: User Portal
- System shall provide a unified web portal
- Portal shall direct users to JupyterHub or Portainer
- Portal shall display resource usage information

### 3.2 JupyterHub Functionality

#### FR2.1: Notebook Environment
- System shall provide Jupyter notebook environments
- System shall support Python data science libraries
- System shall enforce resource limits on notebooks

#### FR2.2: Notebook Activity Tracking
- System shall log basic notebook activity (execution, not content)
- System shall track resource usage via nbresuse
- System shall respect user privacy by not logging cell contents

### 3.3 Docker/Portainer Functionality

#### FR3.1: Container Management
- System shall provide Docker container management
- System shall allow users to create/start/stop containers
- System shall enforce resource limits on containers

#### FR3.2: Container Templates
- System shall provide pre-configured container templates
- Templates shall be accessible via Portainer

#### FR3.3: Container Networking
- System shall provide isolated networks for containers
- System shall allow controlled external access to containers

### 3.4 Monitoring and Logging

#### FR4.1: Resource Monitoring
- System shall track CPU, memory, disk, and network usage
- System shall provide real-time and historical usage data
- System shall alert on resource exhaustion

#### FR4.2: Activity Logging
- System shall log user login/logout events
- System shall log JupyterHub activity (notebook execution)
- System shall log Docker activity (container events)

#### FR4.3: Dashboards
- System shall provide monitoring dashboards
- Dashboards shall display system and per-user metrics

## 4. Non-Functional Requirements

### 4.1 Performance

#### NFR1.1: Resource Efficiency
- System shall minimize overhead on host resources
- System shall support at least 10 concurrent users on modest hardware (4 cores, 16GB RAM)
- System shall optimize resource usage across different Linux distributions

#### NFR1.2: Responsiveness
- Web portal shall load in under 3 seconds
- JupyterHub shall start notebooks in under 15 seconds
- Portainer shall respond to actions in under 5 seconds
- System performance shall be consistent across supported distributions

### 4.2 Security

#### NFR2.1: Isolation
- System shall ensure user isolation
- System shall prevent cross-user resource access
- System shall implement network isolation between containers

#### NFR2.2: Authentication Security
- System shall enforce strong password policies
- System shall use encrypted communications (HTTPS)
- System shall implement session timeout

### 4.3 Usability

#### NFR3.1: Ease of Use
- Portal shall be intuitive for technical users
- System shall provide clear documentation
- System shall provide helpful error messages

#### NFR3.2: Accessibility
- Portal shall be accessible from modern web browsers
- Portal shall be responsive for different screen sizes

### 4.4 Maintainability

#### NFR4.1: Modularity
- System shall be built with modular components
- Components shall be independently upgradeable

#### NFR4.2: Documentation
- System shall be thoroughly documented
- Documentation shall include installation, configuration, and usage guides

## 5. System Architecture

### 5.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                Web Portal                                   │
│                             (Nginx/Frontend)                                │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
                 ┌─────────────────┬┴────────────────┐
                 │                 │                 │
    ┌────────────▼─────────┐   ┌───▼────────────┐  ┌─▼────────────────┐
    │     JupyterHub       │   │Docker/Portainer│  │  Monitoring      │
    │   Module             │   │  Module        │  │  Module          │
    └────────────┬─────────┘   └───┬────────────┘  └──┬───────────────┘
                 │                 │                   │
                 │                 │                   │
    ┌────────────▼─────────┐   ┌───▼────────────┐  ┌──▼───────────────┐
    │  Jupyter Notebook    │   │    Docker      │  │   Prometheus     │
    │  Environments        │   │   Containers   │  │   + Grafana      │
    └────────────┬─────────┘   └───┬────────────┘  └──────────────────┘
                 │                 │
                 └────────┬────────┘
                          │
              ┌───────────▼──────────┐
              │  Resource Management │
              │        Module        │
              └──────────────────────┘
```

### 5.2 Deployment Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Ubuntu Server                               │
│                                                                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │
│  │  Nginx  │  │JupyterHb│  │ Docker  │  │Portainer│  │Promethus│   │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘   │
│                                                                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │
│  │ Grafana │  │ Node    │  │ Python  │  │ nbresuse│  │Activity │   │
│  │         │  │ Exporter│  │ Libs    │  │         │  │ Logger  │   │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘  └─────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.3 Data Model

```
┌───────────────┐      ┌────────────────┐      ┌────────────────┐
│    User       │      │  Resource      │      │   Activity     │
│               │      │  Allocation    │      │   Log          │
│ - username    │      │                │      │                │
│ - role        │◄────►│ - user_id      │      │ - timestamp    │
│ - created_at  │      │ - cpu_limit    │      │ - user_id      │
│ - last_login  │      │ - mem_limit    │◄────►│ - action       │
│               │      │ - disk_quota   │      │ - resource     │
└───────────────┘      │ - gpu_access   │      │ - details      │
                       └────────────────┘      └────────────────┘
```

## 6. External Interfaces

### 6.1 User Interfaces
- Web Portal: Main entry point for users
- JupyterHub Interface: For notebook access
- Portainer Interface: For container management
- Grafana Dashboards: For monitoring visualization

### 6.2 Hardware Interfaces
- CPU: Minimum 2 cores, recommended 4+
- RAM: Minimum 8GB, recommended 16GB+
- Disk: Minimum 50GB, recommended 100GB+
- Network: Ethernet, minimum 100Mbps
- GPU: Optional, NVIDIA with CUDA support

### 6.3 Software Interfaces
- Operating System: Multiple Linux distributions supported
  - Ubuntu 20.04+ LTS
  - Debian 11+ (Bullseye)
  - CentOS/RHEL 8+
  - Fedora 35+
  - Arch Linux (Rolling)
  - OpenSUSE Leap 15.3+
- Web Server: Nginx
- Database: SQLite (default) or PostgreSQL (optional)
- Monitoring: Prometheus, Grafana

## 7. System Modules

### 7.1 Distribution Abstraction Layer
Provides cross-distribution compatibility by abstracting distribution-specific operations.

### 7.2 Core Platform Module
Responsible for base system setup, web portal, and integration.

### 7.3 JupyterHub Module
Handles Jupyter notebook environments and related functionality.

### 7.4 Docker/Portainer Module
Manages Docker containers and Portainer interface.

### 7.5 Monitoring Module
Implements resource and activity monitoring, alerting, and visualization.

### 7.6 User Management Module
Handles user creation, authentication, and resource allocation.

### 7.7 Resource Management Module
Manages system resources across different distributions with support for both cgroups v1 and v2.

## 8. Development Approach

### 8.1 Modularity
Each component will be developed and tested independently.

### 8.2 Configuration over Code
System will prioritize configuration files over custom code.

### 8.3 Documentation
Each module will include comprehensive documentation.

### 8.4 Testing
Each module will include testing procedures and validation.

## 9. Implementation Priorities

1. Base System Setup and Web Portal
2. User Management Module
3. JupyterHub Module
4. Docker/Portainer Module
5. Resource Management Module
6. Monitoring Module
7. Integration and Testing

## 10. Conclusion

This RASD provides a foundation for developing a DIY Cloud Platform that enables resource sharing on Ubuntu servers. The modular design allows for independent development of components while ensuring integration into a cohesive system.
