#!/usr/bin/env bash
set -euo pipefail

SELF=$(basename "$0")
ALL_MODE=false
if [[ "${1:-}" == "--all" ]]; then
  ALL_MODE=true
  if [[ $EUID -ne 0 ]]; then
    echo "⚠  --all mode requires root (profile switching)" >&2
    exit 1
  fi
fi

# ── helpers ──────────────────────────────────────────────────────────
die() { echo "✖ $*" >&2; exit 1; }
header() { printf '\n%s\n%s\n' "$1" "$(printf '%.0s─' $(seq 1 ${#1}))"; }
kv() { printf '  %-30s %s\n' "$1:" "${2:-}"; }

# ── probes ───────────────────────────────────────────────────────────
probe_smt() {
  local ctrl active
  ctrl=$(cat /sys/devices/system/cpu/smt/control 2>/dev/null || echo "N/A")
  active=$(cat /sys/devices/system/cpu/smt/active 2>/dev/null || echo "N/A")
  echo "ctrl=$ctrl active=$active"
}

probe_governor() {
  cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort -u | paste -sd,
}

probe_epp() {
  for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
    val=$(cat "$f" 2>/dev/null) || continue
    echo "$val"
  done | sort -u | paste -sd,
}

probe_capacities() {
  local p_vals e_vals
  p_vals=""; e_vals=""
  for cpu in /sys/devices/system/cpu/cpu*/cpu_capacity; do
    n=$(echo "$cpu" | grep -oP 'cpu\K\d+')
    val=$(cat "$cpu" 2>/dev/null || echo "?")
    if [[ $n -le 15 ]]; then
      p_vals="$p_vals cpu$n=$val"
    else
      e_vals="$e_vals cpu$n=$val"
    fi
  done
  echo "P-cores:${p_vals:- (none)}"
  echo "E-cores:${e_vals:- (none)}"
}

probe_eas_sysctl() {
  local val
  val=$(cat /proc/sys/kernel/sched_energy_aware 2>/dev/null || echo "")
  if [[ "$val" == "1" ]]; then echo "1 (active)"; else echo "0 (inactive / unavailable)"; fi
}

probe_em_klog() {
  local lines
  lines=$(journalctl -k --no-pager 2>/dev/null | grep -c 'energy_model: updating' || true)
  if [[ "$lines" -gt 0 ]]; then
    echo "yes ($lines updates logged)"
  else
    echo "no entries in current boot"
  fi
}

probe_online() {
  nproc
}

probe_driver() {
  cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo "N/A"
}

probe_freqs() {
  for f in /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq; do
    cat "$f" 2>/dev/null || true
  done | sort -u | paste -sd,
}

probe_asym_flag() {
  # Parse schedstat for domain flags — MC domain
  local mc_flags
  mc_flags=$(python3 -c "
import re
with open('/proc/schedstat') as f:
    for line in f:
        m = re.match(r'domain\d+\s+MC\s+([0-9a-fA-F]+)\s+(.*)', line)
        if m:
            fields = m.group(2).split()
            # flags field depends on kernel version — just report it exists
            print('span=0x' + m.group(1) + ' fields=' + str(len(fields)))
            break
" 2>/dev/null || echo "unparsable")
  echo "$mc_flags"

  # Check kernel log for asym detection
  local asym
  asym=$(journalctl -k --no-pager 2>/dev/null | grep -i 'asym_cpu_capacity' | tail -1 || true)
  if [[ -n "$asym" ]]; then echo "  kernel log: $asym"; fi
}

diagnose() {
  local label=$1
  header "📋 $label"
  kv "Profile"      "$(tuned-adm active 2>/dev/null | head -1 || echo 'N/A')"
kv "SMT"          "$(probe_smt)"
kv "Online CPUs"  "$(probe_online)"
kv "Driver"       "$(probe_driver)"
kv "Governor"     "$(probe_governor)"
kv "EPP"          "$(probe_epp)"
kv "Freq (max)"   "$(probe_freqs)"
echo ""
kv "EAS (sysctl)" "$(probe_eas_sysctl)"
kv "EM in klog"   "$(probe_em_klog)"
echo ""
echo "  Capacities:"
probe_capacities | sed 's/^/    /'
echo ""
echo "  Sched domain:"; probe_asym_flag | sed 's/^/    /'

  # Verdict
  local smt_state eas_state
  smt_state=$(cat /sys/devices/system/cpu/smt/active 2>/dev/null || echo "?")
  eas_state=$(cat /proc/sys/kernel/sched_energy_aware 2>/dev/null || echo "")
  local cap_vals
  cap_vals=$(for cpu in /sys/devices/system/cpu/cpu*/cpu_capacity; do cat "$cpu" 2>/dev/null; done | sort -u | paste -sd,)
  echo ""
  if [[ "$smt_state" == "0" && "$eas_state" == "1" ]]; then
    echo "  ⚡ VERDICT: EAS=ACTIVE, CAS=ACTIVE (SMT off, hybrid capacities)"
  elif [[ "$smt_state" == "0" && "$cap_vals" == *","* ]]; then
    echo "  ⚡ VERDICT: CAS=ACTIVE (asym capacities detected), EAS=uncertain"
  elif [[ "$smt_state" == "1" ]]; then
    echo "  ⚡ VERDICT: EAS=OFF, CAS=OFF (SMT active — capacities flat 1024)"
  else
    echo "  ⚡ VERDICT: Cannot determine (unexpected state)"
  fi
}

# ── main ─────────────────────────────────────────────────────────────
diagnose "Current State"

if $ALL_MODE; then
  for prof in balanced performance powersave-battery; do
    tuned-adm profile "$prof" >/dev/null 2>&1
    sleep 2
    diagnose "$prof"
  done

  # Restore balanced
  tuned-adm profile balanced >/dev/null 2>&1
  sleep 1

  header "✅ Done — restored to balanced"
else
  echo ""
  echo "💡 Run with --all (as root) to cycle through all 3 profiles:"
  echo "   sudo $SELF --all"
fi
