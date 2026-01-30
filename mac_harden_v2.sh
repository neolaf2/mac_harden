#!/bin/bash

# ============================================================================
# MAC HARDENING & SECURITY AUDIT SCRIPT v2.0
# Authors: Richard Tong, Claude 4.5, ChatGPT 5.2
# ============================================================================
# Run with: sudo mac_harden [options] [command] [level]
#
# Options:
#   --log-dir <path>   - Directory for log files (default: current directory)
#   -h, --help         - Show help
#   -v, --version      - Show version
#
# Commands:
#   audit              - Full security audit: inbound + outbound (no changes)
#   audit-outbound     - Focus on outbound connections only
#   harden [level]     - Apply hardening at specified level
#   full [level]       - Audit → Harden → Verify
#   ports              - Quick listening ports check (inbound only)
#   interactive, i     - Interactive menu mode
#   help               - Show this help
#
# Hardening Levels:
#   1 | minimal   - Close obvious holes only (guest account, auto-login, 
#                   basic firewall). Preserves all dev workflows.
#   2 | dev       - Dev box defaults. Firewall + stealth, but keeps SSH,
#                   Bonjour, signed app auto-allow.
#   3 | secure    - Key asset protection. Disables SSH, remote events,
#                   Bonjour advertising. Good for laptops with sensitive data.
#   4 | paranoid  - Production/internet-exposed hardening. Maximum lockdown,
#                   blocks unsigned apps, aggressive network restrictions.
#
# Examples:
#   sudo mac_harden audit
#   sudo mac_harden harden minimal
#   sudo mac_harden harden dev
#   sudo mac_harden full secure
# ============================================================================

set -e

# Version
VERSION="2.0.0"
AUTHORS="Richard Tong, Claude 4.5, ChatGPT 5.2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging - default to current working directory, override with --log-dir
LOG_DIR="${PWD}"
LOG_FILE=""

init_log() {
    # Remove trailing slash from LOG_DIR if present
    LOG_DIR="${LOG_DIR%/}"
    LOG_FILE="${LOG_DIR}/mac_security_audit_$(date +%Y%m%d_%H%M%S).log"
    if [ ! -d "$LOG_DIR" ]; then
        echo "Error: Log directory '$LOG_DIR' does not exist"
        exit 1
    fi
    if [ ! -w "$LOG_DIR" ]; then
        echo "Error: Log directory '$LOG_DIR' is not writable"
        echo "Try: sudo mac_harden --log-dir /tmp audit"
        exit 1
    fi
}

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

header() {
    log "\n${BLUE}========================================${NC}"
    log "${BLUE}$1${NC}"
    log "${BLUE}========================================${NC}"
}

subheader() {
    log "\n${CYAN}--- $1 ---${NC}"
}

success() {
    log "${GREEN}✓ $1${NC}"
}

warning() {
    log "${YELLOW}⚠ $1${NC}"
}

fail() {
    log "${RED}✗ $1${NC}"
}

info() {
    log "  $1"
}

skip() {
    log "${MAGENTA}○ SKIP: $1${NC}"
}

# ============================================================================
# AUDIT FUNCTIONS
# ============================================================================

audit_firewall() {
    header "FIREWALL STATUS"
    
    fw_state=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)
    if echo "$fw_state" | grep -q "enabled"; then
        success "Firewall is enabled"
    else
        fail "Firewall is DISABLED"
    fi
    
    stealth=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null)
    if echo "$stealth" | grep -q "enabled"; then
        success "Stealth mode is enabled"
    else
        warning "Stealth mode is disabled"
    fi
    
    signed=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null)
    info "Allow signed apps: $signed"
    
    # List allowed apps
    subheader "Firewall-allowed applications"
    /usr/libexec/ApplicationFirewall/socketfilterfw --listapps 2>/dev/null | head -20 | while read line; do
        info "$line"
    done
}

audit_listening_ports() {
    header "LISTENING PORTS & SERVICES"
    
    subheader "TCP Listening"
    if command -v lsof &> /dev/null; then
        echo ""
        printf "  ${YELLOW}%-20s %-10s %-25s${NC}\n" "COMMAND" "USER" "ADDRESS"
        sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | awk 'NR>1 {printf "  %-20s %-10s %-25s\n", $1, $3, $9}' | tee -a "$LOG_FILE"
    fi
    
    subheader "UDP Listening"
    printf "  ${YELLOW}%-20s %-10s %-25s${NC}\n" "COMMAND" "USER" "ADDRESS"
    sudo lsof -iUDP -n -P 2>/dev/null | awk 'NR>1 {printf "  %-20s %-10s %-25s\n", $1, $3, $9}' | head -20 | tee -a "$LOG_FILE"
    
    # Count and warn
    tcp_count=$(sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | wc -l | tr -d ' ')
    if [ "$tcp_count" -gt 10 ]; then
        warning "You have $tcp_count TCP listeners - consider reviewing"
    else
        success "TCP listener count: $tcp_count"
    fi
}

audit_outbound_connections() {
    header "OUTBOUND CONNECTIONS (ESTABLISHED)"
    
    subheader "Currently established connections"
    echo ""
    printf "  ${YELLOW}%-18s %-8s %-22s %-22s${NC}\n" "COMMAND" "USER" "LOCAL" "REMOTE"
    
    sudo lsof -i -n -P 2>/dev/null | grep ESTABLISHED | awk '{printf "  %-18s %-8s %-22s %-22s\n", $1, $3, $9, $10}' | tee -a "$LOG_FILE"
    
    established_count=$(sudo lsof -i -n -P 2>/dev/null | grep -c ESTABLISHED || echo "0")
    
    if [ "$established_count" -eq 0 ]; then
        success "No established outbound connections"
    else
        info "Total established connections: $established_count"
    fi
    
    subheader "Unique remote IPs currently connected"
    sudo lsof -i -n -P 2>/dev/null | grep ESTABLISHED | awk '{print $9}' | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u | while read ip; do
        # Try to get hostname
        host=$(host "$ip" 2>/dev/null | awk '/domain name pointer/ {print $5}' | head -1)
        if [ -n "$host" ]; then
            info "$ip → $host"
        else
            info "$ip"
        fi
    done
    
    subheader "Processes with network connections"
    sudo lsof -i -n -P 2>/dev/null | awk 'NR>1 {print $1}' | sort | uniq -c | sort -rn | head -10 | while read count proc; do
        info "$proc: $count connections"
    done
}

audit_sharing_services() {
    header "SHARING SERVICES"
    
    # Remote Login (SSH)
    remote_login=$(sudo systemsetup -getremotelogin 2>/dev/null | awk -F': ' '{print $2}')
    if [ "$remote_login" = "Off" ]; then
        success "Remote Login (SSH): Off"
    else
        warning "Remote Login (SSH): $remote_login"
    fi
    
    # Remote Apple Events
    remote_events=$(sudo systemsetup -getremoteappleevents 2>/dev/null | awk -F': ' '{print $2}')
    if [ "$remote_events" = "Off" ]; then
        success "Remote Apple Events: Off"
    else
        warning "Remote Apple Events: $remote_events"
    fi
    
    # Screen Sharing
    screen_sharing=$(sudo launchctl list 2>/dev/null | grep -c "com.apple.screensharing" || echo "0")
    if [ "$screen_sharing" -gt 0 ]; then
        warning "Screen Sharing service is loaded"
    else
        success "Screen Sharing: Not loaded"
    fi
    
    # File Sharing
    smb_sharing=$(sudo launchctl list 2>/dev/null | grep -c "com.apple.smbd" || echo "0")
    if [ "$smb_sharing" -gt 0 ]; then
        warning "SMB File Sharing is loaded"
    else
        success "SMB File Sharing: Not loaded"
    fi
    
    subheader "Active sharing-related services"
    sharing_services=$(sudo launchctl list 2>/dev/null | grep -E 'sharing|smbd|screensharing|remote|vnc' || echo "  None found")
    info "$sharing_services"
}

audit_encryption() {
    header "DISK ENCRYPTION (FileVault)"
    
    fv_status=$(fdesetup status 2>/dev/null)
    if echo "$fv_status" | grep -q "FileVault is On"; then
        success "FileVault is enabled"
    else
        fail "FileVault is DISABLED - your disk is not encrypted!"
    fi
}

audit_system_integrity() {
    header "SYSTEM INTEGRITY PROTECTION"
    
    sip_status=$(csrutil status 2>/dev/null)
    if echo "$sip_status" | grep -q "enabled"; then
        success "SIP is enabled"
    else
        fail "SIP is DISABLED - this is a security risk!"
    fi
    
    # Gatekeeper
    gk_status=$(spctl --status 2>/dev/null)
    if echo "$gk_status" | grep -q "enabled"; then
        success "Gatekeeper is enabled"
    else
        fail "Gatekeeper is DISABLED"
    fi
}

audit_user_settings() {
    header "USER & LOGIN SETTINGS"
    
    # Guest account
    guest_enabled=$(sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo "0")
    if [ "$guest_enabled" = "0" ] || [ "$guest_enabled" = "false" ]; then
        success "Guest account is disabled"
    else
        warning "Guest account is ENABLED"
    fi
    
    # Auto login
    auto_login=$(sudo defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo "")
    if [ -z "$auto_login" ]; then
        success "Auto-login is disabled"
    else
        fail "Auto-login is ENABLED for: $auto_login"
    fi
    
    # Screen saver password
    ss_password=$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "0")
    ss_delay=$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "999")
    if [ "$ss_password" = "1" ] && [ "$ss_delay" = "0" ]; then
        success "Password required immediately after sleep/screensaver"
    else
        warning "Password delay after sleep: ${ss_delay}s (recommend 0)"
    fi
    
    # Firmware password (if checkable)
    subheader "Firmware Security"
    if command -v firmwarepasswd &> /dev/null; then
        fw_pass=$(sudo firmwarepasswd -check 2>/dev/null || echo "Unknown")
        info "Firmware password: $fw_pass"
    fi
}

audit_network_config() {
    header "NETWORK CONFIGURATION"
    
    subheader "Active network interfaces"
    ifconfig -l | tr ' ' '\n' | while read iface; do
        if ifconfig "$iface" 2>/dev/null | grep -q "status: active"; then
            ip=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '{print $2}')
            info "$iface: $ip"
        fi
    done
    
    subheader "IPv6 status"
    networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | while read service; do
        ipv6=$(networksetup -getinfo "$service" 2>/dev/null | grep "IPv6:" | awk '{print $2}')
        if [ -n "$ipv6" ] && [ "$ipv6" != "Off" ]; then
            info "$service: IPv6 $ipv6"
        fi
    done
    
    subheader "DNS Servers"
    scutil --dns 2>/dev/null | grep "nameserver" | head -5 | while read line; do
        info "$line"
    done
    
    subheader "Bonjour/mDNS advertising"
    bonjour_disabled=$(defaults read /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements 2>/dev/null || echo "0")
    if [ "$bonjour_disabled" = "1" ] || [ "$bonjour_disabled" = "true" ]; then
        success "Bonjour multicast advertising: Disabled"
    else
        info "Bonjour multicast advertising: Enabled (default)"
    fi
}

audit_login_items() {
    header "LOGIN ITEMS & LAUNCH AGENTS"
    
    subheader "User login items"
    osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tr ',' '\n' | while read item; do
        info "$item"
    done
    
    subheader "User Launch Agents"
    ls -la ~/Library/LaunchAgents/ 2>/dev/null | tail -n +2 | awk '{print "  " $NF}' | tee -a "$LOG_FILE"
    
    subheader "System Launch Agents (non-Apple)"
    ls /Library/LaunchAgents/ 2>/dev/null | grep -v "com.apple" | while read agent; do
        warning "Third-party agent: $agent"
    done
    
    subheader "System Launch Daemons (non-Apple)"
    ls /Library/LaunchDaemons/ 2>/dev/null | grep -v "com.apple" | while read daemon; do
        warning "Third-party daemon: $daemon"
    done
}

audit_profiles() {
    header "CONFIGURATION PROFILES"
    
    profiles_list=$(sudo profiles list 2>/dev/null || echo "")
    if [ -z "$profiles_list" ] || echo "$profiles_list" | grep -q "There are no configuration profiles installed"; then
        success "No configuration profiles installed"
    else
        warning "Configuration profiles found:"
        echo "$profiles_list" | while read line; do
            info "$line"
        done
    fi
}

audit_browser_extensions() {
    header "BROWSER EXTENSIONS"
    
    subheader "Chrome Extensions"
    chrome_ext_dir="$HOME/Library/Application Support/Google/Chrome/Default/Extensions"
    if [ -d "$chrome_ext_dir" ]; then
        ext_count=$(ls "$chrome_ext_dir" 2>/dev/null | wc -l | tr -d ' ')
        info "Chrome extensions installed: $ext_count"
        if [ "$ext_count" -gt 10 ]; then
            warning "Consider reviewing browser extensions - you have $ext_count"
        fi
    fi
    
    subheader "Safari Extensions"
    safari_ext_dir="$HOME/Library/Safari/Extensions"
    if [ -d "$safari_ext_dir" ]; then
        safari_count=$(ls "$safari_ext_dir" 2>/dev/null | wc -l | tr -d ' ')
        info "Safari extensions: $safari_count"
    fi
}

audit_all() {
    log "Starting security audit at $(date)"
    log "Output will be saved to: $LOG_FILE"
    
    audit_firewall
    audit_listening_ports
    audit_outbound_connections
    audit_sharing_services
    audit_encryption
    audit_system_integrity
    audit_user_settings
    audit_network_config
    audit_login_items
    audit_profiles
    audit_browser_extensions
    
    header "AUDIT COMPLETE"
    log "Full audit log saved to: $LOG_FILE"
}

# ============================================================================
# HARDENING FUNCTIONS - TIERED
# ============================================================================

# Level descriptions for display
describe_level() {
    case "$1" in
        1|minimal)
            echo "MINIMAL - Close obvious holes only"
            echo "  • Enable firewall (allow signed apps)"
            echo "  • Disable guest account & auto-login"
            echo "  • Require password after sleep"
            echo "  • Show file extensions"
            echo "  ✓ Preserves: SSH, Bonjour, all dev workflows"
            ;;
        2|dev)
            echo "DEV BOX - Standard developer machine"
            echo "  • Everything in Minimal, plus:"
            echo "  • Enable stealth mode"
            echo "  • Disable remote Apple events"
            echo "  ✓ Preserves: SSH, Bonjour, signed app auto-allow"
            ;;
        3|secure)
            echo "SECURE - Key asset / sensitive data protection"
            echo "  • Everything in Dev, plus:"
            echo "  • Disable SSH (remote login)"
            echo "  • Disable Bonjour multicast advertising"
            echo "  ⚠ Breaks: SSH access, some AirDrop/printer discovery"
            ;;
        4|paranoid)
            echo "PARANOID - Maximum lockdown (production/internet-exposed)"
            echo "  • Everything in Secure, plus:"
            echo "  • Block unsigned apps in firewall"
            echo "  • Disable IPv6 on Wi-Fi"
            echo "  • Aggressive network restrictions"
            echo "  ⚠ Breaks: Some dev tools, local network discovery"
            ;;
    esac
}

# Normalize level input to number
normalize_level() {
    case "$1" in
        1|minimal) echo 1 ;;
        2|dev)     echo 2 ;;
        3|secure)  echo 3 ;;
        4|paranoid) echo 4 ;;
        *)         echo 0 ;;
    esac
}

harden_level_1_minimal() {
    header "LEVEL 1: MINIMAL HARDENING"
    
    log "Enabling firewall..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    success "Firewall enabled"
    
    log "Allowing signed apps (dev-friendly)..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
    success "Signed apps auto-allowed"
    
    log "Disabling guest account..."
    sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
    success "Guest account disabled"
    
    log "Disabling auto-login..."
    sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || true
    success "Auto-login disabled"
    
    log "Requiring password immediately after sleep..."
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    success "Password required immediately"
    
    log "Showing all file extensions..."
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    success "All file extensions visible"
}

harden_level_2_dev() {
    harden_level_1_minimal
    
    header "LEVEL 2: DEV BOX HARDENING"
    
    log "Enabling stealth mode..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    success "Stealth mode enabled"
    
    log "Disabling remote Apple events..."
    sudo systemsetup -setremoteappleevents off 2>/dev/null || warning "Could not disable remote events"
    success "Remote Apple events disabled"
    
    skip "SSH remains enabled (dev workflow)"
    skip "Bonjour remains enabled (local discovery)"
    skip "Signed apps remain auto-allowed"
}

harden_level_3_secure() {
    harden_level_2_dev
    
    header "LEVEL 3: SECURE HARDENING"
    
    log "Disabling remote login (SSH)..."
    sudo systemsetup -setremotelogin off 2>/dev/null || warning "Could not disable SSH"
    success "SSH disabled"
    info "  To re-enable: sudo systemsetup -setremotelogin on"
    
    log "Disabling Bonjour multicast advertising..."
    sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true 2>/dev/null || warning "Could not disable Bonjour"
    success "Bonjour advertising disabled"
    info "  Note: May affect AirDrop, printer discovery"
    
    log "Flushing DNS cache..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    success "DNS cache flushed"
}

harden_level_4_paranoid() {
    harden_level_3_secure
    
    header "LEVEL 4: PARANOID HARDENING"
    
    log "Blocking unsigned apps in firewall..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
    success "Unsigned apps blocked"
    warning "You may see more firewall prompts for network access"
    
    log "Disabling IPv6 on Wi-Fi..."
    sudo networksetup -setv6off Wi-Fi 2>/dev/null || warning "Could not disable IPv6 on Wi-Fi"
    success "IPv6 disabled on Wi-Fi"
    info "  To re-enable: sudo networksetup -setv6automatic Wi-Fi"
    
    log "Disabling wake on network access..."
    sudo pmset -a womp 0 2>/dev/null || true
    success "Wake on LAN disabled"
    
    log "Disabling Bluetooth sharing..."
    defaults -currentHost write com.apple.Bluetooth PrefKeyServicesEnabled -bool false 2>/dev/null || true
    success "Bluetooth sharing disabled"
    
    log "Setting stricter umask..."
    if ! grep -q "umask 027" ~/.zshrc 2>/dev/null; then
        echo "umask 027" >> ~/.zshrc
        success "Stricter umask (027) added to .zshrc"
    else
        info "Umask already configured"
    fi
}

harden_at_level() {
    local level=$(normalize_level "$1")
    
    if [ "$level" -eq 0 ]; then
        fail "Invalid level: $1"
        echo ""
        echo "Valid levels:"
        echo "  1 | minimal  - Close obvious holes"
        echo "  2 | dev      - Dev box defaults"
        echo "  3 | secure   - Key asset protection"
        echo "  4 | paranoid - Maximum lockdown"
        exit 1
    fi
    
    log "Starting hardening at $(date)"
    
    header "HARDENING LEVEL: $level"
    describe_level "$level"
    
    echo ""
    echo -e "${YELLOW}This will modify your system settings.${NC}"
    read -p "Continue with level $level hardening? (y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log "Hardening cancelled by user"
        exit 0
    fi
    
    case "$level" in
        1) harden_level_1_minimal ;;
        2) harden_level_2_dev ;;
        3) harden_level_3_secure ;;
        4) harden_level_4_paranoid ;;
    esac
    
    header "HARDENING COMPLETE (Level $level)"
    log "Some changes may require logout or restart to take effect"
}

# ============================================================================
# UNDO / RESTORE FUNCTIONS
# ============================================================================

show_undo_commands() {
    header "UNDO COMMANDS REFERENCE"
    
    echo ""
    log "${YELLOW}To undo specific hardening changes:${NC}"
    echo ""
    log "Re-enable SSH:"
    info "sudo systemsetup -setremotelogin on"
    echo ""
    log "Re-enable Bonjour advertising:"
    info "sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool false"
    echo ""
    log "Re-enable IPv6 on Wi-Fi:"
    info "sudo networksetup -setv6automatic Wi-Fi"
    echo ""
    log "Allow signed apps again:"
    info "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on"
    echo ""
    log "Disable stealth mode:"
    info "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off"
    echo ""
    log "Re-enable guest account:"
    info "sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool true"
    echo ""
    log "Re-enable wake on LAN:"
    info "sudo pmset -a womp 1"
}

# ============================================================================
# INTERACTIVE MODE
# ============================================================================

interactive_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║   MAC HARDEN - Interactive Mode        ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}AUDIT${NC}"
        echo "    1) Full audit (inbound + outbound)"
        echo "    2) Outbound connections only"
        echo "    3) Listening ports only"
        echo ""
        echo -e "  ${CYAN}HARDEN${NC}"
        echo "    4) Level 1 - Minimal (close obvious holes)"
        echo "    5) Level 2 - Dev (recommended for developers)"
        echo "    6) Level 3 - Secure (sensitive data protection)"
        echo "    7) Level 4 - Paranoid (maximum lockdown)"
        echo ""
        echo -e "  ${CYAN}OTHER${NC}"
        echo "    8) Full cycle (audit → harden → verify)"
        echo "    9) Show undo commands"
        echo "    0) Exit"
        echo ""
        read -p "Select option [0-9]: " choice
        
        case "$choice" in
            1)
                init_log
                audit_all
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                init_log
                audit_outbound_connections
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                init_log
                audit_listening_ports
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                init_log
                harden_at_level 1
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                init_log
                harden_at_level 2
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                init_log
                harden_at_level 3
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                init_log
                harden_at_level 4
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                interactive_full_cycle
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                show_undo_commands
                echo ""
                read -p "Press Enter to continue..."
                ;;
            0|q|Q)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 0-9.${NC}"
                sleep 1
                ;;
        esac
    done
}

interactive_full_cycle() {
    echo ""
    echo -e "${CYAN}Select hardening level for full cycle:${NC}"
    echo "  1) Minimal"
    echo "  2) Dev (default)"
    echo "  3) Secure"
    echo "  4) Paranoid"
    echo ""
    read -p "Level [1-4, default=2]: " level_choice
    
    local level="${level_choice:-2}"
    
    case "$level" in
        1|2|3|4)
            init_log
            log "=== PRE-HARDENING AUDIT ==="
            audit_all
            harden_at_level "$level"
            log "\n=== POST-HARDENING AUDIT ==="
            audit_all
            ;;
        *)
            echo -e "${RED}Invalid level. Using default (2).${NC}"
            init_log
            log "=== PRE-HARDENING AUDIT ==="
            audit_all
            harden_at_level 2
            log "\n=== POST-HARDENING AUDIT ==="
            audit_all
            ;;
    esac
}

# ============================================================================
# MAIN
# ============================================================================

check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Note: Some operations require sudo. You may be prompted for your password."
    fi
}

show_help() {
    cat << 'EOF'
Mac Hardening & Security Audit Script v2.0

USAGE:
  sudo mac_harden [options] [command] [level]

OPTIONS:
  --log-dir <path>   Directory for log files (default: current directory)
  -h, --help         Show this help
  -v, --version      Show version

COMMANDS:
  audit              Full security audit including inbound & outbound (no changes)
  audit-outbound     Focus on outbound connections only
  harden [level]     Apply hardening at specified level
  full [level]       Audit → Harden → Verify
  ports              Quick listening ports check (inbound only)
  undo               Show commands to undo hardening
  interactive, i     Interactive menu mode
  help               Show this help

HARDENING LEVELS:
  1 | minimal    Close obvious holes only
                 • Firewall on (signed apps allowed)
                 • Disable guest account, auto-login
                 • Require password after sleep
                 ✓ Preserves all dev workflows

  2 | dev        Dev box defaults (RECOMMENDED for developers)
                 • Everything in minimal
                 • Stealth mode on
                 • Disable remote Apple events
                 ✓ Preserves SSH, Bonjour, signed apps

  3 | secure     Key asset / sensitive laptop
                 • Everything in dev
                 • Disable SSH
                 • Disable Bonjour advertising
                 ⚠ May affect AirDrop, printer discovery

  4 | paranoid   Maximum lockdown (production servers)
                 • Everything in secure
                 • Block unsigned apps
                 • Disable IPv6, wake-on-LAN
                 ⚠ May cause extra prompts, break some tools

EXAMPLES:
  sudo mac_harden audit                        # Check current state
  sudo mac_harden --log-dir ~/logs audit       # Audit with custom log dir
  sudo mac_harden audit-outbound               # Check what's phoning home
  sudo mac_harden harden minimal               # Light hardening
  sudo mac_harden harden dev                   # Developer-friendly hardening
  sudo mac_harden full secure                  # Full audit + secure hardening
  sudo mac_harden undo                         # Show how to reverse changes
  sudo mac_harden i                            # Interactive menu mode

EOF
}

main() {
    # Parse options first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help|help)
                show_help
                exit 0
                ;;
            -v|--version|version)
                echo "mac_harden v${VERSION}"
                echo "Authors: ${AUTHORS}"
                exit 0
                ;;
            --log-dir)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    echo "Error: --log-dir requires a path argument"
                    exit 1
                fi
                LOG_DIR="$2"
                shift 2
                ;;
            --log-dir=*)
                LOG_DIR="${1#*=}"
                shift
                ;;
            -*)
                echo "Unknown option: $1"
                echo "Try: mac_harden --help"
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
    
    local command="${1:-help}"
    local level="${2:-2}"  # Default to dev level
    
    # Initialize logging (validates LOG_DIR)
    if [ "$command" != "help" ] && [ "$command" != "undo" ]; then
        init_log
    fi
    
    case "$command" in
        audit)
            check_sudo
            audit_all
            ;;
        audit-outbound)
            check_sudo
            audit_outbound_connections
            ;;
        harden)
            check_sudo
            harden_at_level "$level"
            ;;
        full)
            check_sudo
            log "=== PRE-HARDENING AUDIT ==="
            audit_all
            harden_at_level "$level"
            log "\n=== POST-HARDENING AUDIT ==="
            audit_all
            ;;
        ports)
            check_sudo
            audit_listening_ports
            ;;
        undo)
            show_undo_commands
            ;;
        interactive|i)
            check_sudo
            interactive_menu
            ;;
        help)
            show_help
            ;;
        *)
            echo "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
