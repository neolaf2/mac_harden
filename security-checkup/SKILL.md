---
name: security-checkup
description: Comprehensive macOS security audit, validation, and remediation with network analysis and LLM-powered threat intelligence. Use when users ask to (1) check system security, (2) audit running processes or network connections, (3) investigate suspicious activity, (4) harden their Mac, (5) analyze unknown processes or IPs, or (6) perform security remediation. Triggers on phrases like "security check", "audit my Mac", "what's connecting to the internet", "is this process safe", "harden my system", or "investigate this IP/domain".
---

# Security Checkup

Integrated security analysis combining local scripts with LLM-powered threat intelligence for comprehensive macOS security management.

## Workflow Decision Tree

```
User Request
    │
    ├─► "Check my security" / "Audit my Mac"
    │       └─► Full Security Audit (Step 1)
    │
    ├─► "What's connecting to the internet?"
    │       └─► Network Analysis (Step 2)
    │
    ├─► "Is this process/IP/domain safe?"
    │       └─► Threat Intelligence Lookup (Step 3)
    │
    ├─► "Harden my system"
    │       └─► Security Hardening (Step 4)
    │
    └─► "Something seems wrong"
            └─► Investigation Mode (Step 5)
```

## Step 1: Full Security Audit

Run comprehensive security checks using the bundled scripts:

```bash
# Full system audit (requires sudo)
sudo mac_harden audit

# Process and resource audit
process_audit

# Check for suspicious launch agents/daemons
cleanup_apps
```

**Output Analysis:** After running audits, summarize:
- Firewall status and configuration gaps
- Exposed services and listening ports
- Suspicious launch agents or daemons
- Security recommendations by priority

## Step 2: Network Analysis

Analyze active network connections and identify potentially suspicious traffic:

```bash
# Quick listening ports check
sudo mac_harden ports

# Outbound connection audit
sudo mac_harden audit-outbound

# Detailed network state
netstat -an | grep ESTABLISHED
lsof -i -n -P | grep ESTABLISHED
```

**For each suspicious connection:**
1. Identify the process: `lsof -i :PORT`
2. Check process details: `ps aux | grep PID`
3. Perform threat lookup (Step 3)

## Step 3: Threat Intelligence Lookup

Use web search to investigate unknown processes, IPs, or domains:

### Process Lookup
```
WebSearch: "process_name" macOS malware OR legitimate OR security
```

### IP/Domain Lookup
```
WebSearch: "IP_ADDRESS" OR "domain.com" malware reputation threat intelligence
```

### Lookup Services (via WebFetch)
- AbuseIPDB: `https://www.abuseipdb.com/check/IP_ADDRESS`
- VirusTotal: `https://www.virustotal.com/gui/domain/DOMAIN`
- Shodan: `https://www.shodan.io/host/IP_ADDRESS`

**Interpretation Guidelines:**
- Cross-reference multiple sources
- Check process signing: `codesign -dv --verbose=4 /path/to/binary`
- Verify against known Apple/vendor processes
- Flag anything with reputation score < 70%

## Step 4: Security Hardening

Apply tiered hardening based on user needs:

```bash
# Level 1: Minimal (close obvious holes)
sudo mac_harden harden minimal

# Level 2: Developer (recommended for dev machines)
sudo mac_harden harden dev

# Level 3: Secure (for sensitive data)
sudo mac_harden harden secure

# Level 4: Paranoid (maximum lockdown)
sudo mac_harden harden paranoid
```

**Hardening Level Selection:**
| Scenario | Recommended Level |
|----------|------------------|
| General use, need AirDrop/printers | minimal |
| Developer workstation | dev |
| Contains sensitive/financial data | secure |
| High-value target or internet-exposed | paranoid |

**Always run audit before and after:**
```bash
sudo mac_harden full [level]
```

## Step 5: Investigation Mode

For suspected compromise or anomalies:

### 1. Capture Current State
```bash
# Snapshot running processes
ps aux > ~/investigation_$(date +%Y%m%d_%H%M%S)_ps.txt

# Snapshot network connections
netstat -an > ~/investigation_$(date +%Y%m%d_%H%M%S)_netstat.txt
lsof -i -n -P > ~/investigation_$(date +%Y%m%d_%H%M%S)_lsof.txt

# List all launch agents/daemons
ls -la ~/Library/LaunchAgents/ /Library/LaunchAgents/ /Library/LaunchDaemons/ > ~/investigation_$(date +%Y%m%d_%H%M%S)_launch.txt
```

### 2. Identify Anomalies
- Processes running from /tmp or hidden directories
- Unsigned or ad-hoc signed binaries
- Launch agents with suspicious paths
- Connections to unusual geographic regions
- High CPU/memory with no visible application

### 3. Remediate
```bash
# Kill suspicious process
kill -9 PID

# Remove launch agent (user)
launchctl unload ~/Library/LaunchAgents/suspicious.plist
rm ~/Library/LaunchAgents/suspicious.plist

# Remove launch daemon (system)
sudo launchctl bootout system/com.suspicious.daemon
sudo rm /Library/LaunchDaemons/com.suspicious.daemon.plist

# Quarantine suspicious binary
sudo mv /path/to/suspicious /var/quarantine/
```

### 4. Verify and Monitor
```bash
# Re-run security audit
sudo mac_harden audit

# Monitor for recurrence
sudo fs_usage -f network
```

## Natural Language Commands

For quick actions, use `askcmd`:

```bash
# Generate security commands from natural language
askcmd "find all files modified in the last hour"
askcmd "list all processes connecting to the internet"
askcmd "find all plist files in LaunchAgents"
askcmd "show all listening ports on my Mac"
```

## AI-Assisted Analysis

For detailed analysis of command output:

```bash
# Pipe any output to Claude for analysis
lsof -i | cat_claude "identify any suspicious network connections"
ps aux | cat_claude "find processes that look unusual or potentially malicious"
sudo lsof -i :443 | cat_claude "analyze these HTTPS connections"
```

## Scripts Reference

| Script | Purpose | Requires Sudo |
|--------|---------|---------------|
| `mac_harden` | Security audit and hardening | Yes |
| `process_audit` | Process/memory/CPU analysis | No |
| `cleanup_apps` | Interactive daemon cleanup | Yes |
| `cat_claude` | AI analysis of command output | No |
| `askcmd` | Natural language to command | No |

## Common Investigation Patterns

### Unknown Process
1. `ps aux | grep PROCESS_NAME` - Get details
2. `lsof -p PID` - See what files/ports it uses
3. `codesign -dv /path/to/binary` - Check signing
4. WebSearch the process name + "malware OR legitimate"
5. Decide: kill, quarantine, or whitelist

### Suspicious Connection
1. `lsof -i :PORT` - Identify process
2. `whois IP_ADDRESS` - Get ownership info
3. WebSearch IP on threat intelligence sites
4. If malicious: kill process, block IP, investigate persistence

### High Resource Usage
1. `process_audit` - Get overview
2. Identify top consumers
3. Check if legitimate (browser, IDE, Docker, etc.)
4. Investigate unknown heavy processes

## Logs and History

All analysis logs are stored in `~/.mac_harden/stm/`:

```
~/.mac_harden/stm/
├── cat_claude/     # AI analysis history
│   └── YYYY-MM/
└── askcmd/         # Command generation history
    └── YYYY-MM/
```

Review with:
```bash
cat_claude --history
askcmd --history
```

## References

For detailed lookup tables and commands:

- **[Threat Intelligence](references/threat_intelligence.md)** - IP/domain reputation services, known good processes, suspicious indicators, investigation commands
- **[Network Analysis](references/network_analysis.md)** - macOS network commands, port reference, traffic monitoring, firewall management
