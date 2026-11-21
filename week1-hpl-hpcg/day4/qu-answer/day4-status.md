# Day 4：HPCG 单变量实验收尾报告

日期：2026-11-21。平台：本地 WSL2 单节点。范围：HPCG 3.1、MPI-only、每 rank 1 个线程、全部请求 60 秒。本文根据组员提供的 [10 条 CSV](day4-runs.csv) 整理；原始 `HPCG_*` 目录尚未在本会话直接读取。CSV 中 10 条均记为 `VALID`、`exit_code=0`。全部结果均为 `exploratory`，`official=NO`，不能作为 1800 秒正式成绩。

## 实验 A：每 rank 局部规模

固定 4 ranks、1 thread。`nx,ny,nz` 是每 rank 的局部尺寸；全局问题随局部尺寸改变。

| 局部网格 | 全局网格 | 评级 GFLOP/s | 均值 GFLOP/s | 两次差值 | 验证 |
|---|---|---|---:|---:|---|
| 64³ | 128×128×64 | 5.09955、5.24386 | **5.17171** | 0.14431 | 均 VALID |
| 80³ | 160×160×80 | 5.15595、5.18754 | **5.17175** | 0.03159 | 均 VALID |
| 96³ | 192×192×96 | 4.99188 | — | — | VALID，未复跑 |

64³ 与 80³ 的两次均值只差约 **0.00004 GFLOP/s**，在现有精度和波动下无法区分优劣。80³ 的两次结果更接近，但每 rank 的问题更大。96³ 的单次评级较低，未入围复跑。局部规模变化会改变全局方程数，不能把本组解释为纯并行扩展。

## 实验 B：MPI ranks 的初步弱扩展

固定每 rank 的 64³ 局部网格、1 thread，只改变 ranks；全局问题随 ranks 增加。

| ranks | 布局 | 全局网格 | 评级 GFLOP/s | 两次均值 GFLOP/s | 报告时间 s | 验证 |
|---:|---|---|---|---:|---|---|
| 1 | 1×1×1 | 64×64×64 | 4.38908、4.22263 | **4.30586** | 44.3028、62.9816 | 均 VALID；首次计时待查 |
| 2 | 2×1×1 | 128×64×64 | 5.28495、4.79534 | **5.04015** | 62.3684、64.9338 | 均 VALID |
| 4 | 2×2×1 | 128×128×64 | 5.35995、5.24386¹ | **5.30191** | 60.4600、61.7188 | 均 VALID |

¹ 4-rank 的第二个值来自实验 A 的同参数复跑。实验 A 另有一条同参数结果 5.09955；三条同配置结果的均值为 **5.23445 GFLOP/s**，范围为 **5.09955–5.35995**。

2-rank 两次结果相差 **0.48961 GFLOP/s**，约为均值的 **9.71%**，波动明显。4 ranks 在这组短测中评级较高，但不能从不同全局问题的 GFLOP/s 推导严格的并行效率。

## 1-rank 短计时

首次 1-rank 运行请求 60 秒，报告总时间仅 **44.3028 秒**；复跑请求同样的 60 秒，报告总时间为 **62.9816 秒**。复跑说明短计时没有再次出现，但**不能确定首次提前结束的原因**。首次在 CSV 中仍为 `VALID`，但涉及统一运行时长的比较时应单独标记。需要核对首次原始 `hpcg.dat`、`parameters.txt`、正式报告及 stderr；在证据到位前，原因写“未查明”。若只比较时长接近 60 秒的记录，1-rank 采用复跑的 4.22263 GFLOP/s，并说明这项只有一次合适时长的观察。

## 性能观察与实验 C

各次报告的 MG 时间约占总时间的 80% 左右，是当前日志中耗时最大的分项；SpMV 次之。现有计时不足以把 MG 耗时归因于某个具体内存或通信瓶颈。全部记录的 `swap_status=UNVERIFIED`，因为没有提供运行时监控证据。

**实验 C 未执行：当前 HPCG 二进制以 `HPCG_NO_OPENMP` 构建，无法进行有效的 MPI+OpenMP 对照。** 实验 C 属于资源允许时的扩展工作，不是 Day 4 验收缺项。

## Day 4 结论与 Day 5 候选

Day 4 已有局部规模表、并行配置表及入围项复跑。暂选 **4 MPI ranks × 1 thread、每 rank 64×64×64** 为 Day 5 的 HPCG 候选：它与 80³ 的两次均值几乎相同，所需数据内存较小，而且已有 Day 2 基线可对照。80³ 可保留为备选，现有数据没有证明它的评级更高。

正式运行把输入时长改为 **1800 秒**，固定同一二进制、软件栈、绑核及环境，至少运行两次；只有正式报告均 `VALID` 后才报告正式评级。60 秒结果不能当作正式成绩。

## 归档核验与 Day 5 命令

在 WSL2 Bash 中，用 [验收脚本](day4_check.py) 从原始运行目录重新生成 CSV，核对 10 个 run_id，并保留每次的 `hpcg.dat`、`parameters.txt`、`stdout.log`、`stderr.log` 和 `HPCG-Benchmark_*.txt`。还需核对 HPCG 二进制哈希和 MPI 绑核记录。

```bash
export WEEK1="$HOME/asc-week1/week1-hpl-hpcg"
export HPCG_BIN="$HOME/asc-week1/src/hpcg/bin/xhpcg"
export OUT_ROOT="$HOME/asc-week1/results/day4"
python3 "$HOME/asc-week1/day4_check.py" "$OUT_ROOT"

OLD_ONE_RANK="$OUT_ROOT/HPCG_20261121_151230_yAU6bN"
cat "$OLD_ONE_RANK/hpcg.dat"
cat "$OLD_ONE_RANK/parameters.txt"
grep -E 'Benchmark Time Summary::Total=|Final Summary::Results are valid but execution time|Final Summary::HPCG result is' \
  "$OLD_ONE_RANK"/HPCG-Benchmark_*.txt
cat "$OLD_ONE_RANK/stderr.log"
```

Day 5 复现候选的命令（在确认可用内存、同一二进制与环境后执行）：

```bash
export OUT_ROOT="$HOME/asc-week1/results/day5-hpcg"
export THREADS=1 LAUNCHER=mpirun
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export BLIS_NUM_THREADS=1 MKL_NUM_THREADS=1
export OMPI_MCA_hwloc_base_binding_policy=core
export OMPI_MCA_rmaps_base_mapping_policy=slot
mkdir -p "$OUT_ROOT"
sha256sum "$HPCG_BIN"
free -h
"$WEEK1/collect_env.sh" "$OUT_ROOT/environment.txt"
"$WEEK1/run_hpcg.sh" 4 64 64 64 1800
"$WEEK1/run_hpcg.sh" 4 64 64 64 1800
```

两次运行会生成独立目录。逐个确认退出码为 0、正式报告中的 `Final Summary::HPCG result is VALID`，以及实际执行时间满足当前比赛规则，再归档所有原始文件。
