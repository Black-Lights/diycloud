# DIY Cloud Platform

A self-hosted resource sharing platform that allows you to turn any Linux server into a multi-user cloud environment. Share your CPU, RAM, GPU, and disk resources with others through JupyterHub notebooks and Docker containers. Compatible with multiple Linux distributions including Ubuntu, Debian, CentOS/RHEL, Fedora, Arch Linux, and OpenSUSE.

![DIY Cloud Platform](docs/images/diycloud-banner.png)

## 🌟 Features

- **Unified Web Portal**: Simple landing page for all services
- **JupyterHub Integration**: Python notebooks for data science/ML work
- **Docker with Portainer**: Container management for applications
- **Resource Management**: Control CPU, RAM, disk, and GPU allocation
- **User Activity Tracking**: Monitor resource usage with privacy in mind
- **Comprehensive Monitoring**: Prometheus and Grafana dashboards

## 🚀 Quick Start

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

The installation script will guide you through the setup process and create an admin user.

### Accessing the Platform

After installation, access the web portal at:
```
https://your-server-ip/
```

Default admin credentials:
- Username: admin
- Password: (set during installation)

## 🏗️ Architecture

DIY Cloud Platform follows a modular architecture with distribution abstraction:

```
┌─────────────────────────────────────────────────────────┐
│                   Web Portal (Nginx)                    │
└───────────────────────┬───────────────────────────────┘
                        │
┌───────────────────────▼───────────────────────────────┐
│            Distribution Abstraction Layer              │
│     (Package Management, Service Management, Paths)    │
└───────────────────────┬───────────────────────────────┘
                        │
┌───────────────────────┼───────────────────────────────┐
│                       │                               │
▼                       ▼                               ▼
┌─────────────┐   ┌───────────────┐              ┌──────────────┐
│ JupyterHub  │   │Docker/Portainer│              │  Monitoring  │
│  Module     │   │    Module     │              │   Module     │
└──────┬──────┘   └───────┬───────┘              └───────┬──────┘
       │                  │                              │
       └──────────┬───────┘                              │
                  │                                      │
                  ▼                                      ▼
         ┌────────────────┐                    ┌─────────────────┐
         │    Resource    │                    │  Activity       │
         │   Management   │◄──────────────────►│  Tracking       │
         └────────────────┘                    └─────────────────┘
```

## 📚 Documentation

Comprehensive documentation is available in the [docs](docs/) directory:

- [Requirements Analysis and System Design](docs/RASD.md)
- [Detailed Design](docs/DD.md)
- [Implementation Roadmap](docs/Roadmap.md)
- [User Guide](docs/UserGuide.md)
- [Administrator Guide](docs/AdminGuide.md)

## 🧩 Modules

The platform consists of seven independent modules:

1. **Distribution Abstraction Layer**: Cross-distribution compatibility, package management, service management, path resolution
2. **Core Platform Module**: Base system, web portal, Nginx
3. **User Management Module**: User creation, authentication, roles
4. **JupyterHub Module**: Notebook environments, Python packages
5. **Docker/Portainer Module**: Container management, templates
6. **Resource Management Module**: Resource allocation and limits (cgroups v1/v2 support)
7. **Monitoring Module**: System monitoring, user activity tracking

Each module can be developed and tested independently across different Linux distributions.

## 👨‍💻 Development

### Requirements
- Multiple Linux distributions for testing:
  - Ubuntu 20.04+ LTS
  - Debian 11+ (Bullseye)
  - CentOS/RHEL 8+
  - Fedora 35+
  - Arch Linux (recommended for testing cgroups v2)
  - OpenSUSE Leap 15.3+
- Git
- Python 3.8+
- Docker
- Virtualization software for multi-distro testing (e.g., VirtualBox, KVM)

### Setup Development Environment
```bash
# Clone the repository
git clone https://github.com/your-username/diy-cloud-platform.git
cd diy-cloud-platform

# Set up development environment
./setup-dev.sh
```

### Project Structure
```
diy-cloud-platform/
├── install.sh                  # Main installation script
├── lib/                        # Distribution Abstraction Layer
├── core/                       # Core Platform Module
├── usermgmt/                   # User Management Module
├── jupyterhub/                 # JupyterHub Module
├── docker/                     # Docker/Portainer Module
├── resources/                  # Resource Management Module
├── monitoring/                 # Monitoring Module
└── docs/                       # Documentation
    └── distro/                 # Distribution-specific documentation
```

## 🔒 Security Considerations

- All services are protected by authentication
- Resource limits prevent users from consuming all resources
- User isolation ensures data privacy
- Regular security updates are recommended
- Distribution-specific security enhancements are applied
- Compatible with both cgroups v1 and v2 security models

## 🤝 Contributing

Contributions are welcome! Please check the [Contributing Guidelines](CONTRIBUTING.md) for more information.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgements

- [JupyterHub](https://jupyter.org/hub) project
- [Docker](https://www.docker.com/) project
- [Portainer](https://www.portainer.io/) project
- [Prometheus](https://prometheus.io/) project
- [Grafana](https://grafana.com/) project

## 📞 Support

For issues and feature requests, please use the [GitHub Issues](https://github.com/your-username/diy-cloud-platform/issues) page.

## 🚀 Roadmap

See our [Implementation Roadmap](docs/Roadmap.md) for planned features and enhancements.
