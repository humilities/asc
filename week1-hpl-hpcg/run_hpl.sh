#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 5 ]]; then
  echo "Usage: HPL_BIN=/abs/xhpl OUT_ROOT=/abs/results $0 RANKS P Q N NB" >&2; exit 2
fi
ranks=$1; p=$2; q=$3; n=$4; nb=$5
for value in "$ranks" "$p" "$q" "$n" "$nb"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo 'All inputs must be positive integers' >&2; exit 2; }
done
(( p * q == ranks )) || { echo 'P * Q must equal RANKS' >&2; exit 2; }
[[ -x "${HPL_BIN:-}" ]] || { echo 'Set HPL_BIN to an executable xhpl' >&2; exit 2; }
[[ "$HPL_BIN" = /* ]] || { echo 'HPL_BIN must be an absolute Linux path' >&2; exit 2; }
launcher=${LAUNCHER:-mpirun}
case "$launcher" in mpirun|srun) command -v "$launcher" >/dev/null || { echo "Missing launcher: $launcher" >&2; exit 2; } ;; *) echo 'LAUNCHER must be mpirun or srun' >&2; exit 2 ;; esac
out_root=${OUT_ROOT:-$PWD/week1-results}
mkdir -p "$out_root"
out_root=$(cd "$out_root" && pwd -P)
run_dir=$(mktemp -d "$out_root/HPL_$(date +%Y%m%d_%H%M%S)_XXXXXX")
threads=${THREADS:-1}
[[ "$threads" =~ ^[1-9][0-9]*$ ]] || { echo 'THREADS must be positive' >&2; exit 2; }
export OMP_NUM_THREADS=$threads OPENBLAS_NUM_THREADS=$threads BLIS_NUM_THREADS=$threads MKL_NUM_THREADS=$threads
cat >"$run_dir/HPL.dat" <<EOF
HPLinpack benchmark input file
Output in HPL.out
HPL.out
6
1
$n
1
$nb
0
1
$p
$q
16.0
1
2
1
4
1
2
1
2
1
1
1
1
1
64
0
0
1
8
EOF
if ! awk 'NR==10 {grids=$1} NR==11 {p=$1} NR==12 {q=$1} NR==18 {nrec=$1} NR==19 {ndiv=$1} END {exit !(NR==31 && grids==1 && p>0 && q>0 && nrec==1 && ndiv>=2)}' "$run_dir/HPL.dat"; then
  echo 'Generated HPL.dat failed the P/Q or NDIV field check; see numbered file:' >&2
  nl -ba "$run_dir/HPL.dat" >&2
  exit 2
fi
printf 'RANKS=%s P=%s Q=%s N=%s NB=%s THREADS=%s LAUNCHER=%s\n' "$ranks" "$p" "$q" "$n" "$nb" "$threads" "$launcher" >"$run_dir/parameters.txt"
printf 'HPL_BIN=%s\n' "$HPL_BIN" >>"$run_dir/parameters.txt"
printf 'Run directory: %s\n' "$run_dir"
cd "$run_dir"
start=$(date +%s)
set +e
if [[ "$launcher" == srun ]]; then
  srun --ntasks="$ranks" "$HPL_BIN" >stdout.log 2>stderr.log
else
  mpirun -np "$ranks" "$HPL_BIN" >stdout.log 2>stderr.log
fi
status=$?
set -e
printf 'exit_code=%s\nelapsed_wall_s=%s\n' "$status" "$(( $(date +%s) - start ))" >>parameters.txt
echo "Exit: $status; inspect $run_dir/stdout.log and HPL.out for PASSED and GFLOPS"
exit "$status"
