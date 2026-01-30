# Network Analysis Reference

## macOS Network Commands

### View Active Connections

```bash
# All connections with process info
lsof -i -n -P

# Established connections only
lsof -i -n -P | grep ESTABLISHED

# Listening ports only
lsof -i -n -P | grep LISTEN

# Connections by specific process
lsof -i -n -P | grep "process_name"

# Connections by PID
lsof -p PID -i -n -P
```

### netstat Commands

```bash
# All connections
netstat -an

# TCP connections
netstat -an -p tcp

# UDP connections
netstat -an -p udp

# Listening ports
netstat -an | grep LISTEN

# Connection statistics
netstat -s
```

### Port-Specific Investigation

```bash
# Find process on port
lsof -i :PORT

# Example: who's using port 443
lsof -i :443

# Range of ports
lsof -i :1000-2000
```

## Common Port Reference

### Standard Ports
| Port | Service | Notes |
|------|---------|-------|
| 22 | SSH | Remote login |
| 53 | DNS | Name resolution |
| 80 | HTTP | Web traffic |
| 443 | HTTPS | Encrypted web |
| 993 | IMAPS | Secure email |
| 995 | POP3S | Secure email |
| 3389 | RDP | Remote desktop |

### Development Ports
| Port | Service | Notes |
|------|---------|-------|
| 3000 | Node.js dev | React, Express |
| 5000 | Flask dev | Python |
| 5432 | PostgreSQL | Database |
| 6379 | Redis | Cache |
| 8080 | HTTP alt | Dev servers |
| 27017 | MongoDB | Database |

### Suspicious Ports
| Port | Service | Concern |
|------|---------|---------|
| 4444 | Metasploit | Common C2 |
| 6667 | IRC | Botnet C2 |
| 9050 | Tor SOCKS | Anonymization |
| 31337 | Elite | Backdoor |

## DNS Analysis

```bash
# DNS lookup
dig DOMAIN

# Short answer
dig +short DOMAIN

# All records
dig DOMAIN ANY

# Trace resolution
dig +trace DOMAIN

# Reverse lookup
dig -x IP_ADDRESS

# Check specific record types
dig DOMAIN MX
dig DOMAIN TXT
dig DOMAIN NS
```

## Traffic Monitoring

### tcpdump (requires sudo)

```bash
# Capture all traffic on interface
sudo tcpdump -i en0

# Capture to file
sudo tcpdump -i en0 -w capture.pcap

# Filter by host
sudo tcpdump -i en0 host IP_ADDRESS

# Filter by port
sudo tcpdump -i en0 port 443

# DNS traffic only
sudo tcpdump -i en0 port 53

# Show packet contents
sudo tcpdump -i en0 -X
```

### Packet Filtering (pf)

```bash
# Check pf status
sudo pfctl -s info

# View current rules
sudo pfctl -s rules

# Block IP temporarily
echo "block drop quick from IP_ADDRESS" | sudo pfctl -f -

# Enable pf
sudo pfctl -e

# Disable pf
sudo pfctl -d
```

## Connection States

| State | Meaning |
|-------|---------|
| ESTABLISHED | Active connection |
| LISTEN | Waiting for connection |
| TIME_WAIT | Closing, waiting for packets |
| CLOSE_WAIT | Remote closed, local pending |
| SYN_SENT | Connection initiating |
| SYN_RECV | Connection responding |
| FIN_WAIT | Closing initiated |

## Real-Time Monitoring

```bash
# Watch network activity (file system level)
sudo fs_usage -f network

# Continuous netstat updates
watch -n 1 'netstat -an | grep ESTABLISHED'

# Monitor specific process
sudo dtrace -n 'syscall::connect:entry /execname == "process_name"/ { trace(arg0); }'
```

## Network Interface Info

```bash
# List interfaces
ifconfig -a

# WiFi info
/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I

# Routing table
netstat -rn

# ARP cache
arp -a

# DNS servers
scutil --dns
```

## Firewall Management

```bash
# Application Firewall status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Enable stealth mode
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on

# Block all incoming
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on

# List allowed apps
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --listapps
```

## Investigation Workflow

### 1. Capture Baseline
```bash
netstat -an > baseline_netstat.txt
lsof -i -n -P > baseline_lsof.txt
```

### 2. Identify Anomalies
```bash
# Compare current to baseline
diff baseline_netstat.txt <(netstat -an)

# Find new connections
comm -13 <(sort baseline_lsof.txt) <(lsof -i -n -P | sort)
```

### 3. Investigate Suspicious Connection
```bash
# Get process info
lsof -i :SUSPICIOUS_PORT

# Get full process details
ps aux | grep PID

# Check binary location
lsof -p PID | grep txt

# Verify code signature
codesign -dv /path/to/binary
```

### 4. Take Action
```bash
# Kill connection
kill -9 PID

# Block at firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/app --blockapp
```
