#!/usr/bin/env bash
set -euo pipefail
out=${1:-environment.txt}
mkdir -p "$(dirname "$out")"
{
  printf 'Timestamp: '; date -Is
  printf 'Host: '; hostname
  printf 'Working directory: %s\n' "$PWD"
  printf 'Job ID: %s\n' "${SLURM_JOB_ID:-none}"
  printf 'HPL_BIN: %s\nHPCG_BIN: %s\n' "${HPL_BIN:-unset}" "${HPCG_BIN:-unset}"
  for cmd in uname lscpu free numactl mpirun mpicc gcc g++ gfortran clang nvidia-smi rocminfo; do
    printf '\n===== %s =====\n' "$cmd"
    if ! command -v "$cmd" >/dev/null 2>&1; then printf 'unavailable\n'; continue; fi
    case "$cmd" in
      uname) uname -a ;;
      lscpu) lscpu ;;
      free) free -h ;;
      numactl) numactl --hardware ;;
      mpirun|mpicc|gcc|g++|gfortran|clang) "$cmd" --version 2>&1 | head -n 3 || true ;;
      nvidia-smi) nvidia-smi -L ;;
      rocminfo) rocminfo 2>&1 | head -n 45 || true ;;
    esac
  done
  if command -v module >/dev/null 2>&1; then printf '\n===== modules =====\n'; module list 2>&1 || true; fi
  for bin in "${HPL_BIN:-}" "${HPCG_BIN:-}"; do
    [[ -n "$bin" ]] || continue
    printf '\n===== %s =====\n' "$bin"
    if [[ -x "$bin" ]]; then
      command -v sha256sum >/dev/null && sha256sum "$bin"
      command -v ldd >/dev/null && ldd "$bin" || true
    else printf 'missing or not executable\n'; fi
  done
} >"$out" 2>&1
printf 'Saved %s\n' "$out"
