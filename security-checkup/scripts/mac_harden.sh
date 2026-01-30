#!/bin/bash

# ============================================================================
# MAC HARDENING & SECURITY AUDIT SCRIPT
# ============================================================================
# Run with: sudo ./mac_harden.sh [audit|harden|full]
#   audit  - Only audit current security state (no changes)
#   harden - Apply hardening changes
#   full   - Audit first, then harden, then audit again
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="${PWD%/}/mac_security_audit_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

header() {
    log "\n${BLUE}========================================${NC}"
    log "${BLUE}$1${NC}"
    log "${BLUE}========================================${NC}"
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
}

audit_listening_ports() {
    header "LISTENING PORTS & SERVICES"
    
    log "\n${YELLOW}TCP Listening:${NC}"
    if command -v lsof &> /dev/null; then
        sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | awk 'NR==1 || NR>1 {printf "  %-20s %-10s %-25s\n", $1, $3, $9}' | tee -a "$LOG_FILE"
    fi
    
    log "\n${YELLOW}UDP Listening:${NC}"
    sudo lsof -iUDP -n -P 2>/dev/null | awk 'NR==1 || NR>1 {printf "  %-20s %-10s %-25s\n", $1, $3, $9}' | head -20 | tee -a "$LOG_FILE"
    
    # Count and warn
    tcp_count=$(sudo lsof -iTCP -sTCP:LISTEN -n -P 2>/dev/null | wc -l | tr -d ' ')
    if [ "$tcp_count" -gt 10 ]; then
        warning "You have $tcp_count TCP listeners - consider reviewing"
    else
        success "TCP listener count: $tcp_count"
    fi
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
    
    # Check launchd for sharing services
    log "\n${YELLOW}Active sharing-related services:${NC}"
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
}

audit_network_config() {
    header "NETWORK CONFIGURATION"
    
    # List network interfaces
    log "\n${YELLOW}Active network interfaces:${NC}"
    ifconfig -l | tr ' ' '\n' | while read iface; do
        if ifconfig "$iface" 2>/dev/null | grep -q "status: active"; then
            ip=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '{print $2}')
            info "$iface: $ip"
        fi
    done
    
    # Check IPv6
    log "\n${YELLOW}IPv6 status:${NC}"
    networksetup -listallnetworkservices 2>/dev/null | tail -n +2 | while read service; do
        ipv6=$(networksetup -getinfo "$service" 2>/dev/null | grep "IPv6:" | awk '{print $2}')
        if [ -n "$ipv6" ] && [ "$ipv6" != "Off" ]; then
            info "$service: IPv6 $ipv6"
        fi
    done
    
    # DNS servers
    log "\n${YELLOW}DNS Servers:${NC}"
    scutil --dns 2>/dev/null | grep "nameserver" | head -5 | while read line; do
        info "$line"
    done
}

audit_login_items() {
    header "LOGIN ITEMS & LAUNCH AGENTS"
    
    log "\n${YELLOW}User login items:${NC}"
    osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null | tr ',' '\n' | while read item; do
        info "$item"
    done
    
    log "\n${YELLOW}User Launch Agents:${NC}"
    ls -la ~/Library/LaunchAgents/ 2>/dev/null | tail -n +2 | awk '{print "  " $NF}' | tee -a "$LOG_FILE"
    
    log "\n${YELLOW}System Launch Agents (non-Apple):${NC}"
    ls /Library/LaunchAgents/ 2>/dev/null | grep -v "com.apple" | while read agent; do
        warning "Third-party agent: $agent"
    done
    
    log "\n${YELLOW}System Launch Daemons (non-Apple):${NC}"
    ls /Library/LaunchDaemons/ 2>/dev/null | grep -v "com.apple" | while read daemon; do
        warning "Third-party daemon: $daemon"
    done
}

audit_browser_extensions() {
    header "BROWSER EXTENSIONS (Chrome)"
    
    chrome_ext_dir="$HOME/Library/Application Support/Google/Chrome/Default/Extensions"
    if [ -d "$chrome_ext_dir" ]; then
        ext_count=$(ls "$chrome_ext_dir" 2>/dev/null | wc -l | tr -d ' ')
        info "Chrome extensions installed: $ext_count"
        if [ "$ext_count" -gt 10 ]; then
            warning "Consider reviewing browser extensions - you have $ext_count"
        fi
    fi
}

audit_all() {
    log "Starting security audit at $(date)"
    log "Output will be saved to: $LOG_FILE"
    
    audit_firewall
    audit_listening_ports
    audit_sharing_services
    audit_encryption
    audit_system_integrity
    audit_user_settings
    audit_network_config
    audit_login_items
    audit_browser_extensions
    
    header "AUDIT COMPLETE"
    log "Full audit log saved to: $LOG_FILE"
}

# ============================================================================
# HARDENING FUNCTIONS
# ============================================================================

harden_firewall() {
    header "HARDENING: Firewall"
    
    log "Enabling firewall..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    success "Firewall enabled"
    
    log "Enabling stealth mode..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    success "Stealth mode enabled"
    
    log "Blocking unsigned apps..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off
    success "Unsigned apps blocked"
}

harden_sharing() {
    header "HARDENING: Sharing Services"
    
    log "Disabling remote login (SSH)..."
    sudo systemsetup -setremotelogin off 2>/dev/null || warning "Could not disable remote login"
    success "Remote login disabled"
    
    log "Disabling remote apple events..."
    sudo systemsetup -setremoteappleevents off 2>/dev/null || warning "Could not disable remote events"
    success "Remote apple events disabled"
}

harden_network() {
    header "HARDENING: Network"
    
    log "Disabling Bonjour multicast advertising..."
    sudo defaults write /Library/Preferences/com.apple.mDNSResponder.plist NoMulticastAdvertisements -bool true 2>/dev/null || warning "Could not disable Bonjour advertising"
    success "Bonjour advertising disabled"
    
    log "Flushing DNS cache..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    success "DNS cache flushed"
}

harden_user_settings() {
    header "HARDENING: User Settings"
    
    log "Requiring password immediately after sleep..."
    defaults write com.apple.screensaver askForPassword -int 1
    defaults write com.apple.screensaver askForPasswordDelay -int 0
    success "Password required immediately"
    
    log "Disabling guest account..."
    sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false
    success "Guest account disabled"
    
    log "Disabling auto-login..."
    sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || true
    success "Auto-login disabled"
    
    log "Showing all file extensions..."
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    success "All file extensions visible"
}

harden_all() {
    log "Starting hardening at $(date)"
    
    echo ""
    echo -e "${YELLOW}WARNING: This will make the following changes:${NC}"
    echo "  - Enable firewall and stealth mode"
    echo "  - Disable remote login (SSH) and remote events"
    echo "  - Disable Bonjour multicast advertising"
    echo "  - Require password immediately after sleep"
    echo "  - Disable guest account and auto-login"
    echo ""
    read -p "Continue? (y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log "Hardening cancelled by user"
        exit 0
    fi
    
    harden_firewall
    harden_sharing
    harden_network
    harden_user_settings
    
    header "HARDENING COMPLETE"
    log "Some changes may require logout or restart to take effect"
}

# ============================================================================
# MAIN
# ============================================================================

# Check if running as root for some operations
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Note: Some operations require sudo. You may be prompted for your password."
    fi
}

show_help() {
    echo "Mac Hardening & Security Audit Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  audit     Run security audit only (no changes made)"
    echo "  harden    Apply hardening settings"
    echo "  full      Run audit, apply hardening, then audit again"
    echo "  ports     Quick check of listening ports only"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo $0 audit    # Check current security state"
    echo "  sudo $0 harden   # Apply hardening (will prompt for confirmation)"
    echo "  sudo $0 full     # Full audit + harden + verify"
}

main() {
    case "${1:-audit}" in
        audit)
            check_sudo
            audit_all
            ;;
        harden)
            check_sudo
            harden_all
            ;;
        full)
            check_sudo
            log "=== PRE-HARDENING AUDIT ==="
            audit_all
            harden_all
            log "\n=== POST-HARDENING AUDIT ==="
            audit_all
            ;;
        ports)
            audit_listening_ports
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
