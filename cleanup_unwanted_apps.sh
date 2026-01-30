#!/bin/bash

# ============================================================================
# INTERACTIVE CLEANUP SCRIPT - Audit and remove unwanted processes/daemons
# ============================================================================
# Scans for launch agents, daemons, and running processes, then prompts
# for removal of each item interactively.
#
# Usage: sudo ./cleanup_unwanted_apps.sh
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
log_fail() { echo -e "${RED}✗ $1${NC}"; }
log_info() { echo -e "  $1"; }
header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }

# Prompt for action on an item
# Returns 0 if user wants to remove, 1 otherwise
prompt_remove() {
    local item_type="$1"
    local item_name="$2"
    local item_path="$3"

    echo -e "${YELLOW}Found $item_type:${NC} $item_name"
    if [ -n "$item_path" ]; then
        log_info "Path: $item_path"
    fi

    read -p "  Remove this item? (y/N/q to quit): " choice
    case "$choice" in
        y|Y) return 0 ;;
        q|Q) echo "Exiting..."; exit 0 ;;
        *) return 1 ;;
    esac
}

echo ""
echo "============================================"
echo "  Interactive Cleanup - Process & Daemon Audit"
echo "============================================"
echo ""
echo "This script will scan and prompt for removal of:"
echo "  - User Launch Agents"
echo "  - System Launch Agents (non-Apple)"
echo "  - System Launch Daemons (non-Apple)"
echo ""
read -p "Start audit? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

removed_count=0
skipped_count=0

# ============================================================================
# USER LAUNCH AGENTS
# ============================================================================
header "User Launch Agents (~/.Library/LaunchAgents)"

if [ -d "$HOME/Library/LaunchAgents" ]; then
    for plist in "$HOME/Library/LaunchAgents"/*.plist; do
        [ -f "$plist" ] || continue

        name=$(basename "$plist" .plist)

        if prompt_remove "User Agent" "$name" "$plist"; then
            launchctl unload "$plist" 2>/dev/null || true
            rm -f "$plist"
            log_success "Removed $name"
            ((removed_count++))
        else
            log_info "Skipped $name"
            ((skipped_count++))
        fi
        echo ""
    done
else
    log_info "No user launch agents directory found"
fi

# ============================================================================
# SYSTEM LAUNCH AGENTS (non-Apple)
# ============================================================================
header "System Launch Agents (/Library/LaunchAgents) - non-Apple"

if [ -d "/Library/LaunchAgents" ]; then
    for plist in /Library/LaunchAgents/*.plist; do
        [ -f "$plist" ] || continue

        name=$(basename "$plist" .plist)

        # Skip Apple items
        if [[ "$name" == com.apple.* ]]; then
            continue
        fi

        if prompt_remove "System Agent" "$name" "$plist"; then
            sudo launchctl unload "$plist" 2>/dev/null || true
            sudo rm -f "$plist"
            log_success "Removed $name"
            ((removed_count++))
        else
            log_info "Skipped $name"
            ((skipped_count++))
        fi
        echo ""
    done
else
    log_info "No system launch agents directory found"
fi

# ============================================================================
# SYSTEM LAUNCH DAEMONS (non-Apple)
# ============================================================================
header "System Launch Daemons (/Library/LaunchDaemons) - non-Apple"

if [ -d "/Library/LaunchDaemons" ]; then
    for plist in /Library/LaunchDaemons/*.plist; do
        [ -f "$plist" ] || continue

        name=$(basename "$plist" .plist)

        # Skip Apple items
        if [[ "$name" == com.apple.* ]]; then
            continue
        fi

        if prompt_remove "System Daemon" "$name" "$plist"; then
            sudo launchctl bootout system/"$name" 2>/dev/null || true
            sudo rm -f "$plist"
            log_success "Removed $name"
            ((removed_count++))
        else
            log_info "Skipped $name"
            ((skipped_count++))
        fi
        echo ""
    done
else
    log_info "No system launch daemons directory found"
fi

# ============================================================================
# ASSOCIATED APPLICATIONS
# ============================================================================
header "Checking for associated applications"

# Build list of removed items to check for matching apps
echo "Scanning /Applications for non-Apple apps..."
echo ""

for app in /Applications/*.app; do
    [ -d "$app" ] || continue

    app_name=$(basename "$app" .app)

    # Skip common Apple/system apps
    case "$app_name" in
        Safari|Mail|Calendar|Notes|Reminders|Maps|Photos|FaceTime|Messages|Music|TV|Podcasts|News|Books|"App Store"|"System Preferences"|"System Settings"|Utilities|Automator|Calculator|Chess|Clock|"Dictionary"|"Font Book"|Grapher|"Image Capture"|Keynote|Numbers|Pages|Preview|"QuickTime Player"|Shortcuts|Siri|Stickies|Stocks|TextEdit|Tips|"Voice Memos"|Weather|Xcode)
            continue
            ;;
    esac

    if prompt_remove "Application" "$app_name" "$app"; then
        sudo rm -rf "$app"
        log_success "Removed $app_name.app"
        ((removed_count++))

        # Also remove associated configs
        config_dirs=(
            "$HOME/Library/Application Support/$app_name"
            "$HOME/Library/Caches/$app_name"
            "$HOME/Library/Preferences/*$app_name*"
        )
        for config in "${config_dirs[@]}"; do
            if [ -e "$config" ]; then
                rm -rf "$config" 2>/dev/null || true
                log_info "Cleaned up: $config"
            fi
        done
    else
        log_info "Skipped $app_name"
        ((skipped_count++))
    fi
    echo ""
done

# ============================================================================
# SUMMARY
# ============================================================================
header "Cleanup Summary"

echo -e "  Removed: ${GREEN}$removed_count${NC} items"
echo -e "  Skipped: ${YELLOW}$skipped_count${NC} items"
echo ""

if [ $removed_count -gt 0 ]; then
    log_success "Cleanup complete!"
    log_info "Some changes may require a restart to take full effect."
else
    log_info "No items were removed."
fi

echo ""
echo "Recommended: Run 'sudo mac_harden audit' to verify system state."
echo ""
