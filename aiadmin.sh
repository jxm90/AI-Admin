#!/bin/bash

# AI Admin - AI-powered Linux diagnostic assistant
# Requires: shell-gpt (sgpt)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Ask for sudo password up front
echo -e "${YELLOW}This tool requires root privileges for some diagnostics.${NC}"
sudo -v || { echo -e "${RED}Sudo access is required. Exiting.${NC}"; exit 1; }

# Keep sudo alive while script runs
(sudo -v; while true; do sleep 60; sudo -n true; done) 2>/dev/null &
SUDO_PID=$!

# Temp file for logs
TMP_LOG=$(mktemp /tmp/aiadmin_logs.XXXXXX)

# Welcome message
echo -e "${YELLOW}==================================="
echo -e "       🧠 Welcome to AI Admin"
echo -e "  AI-powered Linux Diagnostic Tool"
echo -e "===================================${NC}"

# Menu
while true; do
  echo ""
  echo "Choose an option:"
  echo "1) Analyze Kernel Panic"
  echo "2) Diagnose High CPU Usage"
  echo "3) Investigate Disk I/O Bottlenecks"
  echo "4) Check for Memory Issues"
  echo "5) Scan for Network Problems"
  echo "6) Analyze Boot Failures"
  echo "7) Review Systemd Service Failures"
  echo "8) Inspect Authentication or SSH Issues"
  echo "9) Look for Crashes or Segfaults"
  echo "10) Custom Log Analysis"
  echo "11) Ask a Follow-up Question to AI"
  echo "0) Exit"
  read -rp "Enter choice [0-11]: " choice

  case $choice in
    1)
      echo -e "${GREEN}Collecting logs for Kernel Panic analysis...${NC}"
      {
        echo "===== dmesg (tail) ====="
        sudo dmesg | tail -n 100
        echo
        echo "===== journalctl -k ====="
        sudo journalctl -k -n 100 --no-pager
        echo
        echo "===== /var/log/syslog ====="
        [[ -f /var/log/syslog ]] && sudo tail -n 100 /var/log/syslog
        echo
        echo "===== /var/log/kern.log ====="
        [[ -f /var/log/kern.log ]] && sudo tail -n 100 /var/log/kern.log
      } > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Analyze these Linux logs for a potential kernel panic. What are the signs and possible root causes?"
      ;;
    2)
      echo -e "${GREEN}Collecting top and journal logs for CPU usage...${NC}"
      {
        echo "===== top -bn1 ====="
        top -bn1
        echo
        echo "===== journalctl -xe ====="
        sudo journalctl -xe -n 50 --no-pager
      } > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Analyze these logs for possible causes of high CPU usage on a Linux server."
      ;;
    3)
      echo -e "${GREEN}Checking disk I/O and latency...${NC}"
      {
        echo "===== iostat ====="
        iostat -xz 1 3
        echo
        echo "===== dmesg (disk-related) ====="
        sudo dmesg | grep -iE 'error|fail|sda|nvme|disk'
      } > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Analyze this output for disk I/O issues or hardware faults."
      ;;
    4)
      echo -e "${GREEN}Checking memory usage and errors...${NC}"
      {
        echo "===== free -m ====="
        free -m
        echo
        echo "===== vmstat ====="
        vmstat 1 5
        echo
        echo "===== dmesg (memory) ====="
        sudo dmesg | grep -iE 'oom|memory|swap'
      } > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Is there a memory leak or OOM issue based on this data?"
      ;;
    5)
      echo -e "${GREEN}Collecting network diagnostics...${NC}"
      {
        echo "===== ip a ====="
        ip a
        echo
        echo "===== ss -tulnp ====="
        ss -tulnp
        echo
        echo "===== ping test ====="
        ping -c 4 8.8.8.8
        echo
        echo "===== dmesg (net) ====="
        sudo dmesg | grep -iE 'eth|net|link|fail'
      } > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Diagnose potential network issues based on this Linux network status report."
      ;;
    6)
      echo -e "${GREEN}Gathering boot logs...${NC}"
      sudo journalctl -b -1 > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Analyze the last boot journal logs for signs of failure or long delays."
      ;;
    7)
      echo -e "${GREEN}Reviewing failed services...${NC}"
      sudo systemctl --failed > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Explain why these systemd services may have failed and how to resolve them."
      ;;
    8)
      echo -e "${GREEN}Inspecting SSH and login attempts...${NC}"
      {
        echo "===== /var/log/auth.log ====="
        [[ -f /var/log/auth.log ]] && sudo tail -n 100 /var/log/auth.log
      } > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Analyze these SSH login logs and auth attempts for anomalies or brute-force attacks."
      ;;
    9)
      echo -e "${GREEN}Looking for crashes and segfaults...${NC}"
      {
        echo "===== dmesg ====="
        sudo dmesg | grep -iE 'segfault|trap|core dumped'
        echo
        echo "===== journalctl ====="
        sudo journalctl -xe | grep -iE 'segfault|crash'
      } > "$TMP_LOG"
      cat "$TMP_LOG" | sgpt --chat ai-admin "Help analyze these logs for application crashes or segmentation faults."
      ;;
    10)
      echo -e "${GREEN}Custom analysis: paste or load any logs...${NC}"
      read -rp "Paste the full path to a log file: " LOG_PATH
      if [[ -f $LOG_PATH ]]; then
        sudo cat "$LOG_PATH" | sgpt --chat ai-admin "Analyze this custom log file and explain any warnings, errors, or patterns you see."
      else
        echo -e "${RED}Log file not found.${NC}"
      fi
      ;;
    11)
      echo -e "${YELLOW}Follow-up mode activated. Your last analysis context is preserved.${NC}"
      read -rp "Enter your follow-up question: " followup
      sgpt --chat ai-admin "$followup"
      ;;
    0)
      echo -e "${YELLOW}Exiting AI Admin. Your conversation history will remain in this session."
      echo -e "Use option 11 anytime to follow up!${NC}"
      rm -f "$TMP_LOG"
      kill $SUDO_PID 2>/dev/null
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option. Try again.${NC}"
      ;;
  esac
done
