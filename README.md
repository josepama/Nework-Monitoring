# Network Monitoring
Simple web-based realtime IP monitoring using BASH script

## 🔍 Purpose

* This script monitors a list of IP addresses by pinging them, then records their:
  * Online/offline status
  * Latency (ping response time)
  * Last seen online timestamp
  * Uptime percentage (online checks/total checks)
- It saves all this data into JSON files so the monitoring history persists across runs.

## 📂 Files Used
```
ip_data.json      → Contains list of IPs + descriptions.
status.json       → Current run’s results (IP, status, latency, uptime, etc.).
last_online.json  → Last time each IP was online.
uptime.json       → Total checks vs online checks for uptime calculation.
ip_order.json     → Keeps consistent ordering of IPs.
```

**Important**
Since the script `ping_check.sh` reads and writes JSON files, the file permissions need to allow:
* `ping_check.sh` must be executable `(chmod 755)`
* Read `(r)` access so the script can load existing data.
* Write `(w)` access so the script can update/save results.

## Directory tree
```
Network Monitoring/
├── ping_check.sh        # Your main Bash script (chmod 755)
├── ip_data.json         # List of IPs + descriptions (chmod 644)
├── status.json          # Latest run results (chmod 644)
├── last_online.json     # Last time each IP was online (chmod 644)
├── uptime.json          # Total/online checks for uptime % (chmod 644)
└── ip_order.json        # Keeps consistent order of IPs (chmod 644)
```

## Requirements:
- Platform
  - ✅ Major Linux distros such as Debian, Ubuntu, CentOS, Fedora and ArchLinux etc.
- Web Server
  - [apache](https://httpd.apache.org/) or [nginx](https://nginx.org/)
  - [bash](https://www.gnu.org/software/bash/) GNU bash, version 4.2 or higher
- Basic Understanding of cron in Linux

## 🔧 How to Install
- Clone the directory to `/var/www/html/`
- Modify `ip_data.json` add IP Addresses you want to Monitor
  - example:
  ```
  [
    {
      "ip": "8.8.8.8",
      "description": "Google Public DNS"
    },
    {
      "ip": "1.1.1.1",
      "description": "Cloudflare DNS"
    },
    {
      "ip": "9.9.9.9",
      "description": "Quad9 DNS"
    },
    {
      "ip": "208.67.222.222",
      "description": "Open DNS"
    }
  ]
  ```

**Last step is very important**

- you must have root privileges to add cron entry
- add this to your cron jobs `*/1 * * * * cd /var/www/html/Network Monitoring/ && bash ping_check.sh`
  - Every minute, cron will go to `/var/www/html/Network Monitoring/` and run the script `ping_check.sh`

## 🖼 Screenshots

<img src="" width="512" alt="" />