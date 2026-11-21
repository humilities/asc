# Day 3 指导文档：HPL 单变量实验

适用范围：本地单节点 WSL2 CPU 实验。本文结合项目 `README.md` 的第 3 天要求、Day 2 基线以及你已完成的 17 次 Day 3 记录整理。**你已经完成三组初筛和入围项复跑，无须为满足 Day 3 验收而重新跑一遍。** 当前最重要的是核对原始日志、归档数据并准确表述结论。

## 1. 目标与验收

HPL 的三个主要输入是矩阵阶数 `N`、分块大小 `NB` 和 MPI 进程网格 `P×Q`。Day 3 分三组依次改变它们，每组只改变一个变量，并始终满足 `P×Q=ranks`。每次保留输入、命令、计算时间、GFLOPS、退出码和残差验证结果。每组先筛选候选，再将前两名各复跑至少一次。

完成标志：有可复查的单变量对照表；入围配置通过 `PASSED`；能解释可能的计算、缓存、内存或通信影响，同时说明短测的波动和解释边界。

## 2. 这台机器的起点

| 项目 | 本次实验的设置或记录 |
|---|---|
| 平台 | WSL2，本地单节点，AMD Ryzen 5 9600X，6 个物理核、12 个逻辑处理器 |
| Day 2 基线 | `N=11520, NB=192, P×Q=2×2, ranks=4, threads=1` |
| Day 2 基线成绩 | 261.27 GFLOPS、3.90 s、`PASSED`（Day 2 原始 `stdout.log`） |
| Day 2 HPL 二进制 | `/home/rugers/asc-week1/src/hpl-2.3/bin/Linux_PII_CBLAS/xhpl` |
| Day 2 二进制 SHA256 | `dd7b2f3bf854eaf50bddf077829a163f85399f9576e3dbfa5d48634fb5a37ddd` |
| Day 2 动态库 | 环境记录显示 Open MPI、OpenBLAS |
| Day 3 记录 | 17 次运行，CSV 中 17 次均为 `PASSED` |

Day 2 的二进制和库信息是当时的环境快照。Day 3 的 CSV 没有二进制哈希，也没有实际绑核证据；归档时应再对照每次的 `parameters.txt`、运行环境和当前 `sha256sum`。不要把“计划固定”写成“已验证固定”。

## 3. 实验前准备：从零复现时使用

先从 PowerShell 输入 `wsl`，以下代码均在 **WSL2 Bash** 中执行。若只是整理你已经完成的结果，可以跳到第 6 节。

```bash
export WEEK1="$HOME/asc-week1/week1-hpl-hpcg"
export HPL_BIN="$HOME/asc-week1/src/hpl-2.3/bin/Linux_PII_CBLAS/xhpl"
export OUT_ROOT="$HOME/asc-week1/results/day3"
export THREADS=1

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export BLIS_NUM_THREADS=1 MKL_NUM_THREADS=1
export OMPI_MCA_hwloc_base_binding_policy=core
export OMPI_MCA_rmaps_base_mapping_policy=slot

mkdir -p "$OUT_ROOT"
chmod +x "$WEEK1"/*.sh
test -x "$HPL_BIN" && sha256sum "$HPL_BIN"
ldd "$HPL_BIN" | grep -E 'mpi|openblas|not found'
free -h
```

核对 SHA256、`ldd` 和可用内存。`N=11520` 的矩阵本身约占 `8×11520² = 1,061,683,200` 字节，即约 **0.99 GiB**；HPL、MPI、BLAS 和操作系统还需要额外空间。不得让交换分区参与计算。若测试期间 `vmstat 1` 中 `si/so` 持续非零，或出现 OOM、异常变慢，应降低 `N` 并保留失败记录。

上述 Open MPI 变量指定拟使用的映射与绑定策略。要在新实验中记录实际绑定，可在相同环境下另行运行 `mpirun --report-bindings -np 4 hostname 2>&1 | tee "$OUT_ROOT/binding-check.txt"`，确认 4 个 rank 的绑定符合预期。这个检查不能追溯证明已经完成的旧运行。

## 4. 三组单变量实验：从零复现时使用

`run_hpl.sh` 的参数顺序是 `RANKS P Q N NB`。脚本会在 `OUT_ROOT` 下自动建立不同的 `HPL_*` 目录，保存 `HPL.dat`、`parameters.txt`、`stdout.log`、`stderr.log`。**已经完成的 17 次无需重跑**；下列命令供队友独立复现或换平台后重做。

### A. 只改变 N

固定 `ranks=4, threads=1, P×Q=2×2, NB=192`：

```bash
"$WEEK1/run_hpl.sh" 4 2 2  7680 192
"$WEEK1/run_hpl.sh" 4 2 2  9600 192
"$WEEK1/run_hpl.sh" 4 2 2 11520 192
```

这三个 `N` 都能被 192 整除。`N` 增加时，计算量大约按 `N³` 增长；较大规模可能提高计算密集型 BLAS 操作的占比，也会增加内存和运行时间。不能把不同 `N` 的 GFLOPS 差异当作纯并行扩展效率。

### B. 只改变 NB

固定 `N=11520, ranks=4, threads=1, P×Q=2×2`：

```bash
"$WEEK1/run_hpl.sh" 4 2 2 11520 128
"$WEEK1/run_hpl.sh" 4 2 2 11520 192
"$WEEK1/run_hpl.sh" 4 2 2 11520 256
"$WEEK1/run_hpl.sh" 4 2 2 11520 384
```

较小的 `NB` 可能增加面板数和同步次数；较大的 `NB` 有利于较大块的 BLAS-3 运算，但也可能增加缓存压力或降低并行度。这里保持同一 HPL 二进制与数学库，不能同时更换 OpenBLAS/BLIS。

### C. 只改变 P×Q

固定 `N=11520, NB=192, ranks=4, threads=1`：

```bash
"$WEEK1/run_hpl.sh" 4 1 4 11520 192
"$WEEK1/run_hpl.sh" 4 2 2 11520 192
"$WEEK1/run_hpl.sh" 4 4 1 11520 192
```

进程网格形状会改变矩阵块分布和行列通信。观察到性能差异后，可以提出这个机制作为可能解释；若没有通信分项计时，就不能断言某个具体通信步骤是原因。

## 5. 每次运行怎样读结果

脚本打印 `Run directory: ...`。对该目录逐项检查，尤其不能只凭高 GFLOPS 判断成功：

```bash
RUN_DIR="脚本刚打印的完整运行目录"
cat "$RUN_DIR/parameters.txt"              # 必须有 exit_code=0
grep -E '^WR[0-9A-Z]+|PASSED|FAILED' "$RUN_DIR/stdout.log"
cat "$RUN_DIR/stderr.log"
test -f "$RUN_DIR/HPL.dat" && echo 'HPL.dat 已保存'
```

`WR...` 行中的列依次是变体、`N`、`NB`、`P`、`Q`、`Time`、`Gflops`。`Time` 是 HPL 求解时间，CSV 中对应 `runtime_s`；`elapsed_s` 是脚本测得的整次运行耗时。只有 `exit_code=0` 且残差检查为 `PASSED` 才算有效结果。每次都记录运行目录名、时间、`N/NB/P/Q/ranks/threads` 和验证状态。失败运行的输入、stdout 与 stderr 同样要保留。

## 6. 你已经得到的 Day 3 结果

完整的逐次记录见 [day3-runs.csv](day3-runs.csv)。下面的两次均值只由对应实验组的初筛与复跑计算，未将其他组中相同参数的运行混入。

### N 组：固定 NB=192、P×Q=2×2

| N | 初筛 GFLOPS | 复跑 GFLOPS | 两次均值 GFLOPS | 验证 |
|---:|---:|---:|---:|---|
| 7680 | 217.55 | — | — | PASSED |
| 9600 | 259.49 | 245.62 | 252.56 | 两次均 PASSED |
| 11520 | 261.31 | 247.97 | 254.64 | 两次均 PASSED |

`N=9600` 和 11520 的两次均值只差约 **0.8%**，不足以证明 11520 稳定更快。7680 的单次结果较低。

### NB 组：固定 N=11520、P×Q=2×2

| NB | 初筛 GFLOPS | 复跑 GFLOPS | 两次均值 GFLOPS | 验证 |
|---:|---:|---:|---:|---|
| 128 | 223.09 | — | — | PASSED |
| 192 | 271.83 | 264.62 | 268.23 | 两次均 PASSED |
| 256 | 260.78 | 268.34 | 264.56 | 两次均 PASSED |
| 384 | 250.82 | — | — | PASSED |

`NB=192` 的均值比 256 高约 **1.4%**，也不足以确认稳定优势。`NB=128` 初筛较低，但只测过一次。

### P×Q 组：固定 N=11520、NB=192

| P×Q | 初筛 GFLOPS | 复跑 GFLOPS | 两次均值 GFLOPS | 验证 |
|---:|---:|---:|---:|---|
| 1×4 | 265.28 | 275.61 | 270.45 | 两次均 PASSED |
| 2×2 | 250.15 | 255.13 | 252.64 | 两次均 PASSED |
| 4×1 | 235.12 | — | — | PASSED |

`1×4` 在该组两轮中都高于 `2×2`，均值约高 **7.0%**。这支持把 `1×4` 选作后续复现候选；单节点短测仍需在 Day 5 验证。

### 波动与结论边界

完全相同的 `N=11520, NB=192, P×Q=2×2, ranks=4, threads=1` 在全部 17 条记录中出现 7 次，GFLOPS 为 **247.97–271.83**，跨度 **23.86**。单次求解约 4 秒，系统负载、频率和 WSL2 调度可能影响成绩。`N` 和 `NB` 的两次均值差异均小于已经观察到的波动；报告中应写“尚不能确认稳定优劣”，不要把单次峰值当正式成绩。

## 7. 入围配置与下一步

**Day 3 入围配置：`N=11520, NB=192, P=1, Q=4, ranks=4, threads=1`。** 该配置两次结果是 265.28 和 275.61 GFLOPS，均为 `PASSED`。这是当前 WSL2 机器上的筛选结果，不代表比赛服务器成绩。

Day 3 现在应完成的工作：

1. 对照原始目录，确认 17 个 `run_id` 各有 `HPL.dat`、`parameters.txt`、`stdout.log`、`stderr.log`；逐个核对 `exit_code=0`、`PASSED` 和 `WR` 性能行与 CSV 一致。
2. 核对 Day 3 使用的 HPL 二进制路径、SHA256、MPI/OpenBLAS 版本，以及实际绑核设置。未留下证据的项目在报告中写“未确认”。
3. 将完整 CSV、原始运行目录和 [Day 3 汇总报告](day3-report.md) 归档。不要覆盖失败日志或删除初筛结果。

若 WSL2 项目映射确实是 `/mnt/d/c/ASC/week1-hpl-hpcg`，可在 WSL2 Bash 中把原始运行目录复制到项目的 `day3/runs/`：

```bash
export OUT_ROOT="$HOME/asc-week1/results/day3"
export DAY3_REPO="/mnt/d/c/ASC/week1-hpl-hpcg/day3"
test -d "$OUT_ROOT" && test -d "$DAY3_REPO"
mkdir -p "$DAY3_REPO/runs"
cp -an "$OUT_ROOT"/HPL_* "$DAY3_REPO/runs/"

for d in "$DAY3_REPO"/runs/HPL_*; do
  for f in HPL.dat parameters.txt stdout.log stderr.log; do
    test -f "$d/$f" || echo "缺少：$d/$f"
  done
done
```

确认源目录确实包含这 17 个运行目录后再归档。上面的 `cp -an` 保留已有文件、不覆盖同名目录。CSV 和汇总报告已经生成；原始日志尚需在你的 WSL2 中执行核对与复制。

## 8. Day 5 对入围项复跑

Day 5 在相同平台、软件栈、线程和绑定条件下至少做两次独立运行。以下仍是 **WSL2 Bash** 命令：

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

test -x "$HPL_BIN" && sha256sum "$HPL_BIN"
free -h
"$WEEK1/collect_env.sh" "$OUT_ROOT/environment.txt"
"$WEEK1/run_hpl.sh" 4 1 4 11520 192
"$WEEK1/run_hpl.sh" 4 1 4 11520 192
```

在两次新生成的 `HPL_*` 目录中分别检查 `exit_code=0`、`PASSED`、`WR` 性能行，并记录两次 GFLOPS 和波动。若 SHA256、MPI、BLAS 或机器环境与 Day 3 不同，应另列为新环境结果。
