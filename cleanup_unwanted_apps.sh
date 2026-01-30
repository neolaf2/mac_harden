#!/bin/bash

# ============================================================================
# CLEANUP SCRIPT - Remove unwanted apps and launch agents/daemons
# Generated: 2026-01-29
# Target: Rewind, SelfControl, Freedom, Tunnelblick
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
log_fail() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "  $1"; }

echo ""
echo "============================================"
echo "  Cleanup: Rewind, SelfControl, Freedom, Tunnelblick"
echo "============================================"
echo ""
echo "This script will:"
echo "  - Unload and remove launch agents/daemons"
echo "  - Delete applications"
echo "  - Remove config files"
echo ""
read -p "Continue? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "--- Stopping and removing launch agents/daemons ---"

# Rewind (user agent)
if [ -f "$HOME/Library/LaunchAgents/com.rewind.Rewind.plist" ]; then
    launchctl unload "$HOME/Library/LaunchAgents/com.rewind.Rewind.plist" 2>/dev/null || true
    rm -f "$HOME/Library/LaunchAgents/com.rewind.Rewind.plist"
    log_success "Removed Rewind launch agent"
else
    log_info "Rewind launch agent not found (already removed)"
fi

# SelfControl (system daemon)
if [ -f "/Library/LaunchDaemons/org.eyebeam.selfcontrold.plist" ]; then
    sudo launchctl bootout system/org.eyebeam.selfcontrold 2>/dev/null || true
    sudo rm -f /Library/LaunchDaemons/org.eyebeam.selfcontrold.plist
    log_success "Removed SelfControl daemon"
else
    log_info "SelfControl daemon not found (already removed)"
fi

# Freedom (system daemon)
if [ -f "/Library/LaunchDaemons/com.80pct.FreedomHelper.plist" ]; then
    sudo launchctl bootout system/com.80pct.FreedomHelper 2>/dev/null || true
    sudo rm -f /Library/LaunchDaemons/com.80pct.FreedomHelper.plist
    log_success "Removed Freedom daemon"
else
    log_info "Freedom daemon not found (already removed)"
fi

# Tunnelblick (system daemon)
if [ -f "/Library/LaunchDaemons/net.tunnelblick.tunnelblick.tunnelblickd.plist" ]; then
    sudo launchctl bootout system/net.tunnelblick.tunnelblick.tunnelblickd 2>/dev/null || true
    sudo rm -f /Library/LaunchDaemons/net.tunnelblick.tunnelblick.tunnelblickd.plist
    log_success "Removed Tunnelblick daemon"
else
    log_info "Tunnelblick daemon not found (already removed)"
fi

echo ""
echo "--- Removing applications ---"

apps=(
    "/Applications/Rewind.app"
    "/Applications/SelfControl.app"
    "/Applications/Freedom.app"
    "/Applications/Tunnelblick.app"
)

for app in "${apps[@]}"; do
    if [ -d "$app" ]; then
        sudo rm -rf "$app"
        log_success "Removed $app"
    else
        log_info "$app not found (already removed)"
    fi
done

echo ""
echo "--- Removing config files ---"

configs=(
    "$HOME/Library/Application Support/Rewind"
    "$HOME/Library/Application Support/SelfControl"
    "$HOME/Library/Application Support/Freedom"
    "$HOME/Library/Application Support/Tunnelblick"
    "$HOME/Library/Preferences/com.rewind.Rewind.plist"
    "$HOME/Library/Preferences/org.eyebeam.SelfControl.plist"
    "$HOME/Library/Preferences/com.80pct.FreedomHelper.plist"
    "$HOME/Library/Preferences/net.tunnelblick.tunnelblick.plist"
    "$HOME/.tunnelblick"
    "$HOME/Library/Caches/com.rewind.Rewind"
    "$HOME/Library/Caches/org.eyebeam.SelfControl"
    "$HOME/Library/Caches/com.80pct.Freedom"
    "$HOME/Library/Caches/net.tunnelblick.tunnelblick"
)

for config in "${configs[@]}"; do
    if [ -e "$config" ]; then
        rm -rf "$config"
        log_success "Removed $config"
    fi
done

echo ""
echo "--- Verifying cleanup ---"

# Check for any remaining traces
remaining=0

for item in "rewind" "selfcontrol" "eyebeam" "freedom" "80pct" "tunnelblick"; do
    if sudo launchctl list 2>/dev/null | grep -qi "$item"; then
        log_warn "Still found running: $item"
        remaining=1
    fi
    if ls /Library/LaunchDaemons/ 2>/dev/null | grep -qi "$item"; then
        log_warn "Still found daemon: $item"
        remaining=1
    fi
    if ls ~/Library/LaunchAgents/ 2>/dev/null | grep -qi "$item"; then
        log_warn "Still found agent: $item"
        remaining=1
    fi
done

echo ""
if [ $remaining -eq 0 ]; then
    log_success "Cleanup complete! All items removed."
else
    log_warn "Some items may remain. A reboot may be required."
fi

echo ""
echo "Recommended: Run 'sudo mac_harden audit' to verify."
