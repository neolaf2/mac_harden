# Threat Intelligence Reference

## Online Lookup Services

### IP Reputation

| Service | URL Pattern | Notes |
|---------|-------------|-------|
| AbuseIPDB | `https://www.abuseipdb.com/check/IP` | Community-reported abuse |
| VirusTotal | `https://www.virustotal.com/gui/ip-address/IP` | Multi-engine scan |
| Shodan | `https://www.shodan.io/host/IP` | Open ports, banners |
| IPVoid | `https://www.ipvoid.com/ip-blacklist-check/` | Blacklist aggregator |
| GreyNoise | `https://viz.greynoise.io/ip/IP` | Internet noise classification |

### Domain Reputation

| Service | URL Pattern | Notes |
|---------|-------------|-------|
| VirusTotal | `https://www.virustotal.com/gui/domain/DOMAIN` | Multi-engine scan |
| URLVoid | `https://www.urlvoid.com/scan/DOMAIN` | Blacklist check |
| URLScan | `https://urlscan.io/search/#domain:DOMAIN` | Live scan results |
| ThreatCrowd | `https://www.threatcrowd.org/domain.php?domain=DOMAIN` | Threat intel |

### File/Hash Lookup

| Service | URL Pattern | Notes |
|---------|-------------|-------|
| VirusTotal | `https://www.virustotal.com/gui/file/HASH` | Multi-engine scan |
| Hybrid Analysis | `https://www.hybrid-analysis.com/search?query=HASH` | Sandbox results |
| MalwareBazaar | `https://bazaar.abuse.ch/browse/` | Malware samples |

## Known Good Processes (macOS)

### Apple System Processes
- `kernel_task` - Kernel
- `launchd` - System launcher (PID 1)
- `WindowServer` - Display server
- `loginwindow` - Login UI
- `SystemUIServer` - Menu bar
- `Finder` - File manager
- `Dock` - Application dock
- `mds`, `mds_stores` - Spotlight indexing
- `mdworker` - Spotlight worker
- `coreaudiod` - Audio daemon
- `bluetoothd` - Bluetooth daemon
- `airportd` - WiFi daemon
- `configd` - Network configuration
- `diskarbitrationd` - Disk mounting
- `fseventsd` - File system events
- `notifyd` - Notification daemon
- `powerd` - Power management
- `securityd` - Security daemon
- `trustd` - Certificate trust
- `sandboxd` - App sandboxing
- `syspolicyd` - Gatekeeper

### Common Developer Tools
- `node`, `npm` - Node.js
- `python`, `python3` - Python
- `ruby` - Ruby
- `java` - Java
- `docker`, `com.docker.*` - Docker
- `code`, `Code Helper` - VS Code
- `mongod` - MongoDB
- `postgres` - PostgreSQL
- `redis-server` - Redis
- `ollama` - Ollama LLM

### Common Applications
- `Slack`, `Slack Helper` - Slack
- `zoom.us` - Zoom
- `Spotify`, `Spotify Helper` - Spotify
- `Google Chrome`, `Google Chrome Helper` - Chrome
- `Firefox` - Firefox
- `1Password` - 1Password

## Suspicious Indicators

### Process Red Flags
- Running from `/tmp`, `/var/tmp`, or hidden directories
- Names mimicking system processes (e.g., `kerne1_task`)
- Unsigned or ad-hoc signed binaries
- High CPU/network with no visible application
- Connecting to unusual ports (IRC: 6667, Tor: 9050)
- Base64 or obfuscated command line arguments

### Network Red Flags
- Connections to known malicious IPs/domains
- Beaconing patterns (regular interval connections)
- DNS tunneling (high volume of TXT/NULL queries)
- Connections to dynamic DNS services
- Unusual geographic destinations
- Non-standard ports for common protocols

### File System Red Flags
- Launch agents/daemons with obfuscated names
- Binaries in user-writable system paths
- Recently modified system files
- Hidden files in home directory
- Suspicious cron jobs

## Quick Investigation Commands

```bash
# Check code signing
codesign -dv --verbose=4 /path/to/binary

# Get binary info
file /path/to/binary
otool -L /path/to/binary  # List linked libraries

# Check file hash
shasum -a 256 /path/to/file

# Whois lookup
whois IP_ADDRESS

# DNS lookup
dig +short DOMAIN
nslookup DOMAIN

# Reverse DNS
dig -x IP_ADDRESS +short

# GeoIP lookup (requires geoiplookup)
geoiplookup IP_ADDRESS
```

## Response Actions

### Immediate Containment
1. Kill suspicious process: `kill -9 PID`
2. Block IP (if pf enabled): `echo "block drop quick on en0 from IP" | sudo pfctl -f -`
3. Quarantine binary: `sudo mv /path/to/binary /var/quarantine/`
4. Disable launch agent: `launchctl unload /path/to/plist`

### Evidence Preservation
1. Screenshot active connections
2. Export process list: `ps aux > evidence_ps.txt`
3. Export network state: `netstat -an > evidence_netstat.txt`
4. Copy suspicious files (don't execute)
5. Note timestamps and observations

### Recovery
1. Remove persistence mechanisms
2. Delete malicious files
3. Reset compromised credentials
4. Re-run security audit
5. Monitor for recurrence
