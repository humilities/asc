#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 5 ]]; then
  echo "Usage: HPCG_BIN=/abs/xhpcg OUT_ROOT=/abs/results $0 RANKS NX NY NZ SECONDS" >&2; exit 2
fi
ranks=$1; nx=$2; ny=$3; nz=$4; seconds=$5
for value in "$ranks" "$nx" "$ny" "$nz" "$seconds"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo 'All inputs must be positive integers' >&2; exit 2; }
done
(( nx >= 16 && ny >= 16 && nz >= 16 )) || { echo 'Each local dimension must be at least 16' >&2; exit 2; }
[[ -x "${HPCG_BIN:-}" ]] || { echo 'Set HPCG_BIN to an executable xhpcg' >&2; exit 2; }
[[ "$HPCG_BIN" = /* ]] || { echo 'HPCG_BIN must be an absolute Linux path' >&2; exit 2; }
launcher=${LAUNCHER:-mpirun}
case "$launcher" in mpirun|srun) command -v "$launcher" >/dev/null || { echo "Missing launcher: $launcher" >&2; exit 2; } ;; *) echo 'LAUNCHER must be mpirun or srun' >&2; exit 2 ;; esac
out_root=${OUT_ROOT:-$PWD/week1-results}
mkdir -p "$out_root"
out_root=$(cd "$out_root" && pwd -P)
run_dir=$(mktemp -d "$out_root/HPCG_$(date +%Y%m%d_%H%M%S)_XXXXXX")
threads=${THREADS:-1}
[[ "$threads" =~ ^[1-9][0-9]*$ ]] || { echo 'THREADS must be positive' >&2; exit 2; }
export OMP_NUM_THREADS=$threads OPENBLAS_NUM_THREADS=$threads BLIS_NUM_THREADS=$threads MKL_NUM_THREADS=$threads
cat >"$run_dir/hpcg.dat" <<EOF
HPCG benchmark input file
HPCG benchmark input file
$nx $ny $nz
$seconds
EOF
printf 'RANKS=%s NX=%s NY=%s NZ=%s SECONDS=%s THREADS=%s LAUNCHER=%s\n' "$ranks" "$nx" "$ny" "$nz" "$seconds" "$threads" "$launcher" >"$run_dir/parameters.txt"
printf 'HPCG_BIN=%s\n' "$HPCG_BIN" >>"$run_dir/parameters.txt"
printf 'Run directory: %s\n' "$run_dir"
cd "$run_dir"
start=$(date +%s)
set +e
if [[ "$launcher" == srun ]]; then
  srun --ntasks="$ranks" "$HPCG_BIN" >stdout.log 2>stderr.log
else
  mpirun -np "$ranks" "$HPCG_BIN" >stdout.log 2>stderr.log
fi
status=$?
set -e
printf 'exit_code=%s\nelapsed_wall_s=%s\n' "$status" "$(( $(date +%s) - start ))" >>parameters.txt
echo "Exit: $status; inspect $run_dir/HPCG-Benchmark_*.txt (or the report format your version writes) for validity and GFLOP/s"
exit "$status"
