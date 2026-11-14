# 第 2 天交付物：正确基线

对应 `README.md` 第 2 天（第 55–66 行）。执行日期 2026-11-13，环境、源码版本与二进制指纹见 [`../day1/environment.txt`](../day1/environment.txt) 与 [`../day1/README.md`](../day1/README.md)。

## 1. 交付文件

| 目录 | 文件 | 说明 |
|---|---|---|
| `HPL_run1/` | `HPL.dat`、`stdout.log`、`stderr.log`、`parameters.txt` | 第 1 次 4 rank HPL 基线的原始输入与输出 |
| `HPL_run2/` | 同上 | 第 2 次，用于确认波动 |
| `HPCG_run1/` | `hpcg.dat`、`HPCG-Benchmark_*.txt`、`hpcg20261113T181649.txt`、`stdout.log`、`stderr.log`、`parameters.txt` | 第 1 次 4 rank HPCG 基线 |
| `HPCG_run2/` | 同上（`hpcg20261113T181758.txt`） | 第 2 次 |

说明：

- HPCG 3.1 把正式结果写进 `HPCG-Benchmark_*.txt`，**`stdout.log` / `stderr.log` 为 0 字节是正常的**，不是执行失败（`parameters.txt` 里 `exit_code=0`）。
- `hpcg_*.txt` 是 HPCG 自身写出的数值校验日志，含 `Departure from symmetry`、`SpMV call [...] Residual` 等行，用于证明矩阵与预条件器的对称性检查通过。
- 原始运行目录在 WSL 的 `~/asc-week1/results/` 下，名称见下表 `run_id` 列；本目录是逐字的副本。

## 2. 执行命令

```bash
export WEEK1=$HOME/asc-week1/week1-hpl-hpcg
export HPL_BIN=$HOME/asc-week1/src/hpl-2.3/bin/Linux_PII_CBLAS/xhpl
export HPCG_BIN=$HOME/asc-week1/src/hpcg/bin/xhpcg
export OUT_ROOT=$HOME/asc-week1/results

"$WEEK1/run_hpl.sh"  4 2 2 11520 192
"$WEEK1/run_hpcg.sh" 4 64 64 64 60
```

两次运行之间没有改动二进制、MPI、BLAS 或环境变量。

## 3. 结果

| 次数 | run_id | 基准 | ranks | 参数 | 时间 | 成绩 | 验证 |
|---|---|---|---|---|---|---|---|
| 1 | `HPL_20261113_181637_tEmyB4` | HPL | 4 | N=11520 NB=192 P×Q=2×2 | 5.30 s | **192.28 GFLOPS** | `PASSED` |
| 2 | `HPL_20261113_181643_74gUhK` | HPL | 4 | 同上 | 5.32 s | **191.79 GFLOPS** | `PASSED` |
| 1 | `HPCG_20261113_181649_loGAOH` | HPCG | 4 | 每 rank 64×64×64，60 s | Total=61.2776 s | **6.51613 GFLOP/s** | `VALID` |
| 2 | `HPCG_20261113_181758_O0VWe4` | HPCG | 4 | 同上 | Total=60.6079 s | **6.58838 GFLOP/s** | `VALID` |

波动：HPL 两次差 0.26%，HPCG 两次差 1.11%，都属正常范围。

## 4. 成绩字段与验证字段在哪

**HPL**（`HPL_run*/stdout.log`）：

```
WR11R2R4       11520   192     2     2               5.30             1.9228e+02
                                                                    ^^^^^^^^^^ 成绩 192.28 GFLOPS
||Ax-b||_oo/(eps*(||A||_oo*||x||_oo+||b||_oo)*N)=   2.08763558e-03 ...... PASSED
1 tests completed and passed residual checks,
0 tests completed and failed residual checks,
```

- 成绩字段：`WR11R2R4 ...` 行最后一段 `1.9228e+02`
- 验证字段：`...... PASSED` 与紧随其后的 `1 tests completed and passed residual checks`
- 退出码：`parameters.txt` 的 `exit_code=0`。README 要求“仅 `exit_code=0` 不足以证明正确”，所以两者都要看。

**HPCG**（`HPCG_run*/HPCG-Benchmark_*.txt`）：

```
Benchmark Time Summary::Total=61.2776
GFLOP/s Summary::Raw Total=6.59132
GFLOP/s Summary::Total with convergence and optimization phase overhead=6.51613
Final Summary::HPCG result is VALID with a GFLOP/s rating of=6.51613
                                                     ^^^^^^^^^^^^^^^^^^^^^^ 成绩取这里
```

- 成绩字段：`Final Summary::... GFLOP/s rating of=` 后的数值（**不是** `Raw Total`）
- 验证字段：同一行的 `HPCG result is VALID`
- `Benchmark Time Summary::Total` 是基准内部计时，与脚本记录的 `elapsed_wall_s=69` 口径不同（后者含启动与收尾），不必相等

## 5. 参数选择的依据（内存）

`N=11520` 的全局矩阵主存约 `8 × 11520² ≈ 0.99 GiB`，在 WSL2 默认 15 GiB 内存里只占约 6.6%——这是刻意保守，先确保拿到“正确基线”。按 README 第 57 行“第一轮令矩阵占比不超过 60–70%”的口径，15 GiB 的 60% 约 9 GiB，对应 `N ≈ 33 500`；第 3 天做 `N` 单变量实验时再按 60% / 80% / 100% 三档推进，并留出 WSL2 与 OpenBLAS 的额外缓冲。

`P×Q=2×2` 与 `ranks=4` 满足 `P×Q=ranks`。第 3 天会比较 `1×4` 与 `2×2` 两种网格。

## 6. 当天验收对照

- [x] 各有两次正确基线（HPL ×2、HPCG ×2）
- [x] 原始输入保留（`HPL.dat`、`hpcg.dat`）
- [x] stdout / stderr 保留（HPCG 的为空，属该版本正常行为）
- [x] 能指出成绩字段与验证字段（见第 4 节）
