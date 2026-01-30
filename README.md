# Mac Hardening & Security Tools

A comprehensive suite of shell scripts for macOS security hardening, process auditing, cleanup, and AI-assisted analysis.

**Authors:** Richard Tong, Claude 4.5, ChatGPT 5.2

## Overview

This toolkit provides:

- **`mac_harden`** - Security audit and tiered hardening for macOS
- **`process_audit`** - Process, CPU, and memory analysis
- **`cleanup_apps`** - Interactive removal of unwanted applications and daemons
- **`cat_claude`** - Pipe command output to Claude for AI analysis

## Quick Start

```bash
# Install all tools
sudo ./install.sh

# Run security audit
sudo mac_harden audit

# Run process audit
process_audit

# Interactive cleanup
sudo cleanup_apps

# AI-assisted analysis
opencode --help | cat_claude
```

---

## mac_harden

A security audit and hardening tool with four tiered hardening levels to match different use cases.

### Usage

```bash
sudo mac_harden [options] [command] [level]
```

### Options

| Option | Description |
|--------|-------------|
| `--log-dir <path>` | Directory for log files (default: current directory) |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

### Commands

| Command | Description |
|---------|-------------|
| `audit` | Full security audit: inbound + outbound connections (no changes) |
| `audit-outbound` | Focus on outbound connections only |
| `harden [level]` | Apply hardening at specified level |
| `full [level]` | Audit → Harden → Verify |
| `ports` | Quick listening ports check (inbound only) |
| `undo` | Show commands to reverse hardening changes |
| `interactive`, `i` | Interactive menu mode |
| `help` | Show help |

### Hardening Levels

| Level | Name | Use Case | What It Does |
|-------|------|----------|--------------|
| 1 | `minimal` | Close obvious holes only | Firewall on (signed apps allowed), disable guest account & auto-login, require password after sleep |
| 2 | `dev` | Developer machine (**recommended**) | Everything in minimal + stealth mode, disable remote Apple events. Preserves SSH, Bonjour, signed apps |
| 3 | `secure` | Laptop with sensitive data | Everything in dev + disable SSH, disable Bonjour advertising. May affect AirDrop, printer discovery |
| 4 | `paranoid` | Internet-exposed / production | Everything in secure + block unsigned apps, disable IPv6, wake-on-LAN. Maximum lockdown |

### Examples

```bash
# Run full security audit
sudo mac_harden audit

# Check outbound connections (what's phoning home)
sudo mac_harden audit-outbound

# Interactive mode
sudo mac_harden i

# Apply developer-friendly hardening
sudo mac_harden harden dev

# Apply maximum security
sudo mac_harden harden paranoid

# Full cycle: audit before, harden, audit after
sudo mac_harden full secure

# Custom log directory
sudo mac_harden --log-dir ~/logs audit

# Show how to undo changes
sudo mac_harden undo
```

### What It Audits

- **Firewall status** - enabled, stealth mode, allowed apps
- **Listening ports** - TCP/UDP services accepting connections
- **Outbound connections** - established connections with reverse DNS
- **Sharing services** - SSH, screen sharing, file sharing, remote events
- **Disk encryption** - FileVault status
- **System integrity** - SIP and Gatekeeper status
- **User settings** - guest account, auto-login, password requirements
- **Network configuration** - interfaces, IPv6, DNS, Bonjour
- **Launch agents/daemons** - third-party items that run at startup
- **Configuration profiles** - MDM or enterprise profiles
- **Browser extensions** - Chrome and Safari extension counts

### Sample Audit Output

```
========================================
FIREWALL STATUS
========================================
✓ Firewall is enabled
✓ Stealth mode is enabled

========================================
SHARING SERVICES
========================================
✓ Remote Login (SSH): Off
✓ Remote Apple Events: Off
✓ Screen Sharing: Not loaded
✓ SMB File Sharing: Not loaded

========================================
SYSTEM INTEGRITY PROTECTION
========================================
✓ SIP is enabled
✓ Gatekeeper is enabled

========================================
LOGIN ITEMS & LAUNCH AGENTS
========================================
--- System Launch Daemons (non-Apple) ---
⚠ Third-party daemon: com.docker.vmnetd.plist
⚠ Third-party daemon: com.expressvpn.expressvpnd.plist
```

---

## process_audit

Analyzes running processes, CPU usage, memory consumption, and provides optimization recommendations.

### Usage

```bash
process_audit [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--log-dir <path>` | Directory for log files (default: current directory) |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

### What It Audits

- **System overview** - uptime, load average, CPU cores, memory pressure
- **Top CPU consumers** - top 15 processes by CPU usage, alerts for >50%
- **Top memory consumers** - top 15 by RAM, flags processes using >1GB
- **Long-running processes** - user processes running >24 hours
- **Suspicious processes** - processes from /tmp, hidden processes, deleted binaries
- **Dev tools status** - MongoDB, PostgreSQL, Neo4j, Redis, Docker, Ollama, LM Studio
- **Optimization suggestions** - browser tabs, Electron apps, idle resources

### Sample Output

```
========================================
SYSTEM OVERVIEW
========================================
Uptime: 17:08  up 30 mins, 2 users, load averages: 1.85 2.63 5.37
Load Average:  1.85 2.63 5.37
CPU Cores: 16
Total Memory: 64.0 GB
Memory Free: 95%
✓ Memory pressure is normal

========================================
TOP MEMORY CONSUMERS
========================================
--- Memory Hogs (>1GB RSS) ---
⚠ rich (PID 991): 2.0 GB - /Applications/MacWhisper.app
⚠ rich (PID 1009): 3.2 GB - /Applications/Docker.app

========================================
DEV TOOLS STATUS
========================================
--- Databases ---
  MongoDB: Running (PID 945, 97MB, 0.1% CPU)
  PostgreSQL: Running (7 processes, 49MB total)
  Neo4j: Running (713MB)
```

---

## cleanup_apps

Interactive tool for auditing and removing unwanted applications, launch agents, and daemons.

### Usage

```bash
sudo cleanup_apps
```

### What It Scans

- **User Launch Agents** - `~/Library/LaunchAgents/*.plist`
- **System Launch Agents** - `/Library/LaunchAgents/*.plist` (non-Apple)
- **System Launch Daemons** - `/Library/LaunchDaemons/*.plist` (non-Apple)
- **Applications** - `/Applications/*.app` (non-Apple)

### Features

- Interactive prompts for each item (y/N/q)
- Automatically skips Apple system items
- Unloads daemons/agents before removal
- Cleans up associated config files for removed apps
- Summary of removed vs skipped items

### Sample Output

```
=== User Launch Agents (~/.Library/LaunchAgents) ===

Found User Agent: com.spotify.webhelper
  Path: /Users/rich/Library/LaunchAgents/com.spotify.webhelper.plist
  Remove this item? (y/N/q to quit): y
✓ Removed com.spotify.webhelper

=== Cleanup Summary ===

  Removed: 3 items
  Skipped: 5 items

✓ Cleanup complete!
```

---

## cat_claude

Pipe any command output to Claude for AI-powered analysis. Outputs markdown to stdout (pipe-friendly) and saves a copy to a file.

### Usage

```bash
# Pipe command output
ANY_COMMAND | cat_claude [output.md] [prompt]

# Or use --cmd flag
cat_claude --cmd "command" [output.md] [prompt]
```

### Options

| Option | Description |
|--------|-------------|
| `--cmd "command"` | Run command and analyze its output |
| `--version, -v` | Show version |
| `--help, -h` | Show help |

### Examples

```bash
# Basic usage - auto-generates filename from command
opencode --help | cat_claude
# → Creates: opencode--help-analysis.md

# Custom output file
ls -la | cat_claude ls_analysis.md

# Custom prompt
git diff | cat_claude review.md "review these changes for bugs"

# Using --cmd flag (most reliable for filename detection)
cat_claude --cmd "docker ps -a"

# Pipe-friendly - append to log file
opencode --help | cat_claude >> my_shell_analysis_log.md
git status | cat_claude >> my_shell_analysis_log.md
```

### Output Format

```markdown
# Command → Claude Analysis

**Command:** `opencode --help`
**Generated:** 2024-01-15 14:30:00

## Prompt
\`\`\`text
Analyze this output and explain what it shows
\`\`\`

## Input
\`\`\`
[original command output]
\`\`\`

## Analysis

[Claude's analysis]

---
```

### Notes

- Full output goes to stdout (pipe-friendly)
- A copy is saved to the `.md` file
- Status messages go to stderr (won't pollute pipes)
- Default filename is generated from the command name

---

## Dev Tools Management

Quick commands to start/stop development tools to save resources.

### Stop All Dev Tools

```bash
osascript -e 'quit app "Docker"'
osascript -e 'quit app "LM Studio"'
pkill -f ollama
brew services stop mongodb-community
brew services stop postgresql@14
brew services stop neo4j
```

### Start All Dev Tools

```bash
open -a Docker
open -a Ollama
open -a "LM Studio"
brew services start mongodb-community
brew services start postgresql@14
brew services start neo4j
```

---

## Common Issues & Solutions

### Third-Party Launch Daemons

The audit may flag third-party launch agents/daemons. Here's how to evaluate them:

| Pattern | What It Is | Action |
|---------|------------|--------|
| `com.google.*` | Google Chrome/Drive updaters | ✅ Safe |
| `com.microsoft.*` | Office/OneDrive updaters | ✅ Safe |
| `com.adobe.ARMDC.*` | Adobe updater | ✅ Safe |
| `com.docker.*` | Docker networking | ✅ Safe if you use Docker |
| `com.logi.*` | Logitech peripherals | ✅ Safe |
| `us.zoom.*` | Zoom client | ✅ Safe |
| Unknown items | Research before removing | ⚠️ Investigate |

### Removing Unwanted Launch Daemons

```bash
# User agent (no sudo needed)
launchctl unload ~/Library/LaunchAgents/com.example.agent.plist
rm ~/Library/LaunchAgents/com.example.agent.plist

# System daemon (requires sudo)
sudo launchctl bootout system/com.example.daemon
sudo rm /Library/LaunchDaemons/com.example.daemon.plist
```

### Undo Hardening Changes

```bash
# Re-enable SSH
sudo systemsetup -setremotelogin on

# Re-enable Bonjour advertising
sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool false

# Re-enable IPv6 on Wi-Fi
sudo networksetup -setv6automatic Wi-Fi

# Allow signed apps again
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on

# Disable stealth mode
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off

# Re-enable guest account
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool true

# Re-enable wake on LAN
sudo pmset -a womp 1
```

---

## Security Recommendations

### Recommended Baseline (Level 2 - Dev)

For most developers, Level 2 provides good security without breaking workflows:

- ✅ Firewall enabled with stealth mode
- ✅ Guest account disabled
- ✅ Auto-login disabled
- ✅ Immediate password on wake
- ✅ Remote Apple Events disabled
- ✅ SSH preserved (for dev work)
- ✅ Bonjour preserved (for AirDrop, printers)

### For Sensitive Machines (Level 3 - Secure)

If your machine contains sensitive data:

```bash
sudo mac_harden harden secure
```

This additionally:
- Disables SSH
- Disables Bonjour multicast advertising

### For Maximum Security (Level 4 - Paranoid)

For internet-exposed or high-security machines:

```bash
sudo mac_harden harden paranoid
```

This additionally:
- Blocks unsigned apps in firewall
- Disables IPv6 on Wi-Fi
- Disables wake-on-LAN
- Disables Bluetooth sharing

---

## Installation

### Option 1: Use the Installer (Recommended)

```bash
# Clone or download the scripts
git clone https://github.com/yourusername/mac-harden.git
cd mac-harden

# Install all tools
sudo ./install.sh

# Verify
mac_harden --version
process_audit --version
cat_claude --version
```

### Option 2: Run from local directory

```bash
chmod +x *.sh
sudo ./mac_harden.sh audit
./process_audit.sh
./cat_claude.sh --help
```

### Why /usr/local/bin?

- Already in your PATH
- Requires sudo to modify (protects against malware)
- Appropriate for system-wide security tools
- Survives macOS updates

---

## File Structure

```
mac-harden/
├── README.md
├── install.sh                 # Installer script
├── mac_harden.sh              # Main security audit & hardening script
├── process_audit.sh           # Process & resource analysis script
├── cleanup_unwanted_apps.sh   # Interactive cleanup script
└── cat_claude.sh              # Pipe output to Claude for AI analysis
```

---

## Requirements

- macOS 12+ (Monterey or later)
- Admin/sudo access for hardening operations
- Homebrew (optional, for dev tools management)
- Claude Code CLI (for `cat_claude` - install via `npm install -g @anthropic-ai/claude-code`)

---

## License

MIT License - Feel free to use, modify, and distribute.

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes on your own machine
4. Submit a pull request

---

## Changelog

### v2.1.0
- Added `cat_claude` - pipe command output to Claude for AI analysis
- Added `cleanup_apps` to installer
- Added `install.sh` for easy installation
- Updated documentation

### v2.0.0
- Added tiered hardening levels (minimal, dev, secure, paranoid)
- Added interactive mode
- Added outbound connection auditing
- Added `--log-dir` option
- Added `undo` command
- Fixed log file path double-slash issue

### v1.0.0
- Initial release
- Basic audit and hardening functionality
