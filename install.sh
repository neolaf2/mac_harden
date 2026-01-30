#!/bin/bash

# ============================================================================
# INSTALL SCRIPT - Mac Hardening & Security Tools
# ============================================================================
# Installs mac_harden, process_audit, cleanup_apps, and cat_claude to /usr/local/bin
#
# Usage: sudo ./install.sh
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "  $1"; }

INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "============================================"
echo "  Mac Harden Tools - Installer"
echo "============================================"
echo ""

# Check for root
if [ "$EUID" -ne 0 ]; then
    fail "Please run with sudo: sudo ./install.sh"
fi

# Check install directory exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Creating $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
fi

# Install mac_harden
if [ -f "$SCRIPT_DIR/mac_harden.sh" ]; then
    cp "$SCRIPT_DIR/mac_harden.sh" "$INSTALL_DIR/mac_harden"
    chmod 755 "$INSTALL_DIR/mac_harden"
    chown root:wheel "$INSTALL_DIR/mac_harden"
    success "Installed mac_harden to $INSTALL_DIR/mac_harden"
else
    fail "mac_harden.sh not found in $SCRIPT_DIR"
fi

# Install process_audit
if [ -f "$SCRIPT_DIR/process_audit.sh" ]; then
    cp "$SCRIPT_DIR/process_audit.sh" "$INSTALL_DIR/process_audit"
    chmod 755 "$INSTALL_DIR/process_audit"
    chown root:wheel "$INSTALL_DIR/process_audit"
    success "Installed process_audit to $INSTALL_DIR/process_audit"
else
    echo -e "${YELLOW}⚠ process_audit.sh not found - skipping${NC}"
fi

# Install cat_claude
if [ -f "$SCRIPT_DIR/cat_claude.sh" ]; then
    cp "$SCRIPT_DIR/cat_claude.sh" "$INSTALL_DIR/cat_claude"
    chmod 755 "$INSTALL_DIR/cat_claude"
    chown root:wheel "$INSTALL_DIR/cat_claude"
    success "Installed cat_claude to $INSTALL_DIR/cat_claude"
else
    echo -e "${YELLOW}⚠ cat_claude.sh not found - skipping${NC}"
fi

# Install cleanup_apps
if [ -f "$SCRIPT_DIR/cleanup_unwanted_apps.sh" ]; then
    cp "$SCRIPT_DIR/cleanup_unwanted_apps.sh" "$INSTALL_DIR/cleanup_apps"
    chmod 755 "$INSTALL_DIR/cleanup_apps"
    chown root:wheel "$INSTALL_DIR/cleanup_apps"
    success "Installed cleanup_apps to $INSTALL_DIR/cleanup_apps"
else
    echo -e "${YELLOW}⚠ cleanup_unwanted_apps.sh not found - skipping${NC}"
fi

echo ""
echo "============================================"
echo "  Installation Complete"
echo "============================================"
echo ""
info "Installed to: $INSTALL_DIR"
info ""
info "Verify installation:"
info "  mac_harden --version"
info "  process_audit --version"
info "  cat_claude --version"
info "  cleanup_apps (interactive)"
info ""
info "Quick start:"
info "  sudo mac_harden audit"
info "  sudo mac_harden i"
info "  process_audit"
info "  sudo cleanup_apps"
info "  opencode --help | cat_claude"
echo ""
