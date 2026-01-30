#!/bin/bash

# ============================================================================
# INSTALL SCRIPT - Mac Hardening & Process Audit Tools
# ============================================================================
# Installs mac_harden and process_audit to /usr/local/bin with proper permissions
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
info ""
info "Quick start:"
info "  sudo mac_harden audit"
info "  sudo mac_harden i"
info "  process_audit"
echo ""
