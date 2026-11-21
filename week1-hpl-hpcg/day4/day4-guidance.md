# Day 4 指导文档：HPCG 单变量实验

本文对应项目 README 的“第 4 天：HPCG 单变量实验”，并按你已有的 Day 2 HPCG 结果制定方案。所有 Day 4 运行都是本地 WSL2 单节点的 `exploratory` 短测，不是比赛正式成绩；正式 HPCG 成绩需要按所用规则运行至少 1800 秒。

## 1. Day 4 要完成什么

完成两张表：

1. **局部规模表**：固定 MPI ranks 和线程，比较每个 rank 的 `nx,ny,nz`。
2. **并行配置表**：固定局部网格，比较 1、2、4 个 MPI ranks。

每个候选都要保存：`nx,ny,nz`（每 rank 的局部尺寸）、ranks、threads、进程布局、HPCG 评级、总时间、SpMV/MG 时间、验证状态和运行目录。所有候选使用相同的短时长，例如 60 秒；不要用不同运行时长直接比较成绩。

## 2. 已有基线

你 Day 2 的 HPCG 报告是：

| 项目 | 基线值 |
|---|---:|
| ranks | 4 |
| threads/rank | 1 |
| 局部网格 | `64×64×64` |
| 全局网格 | `128×128×64` |
| 进程布局 | `npx=2,npy=2,npz=1` |
| 报告总时间 | 63.1482 s |
| HPCG 有效评级 | 5.12021 GFLOP/s |
| 验证 | `HPCG result is VALID` |
| 官方最短时间 | 1800 s |

报告中的 `Total memory used for data` 是 0.750145 GB。它对应的是 4 ranks、每 rank `64³` 的问题；HPCG 内存随网格体积增加，不能使用 HPL 的 `8N²` 公式估算。

## 3. 在 WSL2 Bash 中准备环境

从 PowerShell 输入 `wsl`，之后全部在 WSL2 Bash 中执行：

```bash
export WEEK1="$HOME/asc-week1/week1-hpl-hpcg"
export HPCG_BIN="$HOME/asc-week1/src/hpcg/bin/xhpcg"
export OUT_ROOT="$HOME/asc-week1/results/day4"
export THREADS=1
export LAUNCHER=mpirun

export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
export BLIS_NUM_THREADS=1 MKL_NUM_THREADS=1
export OMPI_MCA_hwloc_base_binding_policy=core
export OMPI_MCA_rmaps_base_mapping_policy=slot

mkdir -p "$OUT_ROOT"
chmod +x "$WEEK1"/*.sh
test -x "$HPCG_BIN" && sha256sum "$HPCG_BIN"
ldd "$HPCG_BIN" | grep -E 'mpi|gomp|omp|not found' || true
free -h
```

如果实际路径不是上述路径，使用：

```bash
export HPCG_BIN="$(find "$HOME/asc-week1/src/hpcg" -type f -name xhpcg | head -n 1)"
```

脚本参数格式：

```text
RANKS NX NY NZ SECONDS
```

其中 `NX,NY,NZ` 是**每个 MPI rank 的局部网格**，不是全局网格。当前脚本会将它们原样写入 `hpcg.dat`。

## 4. 内存安全与网格选择

以已有 `64³/ranks=4` 报告的 0.750145 GB 为粗略比例估计：

| 每 rank 局部网格 | 相对体积 | 粗略数据内存 | 建议 |
|---|---:|---:|---|
| `64³` | 1.00 | 0.75 GB | 已有基线 |
| `80³` | 1.95 | 约 1.47 GB | 建议候选 |
| `96³` | 3.38 | 约 2.53 GB | 建议候选，先检查可用内存 |
| `128³` | 8.00 | 约 6.0 GB | 当前 WSL2 不建议直接运行 |

你的环境记录中总内存约 7.3 GiB，Day 2 时可用约 5.9 GiB。`128³` 每 rank 的估算数据已经接近或超过可用空间，还没有给 MPI、程序和操作系统留下缓冲。Day 4 先使用 `64³、80³、96³`；只有 `96³` 稳定、无 swap、无 OOM，且 `free -h` 显示足够内存时，才考虑更大规模。

## 5. 建议的运行顺序

### 实验 A：局部网格规模

固定：`ranks=4、threads=1、seconds=60`，只改变局部网格：

```bash
"$WEEK1/run_hpcg.sh" 4 64 64 64 60
"$WEEK1/run_hpcg.sh" 4 80 80 80 60
"$WEEK1/run_hpcg.sh" 4 96 96 96 60
```

三项均为每 rank 的局部尺寸，且都是 8 的倍数、不小于 16。它们的全局工作量不同：ranks=4 时，局部 `64³` 对应约 1.05M 个方程，`80³` 对应约 2.05M，`96³` 对应约 3.54M。因此不能把这组结果解释为强扩展效率；它主要观察局部问题大小对内存、缓存和计算吞吐的影响。

### 实验 B：MPI ranks 的初步弱扩展

固定：局部网格 `64×64×64、threads=1、seconds=60`，只改变 MPI ranks：

```bash
"$WEEK1/run_hpcg.sh" 1 64 64 64 60
"$WEEK1/run_hpcg.sh" 2 64 64 64 60
"$WEEK1/run_hpcg.sh" 4 64 64 64 60
```

这组实验中每个 rank 的工作量不变，所以全局问题随 ranks 增长，是**弱扩展的初步观察**。不要称为固定全局问题的并行加速。必须从每个正式报告中记录 `npx,npy,npz` 和全局尺寸；不能假定 MPI 自动使用某个进程网格。

## 6. 运行期间检查内存和绑核

另开一个 WSL2 窗口，在运行期间执行：

```bash
watch -n 1 free -h
```

或：

```bash
vmstat 1
```

如果看到持续的 swap 输入/输出、内存耗尽、系统明显卡顿或程序被杀，停止该规模并保留运行目录。不要删除失败案例；在结果表中标记 `OOM`、`swap` 或 `FAILED`。

为了记录 MPI 绑定情况，可以在实际实验前做一次单独检查：

```bash
mpirun --report-bindings -np 4 hostname 2>&1 | tee "$OUT_ROOT/binding-4ranks.txt"
```

对 1、2、4 ranks 分别检查进程绑定情况。绑定检查文件和 `environment.txt` 一起归档。

## 7. 用验收脚本批量检查运行目录

把随本文交付的 [day4_check.py](day4_check.py) 复制到 WSL2，然后扫描 `OUT_ROOT` 下所有 `HPCG_*` 目录：

```bash
cp /mnt/c/Users/Rugers/Documents/Codex/2026-11-21/zhi-d/outputs/day4_check.py \
  "$HOME/asc-week1/day4_check.py"
python3 "$HOME/asc-week1/day4_check.py" "$OUT_ROOT"
```

脚本会生成 `"$OUT_ROOT/day4-runs.csv"`，并在终端逐行显示 `VALID` 或 `CHECK`。`CHECK` 的原因写在 `notes` 中；有任何 `CHECK` 时脚本以非零状态退出。它检查输入目录中的 `hpcg.dat`、`parameters.txt`、`stdout.log`、`stderr.log` 和唯一一份 `HPCG-Benchmark_*.txt`，核对退出码、局部尺寸、ranks、threads、进程网格、四项 V&V 结果及最终评级。报告计时明显短于请求时长时，脚本添加 `reported_time_below_requested_review` 提示，但不自动推翻报告的 `VALID`。重复运行脚本会**重新生成** CSV，不会追加重复行；如果组员要手工补充注释，请另存一份带注释的表。

查看表格：

```bash
column -s, -t "$OUT_ROOT/day4-runs.csv"
```

若 `column` 不可用，执行 `cat "$OUT_ROOT/day4-runs.csv"`。对标为 `CHECK` 的运行，再看原始文件：

```bash
RUN_DIR="需要复查的完整 HPCG_* 目录"
cat "$RUN_DIR/parameters.txt"
grep -E 'Final Summary::HPCG result is|Benchmark Time Summary::(SpMV|MG|Total)=|::Result=|Machine Summary::|Processor Dimensions::' \
  "$RUN_DIR"/HPCG-Benchmark_*.txt
cat "$RUN_DIR/stderr.log"
```

一个有效的 Day 4 短测至少需要：

- `parameters.txt` 中 `exit_code=0`；
- 报告中 `Final Summary::HPCG result is VALID with a GFLOP/s rating of=...`；
- V&V、对称性、迭代和可复现性摘要都为 `PASSED`；
- 报告中记录了 `npx,npy,npz`、全局/局部尺寸；
- 没有 OOM；swap 需靠运行时监测证明。

脚本对短测写 `official=NO` 和 `exploratory_short_run`，并将 `swap_status` 写为 `UNVERIFIED`。**报告无法在事后证明没有 swap**；若未保存运行时的 `vmstat` 或等价监控记录，应保持“未核实”。`60` 秒运行的结果可以是 VALID，但不能称为官方 HPCG 成绩。正式运行需使用至少 1800 秒，并保存正式 `HPCG-Benchmark_*.txt`。

## 8. 建议的 Day 4 记录表

验收脚本直接生成 `day4-runs.csv`，包含 HPCG 特有字段：

| run_id | nx | ny | nz | ranks | threads | npx | npy | npz | global dims | seconds | total time | GFLOP/s rating | SpMV time | MG time | valid | official | notes |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---|---|---|
| HPCG_... | 64 | 64 | 64 | 4 | 1 | 2 | 2 | 1 | 128×128×64 | 60 | 63.1482 | 5.12021 | 8.80928 | 50.7173 | VALID | NO | baseline/exploratory |

`GFLOP/s rating` 使用 Final Summary 中的评级，不要使用 `Raw Total` 或其他中间字段。`valid` 根据报告文字填写，不要根据 GFLOP/s 猜测。

## 9. 结果分析模板

### 局部规模

> 固定 4 ranks、1 thread 和 60 秒运行时长，比较每 rank 的 `64³、80³、96³` 局部网格。局部网格增大使全局方程数和数据内存按体积增长，因此 GFLOP/s 不能单独解释为并行效率。结合总时间、SpMV、MG、内存占用和是否换页，判断较大网格是否提高了稳态吞吐或只是增加了工作量。

### MPI ranks

> 固定每 rank 的 `64³` 局部网格和 1 个线程，比较 1、2、4 ranks。这是保持局部工作量的弱扩展初步观察；全局尺寸随 ranks 改变。对比报告中的 Processor Dimensions、SpMV、MG 和总评级，并说明单节点内存带宽与 MPI halo 通信可能影响结果。

## 10. Day 4 验收清单

- [ ] 局部规模表至少包含 `64³、80³、96³` 或有充分理由的替代规模。
- [ ] 并行配置表至少包含 1、2、4 ranks 的 `64³` 局部网格。
- [ ] 所有候选使用相同短时长（建议 60 秒）。
- [ ] 每条记录有局部尺寸、全局尺寸、进程布局、threads、评级、总时间、SpMV/MG 时间和验证状态。
- [ ] 所有入围项的报告中有 `HPCG result is VALID`，V&V 项为 `PASSED`。
- [ ] 失败、OOM 和 swap 案例没有被删除。
- [ ] 报告注明实验 C 未执行：当前二进制以 `HPCG_NO_OPENMP` 构建。
- [ ] 解释了不同局部规模和不同 ranks 下全局工作量的变化。
- [ ] 60 秒结果标为 `exploratory`，没有冒充 1800 秒正式成绩。

## 11. 推荐执行顺序

你已完成实验 A 的 `64³、80³、96³` 和实验 B 的 1、2、4 ranks 初筛，并完成 A 组 `64³、80³`、B 组 2 ranks 与 1 rank 的复跑。查看 [Day 4 收尾报告](day4-status.md) 与 [10 条运行记录](day4-runs.csv) 了解结果。现在需要从原始目录重新运行验收脚本、核查首次 1-rank 的短计时、保存全部 `HPCG_*` 目录与环境记录。Day 5 暂选 4 ranks、1 thread、每 rank `64³` 做 1800 秒正式复现。
