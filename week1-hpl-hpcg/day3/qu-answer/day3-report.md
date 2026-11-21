# Day 3：HPL 单变量实验汇总

实验日期：2026-11-21（UTC+08:00）  
平台：本地单节点 WSL2，AMD Ryzen 5 9600X（6 个物理核、12 个逻辑处理器）。此结果仅用于本地学习和筛选。

## 数据与固定条件

本报告根据队员提供的 [完整运行记录](day3-runs.csv) 整理，共 17 次运行，CSV 中的 `valid` 全部为 `PASSED`。每次运行的原始输入和日志应保留在 WSL2 的 `~/asc-week1/results/day3/HPL_*` 目录，包含 `HPL.dat`、`parameters.txt`、`stdout.log` 和 `stderr.log`。当前报告未直接读取这些原始目录，CSV 与日志的一致性尚待归档时核对。

所有 CSV 行均记录：单节点、4 个 MPI ranks、每 rank 1 个线程。单变量实验中固定 `N`、`NB` 或 `P×Q` 中的另外两项。Day 2 环境记录中的 HPL 二进制为 `/home/rugers/asc-week1/src/hpl-2.3/bin/Linux_PII_CBLAS/xhpl`，SHA256 为 `dd7b2f3bf854eaf50bddf077829a163f85399f9576e3dbfa5d48634fb5a37ddd`；其动态链接记录显示 OpenBLAS 与 Open MPI。Day 3 每次使用的二进制身份仍需对照 `parameters.txt` 和重新计算的 SHA256 确认。

计划采用的线程和绑定设置是 `OMP_NUM_THREADS=1`、`OPENBLAS_NUM_THREADS=1`、`BLIS_NUM_THREADS=1`、`MKL_NUM_THREADS=1`、`OMPI_MCA_hwloc_base_binding_policy=core`、`OMPI_MCA_rmaps_base_mapping_policy=slot`。CSV 不包含实际绑核信息，因此不能仅凭 CSV 证明这 17 次运行的绑核设置一致；归档时应检查运行命令、环境设置及 `parameters.txt`。如无法核实，应在正式报告中将绑定标为“未确认”。

`runtime_s` 是 HPL 报告中的计算时间；`elapsed_s` 是脚本测得的整次运行时间。以下性能比较使用 `gflops`，均值只对相应实验组中的“初筛＋复跑”两次求平均，不混合其他组的相同参数记录。

## 结果

### N：固定 NB=192、P×Q=2×2

| N | 初筛 GFLOPS | 复跑 GFLOPS | 两次均值 GFLOPS | 验证 |
|---:|---:|---:|---:|---|
| 7680 | 217.55 | — | — | PASSED |
| 9600 | 259.49 | 245.62 | 252.56 | 两次均 PASSED |
| 11520 | 261.31 | 247.97 | 254.64 | 两次均 PASSED |

`N=11520` 的两次均值比 `N=9600` 高约 0.8%，差距小于这两项各自的复跑波动。`N=7680` 的单次结果较低。当前数据支持“增大规模至 9600 后性能提高”，尚不足以确认 11520 稳定优于 9600。

### NB：固定 N=11520、P×Q=2×2

| NB | 初筛 GFLOPS | 复跑 GFLOPS | 两次均值 GFLOPS | 验证 |
|---:|---:|---:|---:|---|
| 128 | 223.09 | — | — | PASSED |
| 192 | 271.83 | 264.62 | 268.23 | 两次均 PASSED |
| 256 | 260.78 | 268.34 | 264.56 | 两次均 PASSED |
| 384 | 250.82 | — | — | PASSED |

`NB=192` 的两次均值比 256 高约 1.4%，但差距小于重复测量的波动；不能断言它稳定更快。`NB=128` 初筛明显较低，可能与更频繁的面板处理和同步有关；该解释仍需更长时间的测量支持。

### P×Q：固定 N=11520、NB=192

| P×Q | 初筛 GFLOPS | 复跑 GFLOPS | 两次均值 GFLOPS | 验证 |
|---:|---:|---:|---:|---|
| 1×4 | 265.28 | 275.61 | 270.45 | 两次均 PASSED |
| 2×2 | 250.15 | 255.13 | 252.64 | 两次均 PASSED |
| 4×1 | 235.12 | — | — | PASSED |

`1×4` 在两轮中均高于 `2×2`，两次均值高约 7.0%。进程网格形状会改变二维数据分布和面板通信；本轮没有通信分项计时，不能把差异归因于某个具体通信操作。`4×1` 仅测过一次。

## 波动与结论

相同参数 `N=11520、NB=192、P×Q=2×2、4 ranks、1 thread` 在所有组中共出现 7 次，GFLOPS 范围为 **247.97–271.83**，跨度 23.86 GFLOPS。多数求解仅持续约 4 秒，系统负载、频率和 WSL2 调度都可能影响短测。因此本报告将结果用于候选筛选，不将单次最高值作为正式成绩。

Day 3 入围配置：**HPL 2.3；N=11520，NB=192，P=1，Q=4，ranks=4，threads=1**。该配置两次结果分别为 **265.28** 和 **275.61 GFLOPS**，均为 `PASSED`。这是当前 WSL2 平台的候选；Day 5 应在相同环境和绑定条件下至少复跑两次，再报告绝对成绩、波动与验证结果。

## Day 5 复跑命令

在 WSL2 Bash 中执行，先核对实际可执行文件和环境；若 Day 3 的二进制 SHA256 与下方结果不同，先查明差异，不要把不同二进制混入同一对照。

```bash
export WEEK1="$HOME/asc-week1/week1-hpl-hpcg"
export HPL_BIN="$HOME/asc-week1/src/hpl-2.3/bin/Linux_PII_CBLAS/xhpl"
export OUT_ROOT="$HOME/asc-week1/results/day5-hpl"
export THREADS=1
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export BLIS_NUM_THREADS=1 MKL_NUM_THREADS=1
export OMPI_MCA_hwloc_base_binding_policy=core
export OMPI_MCA_rmaps_base_mapping_policy=slot
mkdir -p "$OUT_ROOT"
test -x "$HPL_BIN" || { echo 'HPL_BIN 不可执行'; exit 1; }
sha256sum "$HPL_BIN"
free -h
"$WEEK1/collect_env.sh" "$OUT_ROOT/environment.txt"

"$WEEK1/run_hpl.sh" 4 1 4 11520 192
"$WEEK1/run_hpl.sh" 4 1 4 11520 192
```

两次运行会自动生成不同的 `HPL_*` 目录。逐个检查 `parameters.txt` 中 `exit_code=0`，`stdout.log` 中有 `PASSED`，再提取以 `WR` 开头的性能行。也要确认没有明显换页或 OOM。

```bash
for d in "$OUT_ROOT"/HPL_*; do
  echo "===== $d ====="
  cat "$d/parameters.txt"
  grep -E '^WR[0-9A-Z]+|PASSED|FAILED' "$d/stdout.log" || true
  cat "$d/stderr.log"
done
```

## Day 3 原始文件归档命令

如果准备把 WSL2 的原始运行目录一并提交到 Windows 项目中，在 WSL2 Bash 中执行：

```bash
export OUT_ROOT="$HOME/asc-week1/results/day3"
export DAY3_REPO="/mnt/d/c/ASC/week1-hpl-hpcg/day3"
mkdir -p "$DAY3_REPO/runs"
cp -an "$OUT_ROOT"/HPL_* "$DAY3_REPO/runs/"
cp -an "$OUT_ROOT"/*_launcher.log "$DAY3_REPO/" 2>/dev/null || true

for d in "$DAY3_REPO"/runs/HPL_*; do
  for f in HPL.dat parameters.txt stdout.log stderr.log; do
    test -f "$d/$f" || echo "缺少：$d/$f"
  done
done
```

归档前确认 Windows 路径映射确实是上述 `/mnt/d/...`，且 `OUT_ROOT` 包含这 17 个运行目录。失败案例也应保留；当前提供的 CSV 没有失败记录。
