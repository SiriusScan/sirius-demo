# Ellingson Mineral Company - Demo Network Environment

> Realistic corporate network data for SiriusScan demo

## Network Topology

### IT Environment (10.0.0.0/16)

Corporate network with standard enterprise infrastructure:

**Planned Hosts** (to be created):

- `emc-dc01` (10.0.1.10) - Windows Server 2016 Domain Controller
- `emc-dc02` (10.0.1.11) - Windows Server 2019 Domain Controller (backup)
- `emc-fs01` (10.0.2.10) - Windows Server 2012 R2 File Server
- `emc-web01` (10.0.3.10) - Ubuntu 20.04 Web Server (Apache)
- `emc-web02` (10.0.3.11) - Ubuntu 22.04 Web Server (Nginx)
- `emc-db01` (10.0.4.10) - Windows Server 2019 SQL Server
- `emc-ws01` (10.0.10.100) - Windows 10 Workstation
- `emc-ws02` (10.0.10.101) - Windows 10 Workstation

### OT Environment (192.168.50.0/24)

Industrial control systems and SCADA infrastructure:

**Planned Hosts** (to be created):

- `emc-scada01` (192.168.50.10) - Windows Server 2008 R2 SCADA Server
- `emc-hmi01` (192.168.50.20) - Windows 7 HMI Workstation
- `emc-hmi02` (192.168.50.21) - Windows 7 HMI Workstation
- `emc-plc01` (192.168.50.30) - Embedded Linux PLC/RTU

## Vulnerability Profile

### Critical Vulnerabilities

- **CVE-2020-1472** (Zerologon) - Domain Controllers
- **CVE-2017-0144** (EternalBlue) - Unpatched Windows systems
- **CVE-2021-34527** (PrintNightmare) - Print Spooler services

### High Vulnerabilities

- **CVE-2021-42287** - Active Directory Privilege Escalation
- **CVE-2019-0708** (BlueKeep) - RDP services
- Outdated Apache/Nginx versions with known CVEs

### Medium Vulnerabilities

- Missing security patches
- Weak TLS configurations
- Exposed management interfaces

## Fixture File Format

Each host fixture follows this schema:

```json
{
  "hid": "unique-host-id",
  "os": "Operating System",
  "osversion": "OS Version",
  "ip": "IP Address",
  "hostname": "Host Name",
  "ports": [
    {
      "id": 445,
      "protocol": "tcp",
      "state": "open"
    }
  ],
  "vulnerabilities": [
    {
      "vid": "CVE-XXXX-XXXXX",
      "description": "Vulnerability description",
      "title": "Vulnerability title",
      "riskscore": 8.8
    }
  ],
  "cpe": ["cpe:2.3:o:microsoft:windows_server_2016:-:*:*:*:*:*:*:*"],
  "users": ["username1", "username2"],
  "notes": ["Contextual information about the host"]
}
```

## Adding New Hosts

1. **Create fixture file**:

   ```bash
   # For IT hosts
   touch fixtures/it-environment/emc-newhost.json

   # For OT hosts
   touch fixtures/ot-environment/emc-newhost.json
   ```

2. **Populate with data**:

   - Use realistic CVEs from NVD database
   - Include accurate CPE strings
   - Add contextual notes about the host's purpose

3. **Update index.json**:

   ```json
   {
     "file": "it-environment/emc-newhost.json",
     "description": "New Host Description",
     "priority": 2,
     "environment": "it"
   }
   ```

4. **Test locally**:

   ```bash
   # Validate JSON syntax
   jq empty fixtures/it-environment/emc-newhost.json

   # Test POST to local API
   curl -X POST http://localhost:9001/host \
     -H "Content-Type: application/json" \
     -d @fixtures/it-environment/emc-newhost.json
   ```

## CVE Selection Guidelines

- Use **real CVEs** from NIST NVD database
- Select CVEs relevant to the OS/software version
- Include mix of severity levels:
  - Critical: 9.0-10.0 CVSS
  - High: 7.0-8.9 CVSS
  - Medium: 4.0-6.9 CVSS
- Focus on high-impact vulnerabilities that tell a story
- Include both recent and historical CVEs for variety

## Naming Conventions

- **Hostnames**: `emc-<type><number>` (e.g., `emc-dc01`, `emc-web02`)
- **Types**: dc (domain controller), fs (file server), web, db, ws (workstation), scada, hmi, plc
- **IPs**: Follow topology subnets (IT: 10.0.x.x, OT: 192.168.50.x)

## Demo Narrative

The Ellingson Mineral Company network represents a mid-sized enterprise with:

- **Aging infrastructure**: Mix of modern and legacy systems
- **Hybrid environment**: Traditional IT + industrial OT
- **Security debt**: Unpatched systems, missing updates
- **Realistic vulnerabilities**: Known exploits affecting similar organizations

This creates a compelling demo showing:

1. How SiriusScan discovers vulnerable systems
2. Risk prioritization across IT and OT environments
3. Visibility into complex, mixed-technology networks

## Current Status

- ✅ Example host fixture created (data/host-record.json)
- 🚧 IT environment hosts - in progress
- 🚧 OT environment hosts - in progress
- 📝 Total planned hosts: 12-15

## References

- [NIST NVD](https://nvd.nist.gov/) - CVE database
- [CPE Dictionary](https://nvd.nist.gov/products/cpe) - CPE string lookup
- [CVSS Calculator](https://www.first.org/cvss/calculator/3.1) - Risk scoring
