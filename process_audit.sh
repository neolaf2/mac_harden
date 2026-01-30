#!/bin/bash

# ============================================================================
# PROCESS AUDIT SCRIPT
# Authors: Richard Tong, Claude 4.5
# Version: 1.0.0
# ============================================================================
# Analyzes running processes, CPU usage, memory consumption, and runtime
# to identify optimization opportunities and suspicious activity.
#
# Usage: ./process_audit.sh [--log-dir <path>]
# ============================================================================

set -e

VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging
LOG_DIR="${PWD}"
LOG_FILE=""

init_log() {
    LOG_DIR="${LOG_DIR%/}"
    LOG_FILE="${LOG_DIR}/process_audit_$(date +%Y%m%d_%H%M%S).log"
    if [ ! -d "$LOG_DIR" ]; then
        echo "Error: Log directory '$LOG_DIR' does not exist"
        exit 1
    fi
    if [ ! -w "$LOG_DIR" ]; then
        echo "Error: Log directory '$LOG_DIR' is not writable"
        exit 1
    fi
}

log() { echo -e "$1" | tee -a "$LOG_FILE"; }
header() { log "\n${BLUE}========================================${NC}"; log "${BLUE}$1${NC}"; log "${BLUE}========================================${NC}"; }
subheader() { log "\n${CYAN}--- $1 ---${NC}"; }
success() { log "${GREEN}✓ $1${NC}"; }
warning() { log "${YELLOW}⚠ $1${NC}"; }
fail() { log "${RED}✗ $1${NC}"; }
info() { log "  $1"; }

# ============================================================================
# SYSTEM OVERVIEW
# ============================================================================

audit_system_overview() {
    header "SYSTEM OVERVIEW"
    
    # Uptime
    uptime_info=$(uptime)
    log "Uptime: $uptime_info"
    
    # Load averages
    load_avg=$(sysctl -n vm.loadavg 2>/dev/null | tr -d '{}')
    log "Load Average: $load_avg"
    
    # CPU cores
    cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null)
    log "CPU Cores: $cpu_cores"
    
    # Memory
    total_mem=$(sysctl -n hw.memsize 2>/dev/null)
    total_mem_gb=$(echo "scale=1; $total_mem / 1024 / 1024 / 1024" | bc)
    log "Total Memory: ${total_mem_gb} GB"
    
    # Memory pressure
    memory_pressure=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $NF}')
    if [ -n "$memory_pressure" ]; then
        log "Memory Free: $memory_pressure"
        free_pct=$(echo "$memory_pressure" | tr -d '%')
        if [ "$free_pct" -lt 10 ]; then
            fail "Memory pressure is HIGH - less than 10% free"
        elif [ "$free_pct" -lt 25 ]; then
            warning "Memory pressure is elevated - less than 25% free"
        else
            success "Memory pressure is normal"
        fi
    fi
}

# ============================================================================
# TOP CPU CONSUMERS
# ============================================================================

audit_cpu_usage() {
    header "TOP CPU CONSUMERS"
    
    subheader "Top 15 by CPU %"
    printf "  ${YELLOW}%-8s %-6s %-6s %-20s %s${NC}\n" "PID" "CPU%" "MEM%" "USER" "COMMAND"
    ps aux -r | head -16 | tail -15 | while read user pid cpu mem vsz rss tt stat started time command; do
        # Truncate command to 40 chars
        cmd_short=$(echo "$command" | cut -c1-40)
        printf "  %-8s %-6s %-6s %-20s %s\n" "$pid" "$cpu" "$mem" "$user" "$cmd_short"
    done | tee -a "$LOG_FILE"
    
    # Flag high CPU processes
    subheader "High CPU Alerts (>50%)"
    high_cpu=$(ps aux -r | awk 'NR>1 && $3>50 {print $2, $3, $11}')
    if [ -n "$high_cpu" ]; then
        echo "$high_cpu" | while read pid cpu cmd; do
            warning "PID $pid using ${cpu}% CPU: $cmd"
        done
    else
        success "No processes using >50% CPU"
    fi
}

# ============================================================================
# TOP MEMORY CONSUMERS
# ============================================================================

audit_memory_usage() {
    header "TOP MEMORY CONSUMERS"
    
    subheader "Top 15 by Memory %"
    printf "  ${YELLOW}%-8s %-6s %-6s %-12s %-20s %s${NC}\n" "PID" "MEM%" "CPU%" "RSS(MB)" "USER" "COMMAND"
    ps aux -m | head -16 | tail -15 | while read user pid cpu mem vsz rss tt stat started time command; do
        rss_mb=$(echo "scale=1; $rss / 1024" | bc)
        cmd_short=$(echo "$command" | cut -c1-35)
        printf "  %-8s %-6s %-6s %-12s %-20s %s\n" "$pid" "$mem" "$cpu" "$rss_mb" "$user" "$cmd_short"
    done | tee -a "$LOG_FILE"
    
    # Flag memory hogs (>1GB)
    subheader "Memory Hogs (>1GB RSS)"
    ps aux -m | awk 'NR>1 && $6>1048576 {printf "  %s (PID %s): %.1f GB - %s\n", $1, $2, $6/1024/1024, $11}' | while read line; do
        warning "$line"
    done | tee -a "$LOG_FILE"
    
    hog_count=$(ps aux -m | awk 'NR>1 && $6>1048576' | wc -l | tr -d ' ')
    if [ "$hog_count" -eq 0 ]; then
        success "No processes using >1GB memory"
    fi
}

# ============================================================================
# LONG-RUNNING PROCESSES
# ============================================================================

audit_long_running() {
    header "LONG-RUNNING PROCESSES"
    
    subheader "Processes running >24 hours (non-system)"
    
    # Get processes with elapsed time, filter user processes
    ps -eo pid,etime,user,comm | grep -v "^  PID" | while read pid etime user comm; do
        # Skip system users
        if [[ "$user" == "root" ]] || [[ "$user" == "_"* ]] || [[ "$user" == "nobody" ]]; then
            continue
        fi
        
        # Parse elapsed time (formats: MM:SS, HH:MM:SS, D-HH:MM:SS)
        if [[ "$etime" == *"-"* ]]; then
            # Days format
            days=$(echo "$etime" | cut -d'-' -f1)
            if [ "$days" -ge 1 ]; then
                info "PID $pid ($comm) - running $etime as $user"
            fi
        elif [[ $(echo "$etime" | tr -cd ':' | wc -c) -eq 2 ]]; then
            # HH:MM:SS format - check if hours > 24
            hours=$(echo "$etime" | cut -d':' -f1)
            if [ "$hours" -ge 24 ]; then
                info "PID $pid ($comm) - running $etime as $user"
            fi
        fi
    done | tee -a "$LOG_FILE"
    
    long_count=$(ps -eo etime | grep -E "^[0-9]+-|^[0-9]{2,}:" | wc -l | tr -d ' ')
    info "Total long-running processes (>24h): $long_count"
}

# ============================================================================
# PROCESS TREE / HIERARCHY
# ============================================================================

audit_process_tree() {
    header "PROCESS HIERARCHY (User Processes)"
    
    current_user=$(whoami)
    
    subheader "Your process tree"
    pstree -u "$current_user" 2>/dev/null | head -50 | tee -a "$LOG_FILE" || {
        # Fallback if pstree not installed
        info "pstree not installed. Install with: brew install pstree"
        ps -u "$current_user" -o pid,ppid,comm | head -30 | tee -a "$LOG_FILE"
    }
}

# ============================================================================
# SUSPICIOUS PROCESSES
# ============================================================================

audit_suspicious() {
    header "SUSPICIOUS PROCESS CHECK"
    
    subheader "Processes with no controlling terminal (potential daemons)"
    # User processes with no terminal that aren't common apps
    ps aux | awk '$7=="??" && $1!="root" && $1!~"^_" {print}' | grep -v -E "launchd|mdworker|Spotlight|Finder|Dock|WindowServer|loginwindow|corebrightness|cfprefsd|distnoted" | head -20 | while read line; do
        info "$line"
    done | tee -a "$LOG_FILE"
    
    subheader "Processes running from /tmp or unusual locations"
    ps aux | grep -E "/tmp/|/var/tmp/|/private/tmp/" | grep -v grep | while read line; do
        warning "$line"
    done | tee -a "$LOG_FILE"
    
    tmp_count=$(ps aux | grep -E "/tmp/|/var/tmp/|/private/tmp/" | grep -v grep | wc -l | tr -d ' ')
    if [ "$tmp_count" -eq 0 ]; then
        success "No processes running from /tmp directories"
    fi
    
    subheader "Hidden processes (command starts with .)"
    ps aux | awk '$11 ~ /^\./ || $11 ~ /\/\./' | while read line; do
        warning "$line"
    done | tee -a "$LOG_FILE"
    
    hidden_count=$(ps aux | awk '$11 ~ /^\./ || $11 ~ /\/\./' | wc -l | tr -d ' ')
    if [ "$hidden_count" -eq 0 ]; then
        success "No hidden processes found"
    fi
    
    subheader "Processes with deleted binaries"
    # This checks if the executable path still exists
    for pid in $(ps -eo pid= 2>/dev/null); do
        exe_path=$(ps -p "$pid" -o comm= 2>/dev/null)
        full_path=$(ps -p "$pid" -o command= 2>/dev/null | awk '{print $1}')
        if [ -n "$full_path" ] && [[ "$full_path" == /* ]] && [ ! -e "$full_path" ]; then
            warning "PID $pid running deleted binary: $full_path"
        fi
    done 2>/dev/null | head -10 | tee -a "$LOG_FILE"
}

# ============================================================================
# RESOURCE OPTIMIZATION SUGGESTIONS
# ============================================================================

audit_optimization() {
    header "OPTIMIZATION SUGGESTIONS"
    
    subheader "Browser processes"
    chrome_count=$(pgrep -f "Google Chrome" | wc -l | tr -d ' ')
    safari_count=$(pgrep -f "Safari" | wc -l | tr -d ' ')
    firefox_count=$(pgrep -f "Firefox" | wc -l | tr -d ' ')
    edge_count=$(pgrep -f "Microsoft Edge" | wc -l | tr -d ' ')
    
    browser_total=$((chrome_count + safari_count + firefox_count + edge_count))
    
    if [ "$chrome_count" -gt 0 ]; then
        chrome_mem=$(ps aux | grep -i "[G]oogle Chrome" | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
        info "Chrome: $chrome_count processes, ~${chrome_mem}MB RAM"
        if [ "$chrome_count" -gt 20 ]; then
            warning "Consider closing unused Chrome tabs ($chrome_count processes)"
        fi
    fi
    
    if [ "$safari_count" -gt 0 ]; then
        safari_mem=$(ps aux | grep -i "[S]afari" | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
        info "Safari: $safari_count processes, ~${safari_mem}MB RAM"
    fi
    
    subheader "Electron apps (memory heavy)"
    electron_apps=$(ps aux | grep -E "Electron|\.app/Contents/MacOS" | grep -v grep | awk '{print $11}' | xargs -I{} basename {} 2>/dev/null | sort | uniq -c | sort -rn | head -10)
    if [ -n "$electron_apps" ]; then
        echo "$electron_apps" | while read count app; do
            info "$app: $count processes"
        done | tee -a "$LOG_FILE"
    fi
    
    subheader "Helper processes that could be disabled"
    helpers=$(ps aux | grep -iE "helper|agent|updater|sync" | grep -v grep | awk '{print $11}' | xargs -I{} basename {} 2>/dev/null | sort | uniq -c | sort -rn | head -15)
    if [ -n "$helpers" ]; then
        echo "$helpers" | while read count helper; do
            info "$helper: $count"
        done | tee -a "$LOG_FILE"
    fi
    
    subheader "Idle apps consuming memory (>100MB, 0% CPU)"
    ps aux | awk '$3==0.0 && $6>102400 {printf "  %s (PID %s): %.0f MB - %s\n", $1, $2, $6/1024, $11}' | head -15 | while read line; do
        info "$line"
    done | tee -a "$LOG_FILE"
}

# ============================================================================
# DEV TOOLS STATUS
# ============================================================================

audit_dev_tools() {
    header "DEV TOOLS STATUS"
    
    subheader "Databases"
    
    # MongoDB
    mongo_pid=$(pgrep mongod 2>/dev/null)
    if [ -n "$mongo_pid" ]; then
        mongo_mem=$(ps -p "$mongo_pid" -o rss= 2>/dev/null | awk '{printf "%.0f", $1/1024}')
        mongo_cpu=$(ps -p "$mongo_pid" -o %cpu= 2>/dev/null)
        info "MongoDB: Running (PID $mongo_pid, ${mongo_mem}MB, ${mongo_cpu}% CPU)"
    else
        info "MongoDB: Not running"
    fi
    
    # PostgreSQL
    pg_pid=$(pgrep -f "postgres" | head -1 2>/dev/null)
    if [ -n "$pg_pid" ]; then
        pg_count=$(pgrep -f "postgres" | wc -l | tr -d ' ')
        pg_mem=$(ps aux | grep "[p]ostgres" | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
        info "PostgreSQL: Running ($pg_count processes, ${pg_mem}MB total)"
    else
        info "PostgreSQL: Not running"
    fi
    
    # Neo4j
    neo4j_pid=$(pgrep -f "neo4j" 2>/dev/null | head -1)
    if [ -n "$neo4j_pid" ]; then
        neo4j_mem=$(ps aux | grep "[n]eo4j" | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
        info "Neo4j: Running (${neo4j_mem}MB)"
    else
        info "Neo4j: Not running"
    fi
    
    # Redis
    redis_pid=$(pgrep redis-server 2>/dev/null)
    if [ -n "$redis_pid" ]; then
        redis_mem=$(ps -p "$redis_pid" -o rss= 2>/dev/null | awk '{printf "%.0f", $1/1024}')
        info "Redis: Running (PID $redis_pid, ${redis_mem}MB)"
    else
        info "Redis: Not running"
    fi
    
    subheader "Containers"
    
    # Docker
    docker_pid=$(pgrep -f "Docker Desktop" 2>/dev/null | head -1)
    if [ -n "$docker_pid" ]; then
        docker_mem=$(ps aux | grep -i "[d]ocker" | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
        container_count=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
        info "Docker: Running (${docker_mem}MB, $container_count containers)"
        
        if [ "$container_count" -eq 0 ]; then
            warning "Docker is running but no containers active - consider quitting to save resources"
        fi
    else
        info "Docker: Not running"
    fi
    
    subheader "AI/ML Tools"
    
    # Ollama
    ollama_pid=$(pgrep -f "ollama" 2>/dev/null | head -1)
    if [ -n "$ollama_pid" ]; then
        ollama_mem=$(ps aux | grep "[o]llama" | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
        info "Ollama: Running (${ollama_mem}MB)"
    else
        info "Ollama: Not running"
    fi
    
    # LM Studio
    lm_pid=$(pgrep -f "LM Studio" 2>/dev/null | head -1)
    if [ -n "$lm_pid" ]; then
        lm_mem=$(ps aux | grep "[L]M Studio" | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
        info "LM Studio: Running (${lm_mem}MB)"
    else
        info "LM Studio: Not running"
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

generate_summary() {
    header "SUMMARY & RECOMMENDATIONS"
    
    # Total process count
    total_procs=$(ps aux | wc -l | tr -d ' ')
    info "Total processes: $total_procs"
    
    # User process count
    user_procs=$(ps aux | grep -v "^root" | grep -v "^_" | wc -l | tr -d ' ')
    info "User processes: $user_procs"
    
    # Memory usage summary
    mem_used=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
    mem_wired=$(vm_stat | grep "Pages wired" | awk '{print $4}' | tr -d '.')
    if [ -n "$mem_used" ] && [ -n "$mem_wired" ]; then
        # Page size is typically 16384 on Apple Silicon, 4096 on Intel
        page_size=$(pagesize)
        active_gb=$(echo "scale=2; $mem_used * $page_size / 1024 / 1024 / 1024" | bc)
        wired_gb=$(echo "scale=2; $mem_wired * $page_size / 1024 / 1024 / 1024" | bc)
        info "Active memory: ${active_gb}GB, Wired: ${wired_gb}GB"
    fi
    
    echo ""
    log "${CYAN}Potential optimizations:${NC}"
    
    # Check browsers
    chrome_count=$(pgrep -f "Google Chrome" | wc -l | tr -d ' ')
    if [ "$chrome_count" -gt 15 ]; then
        warning "Close unused Chrome tabs ($chrome_count helper processes)"
    fi
    
    # Check Docker
    docker_running=$(pgrep -f "Docker Desktop" | wc -l | tr -d ' ')
    container_count=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    if [ "$docker_running" -gt 0 ] && [ "$container_count" -eq 0 ]; then
        warning "Docker running with no containers - quit to save ~2GB RAM"
    fi
    
    # Check idle databases
    mongo_pid=$(pgrep mongod 2>/dev/null)
    if [ -n "$mongo_pid" ]; then
        mongo_conns=$(lsof -i :27017 2>/dev/null | grep -c ESTABLISHED || echo "0")
        if [ "$mongo_conns" -eq 0 ]; then
            info "MongoDB has no active connections - stop if not needed: brew services stop mongodb-community"
        fi
    fi
    
    pg_pid=$(pgrep -f "postgres" | head -1 2>/dev/null)
    if [ -n "$pg_pid" ]; then
        pg_conns=$(lsof -i :5432 2>/dev/null | grep -c ESTABLISHED || echo "0")
        if [ "$pg_conns" -lt 2 ]; then
            info "PostgreSQL has few connections - stop if not needed: brew services stop postgresql@14"
        fi
    fi
    
    success "Audit complete. Log saved to: $LOG_FILE"
}

# ============================================================================
# MAIN
# ============================================================================

show_help() {
    cat << 'EOF'
Process Audit Script v1.0.0

USAGE:
  ./process_audit.sh [options]

OPTIONS:
  --log-dir <path>   Directory for log files (default: current directory)
  -h, --help         Show this help
  -v, --version      Show version

EXAMPLES:
  ./process_audit.sh                      # Run full audit
  ./process_audit.sh --log-dir ~/logs     # Custom log directory

EOF
}

main() {
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "process_audit.sh v${VERSION}"
                exit 0
                ;;
            --log-dir)
                LOG_DIR="$2"
                shift 2
                ;;
            --log-dir=*)
                LOG_DIR="${1#*=}"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    init_log
    
    log "Process Audit started at $(date)"
    log "Output will be saved to: $LOG_FILE"
    
    audit_system_overview
    audit_cpu_usage
    audit_memory_usage
    audit_long_running
    audit_suspicious
    audit_dev_tools
    audit_optimization
    generate_summary
}

main "$@"
