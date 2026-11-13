

# 第一周 HPL / HPCG 实验手册

目标：让每位队员能独立解释两项基准测试、编译或取得可运行程序、得到正确的基线、只改变一个变量做对照实验，并复现最终结果。目前只有本地/单节点，因此本周必做内容都是**单节点 CPU 实验**。Linux 集群上要在作业分配内运行，不要在登录节点跑性能测试。下文的参数是教学起点，不是今年硬件的最优值。

ASC26 初赛通知要求说明操作系统、编译器、数学库、MPI 及版本，描述调优与测量方法，并提交名为 `HPL`、`HPCG` 的输出目录。本目录提供了起步脚本；最终提交前仍须核对当年的完整规则和平台使用说明。往届方案使用 EPYC 9124 + RTX 4070 Ti Super，成绩与参数不能当成新平台的目标值。

**现在从 [WSL2 启动步骤](WSL2-START.md) 开始。**老师的服务器开放后重新采集环境与基线，再开展多节点及 GPU 实验。

## 0. 准备

至少两人交叉检查：一人执行，一人核对输入、资源分配和日志。先确认可用节点数、每节点物理核数、内存、NUMA 拓扑、互连、调度器、可用编译器/MPI/BLAS、GPU 型号和相关权限。记录实际分配到的节点，不要用宣传配置代替。

如果本地是 Windows，请在 WSL2 的 Linux 发行版内执行脚本；本工作区通常对应 `/mnt/d/c/ASC/week1-hpl-hpcg`。先确认 `bash`、C/C++/Fortran 编译器、`make`、MPI 开发包及 BLAS 开发包已就绪。WSL2 的结果仅用作学习和本地对照，不能冒充正式测试平台成绩。准备好标准 CPU HPL 的 `xhpl` 和标准 HPCG 的 `xhpcg` 可执行文件，记录源码版本或提交号、构建命令和依赖库。HPL 源码来自 <https://www.netlib.org/benchmark/hpl/>，HPCG 源码来自 <https://github.com/hpcg-benchmark/hpcg>。HPCG 源码通常可用 `make arch=Linux_MPI` 从 `setup/Make.Linux_MPI` 模板构建；HPL 需从其 `setup/Make.*` 模板复制配置，明确 MPI、BLAS 路径后执行 `make arch=<配置名>`。不同机器的模块、库路径不同，不要照抄别人的 Makefile。用 `ldd /path/to/xhpl` 和 `ldd /path/to/xhpcg` 确认实际链接到哪一套 MPI/数学库，避免编译与运行混用 MPI。

把本目录复制到测试机后执行 `chmod +x *.sh`。以下示例假设脚本所在目录为 `$WEEK1`，并在已取得的计算节点作业分配内运行：

```bash
export WEEK1=/absolute/path/to/week1-hpl-hpcg
export HPL_BIN=/absolute/path/to/xhpl
export HPCG_BIN=/absolute/path/to/xhpcg
export OUT_ROOT=$PWD/week1-results
mkdir -p "$OUT_ROOT"
"$WEEK1/collect_env.sh" "$OUT_ROOT/environment.txt"
```

---

注意这里的hpl_bin 和 hpcg_bin命令里面写的不是正确命令 具体查询二者二进制地址可以详见 wsl2_start.md 中的

```bash
export HPL_BIN="$(find ~/asc-week1/src/hpl-2.3 -type f -name xhpl | head -n 1)"
export HPCG_BIN="$(find ~/asc-week1/src/hpcg -type f -name xhpcg | head -n 1)"
```

---

`collect_env.sh` 不一定能检测厂商专用软件；请把 `module list`、作业号、队列、节点型号、源码版本、构建参数补写到 `environment.txt`。如果使用 Slurm，在 `salloc`/`sbatch` 分配内设置 `LAUNCHER=srun`；本地单节点默认 `mpirun`。脚本默认 `OMP_NUM_THREADS=1`；将 rank 数限制在实际分配的物理核数内。若有意测试混合并行，设置 `THREADS` 并确保 `ranks × THREADS ≤ 分配的物理核数`，同时记录绑核方式。

## 第 1 天：环境与程序

1. 运行 `collect_env.sh`。核对 `lscpu`、`free -h`、`numactl --hardware`、网卡、`mpirun --version`、编译器版本、`ldd` 与作业分配一致。没有某个命令时记录 `unavailable` 即可。
2. 保存源码包或 Git 提交号、Makefile/编译参数、二进制 SHA256。两项程序先各以最小可行规模运行一次，排除动态库、MPI 和输入格式问题。
3. 每位队员画出 HPL 的「分块 LU → BLAS 计算与面板通信」以及 HPCG 的「SpMV / SymGS / 多重网格 / MPI halo」流程，指出 HPL 偏计算、HPCG 更受内存与通信影响。阅读源码中对应入口和计时/验证逻辑，在笔记中写出文件名与函数名。

提交到各自github分支：environment.txt文件 以及 wsl2-start.md中的冒烟测试运行结果（具体输出结果，命令详见wsl2-start.md![image-20261113105624169](C:\Users\Rugers\AppData\Roaming\Typora\typora-user-images\image-20261113105624169.png))

**当天验收**：两项二进制可启动；环境清单、构建命令与源码版本完整；能解释 rank、线程、节点、进程网格的区别。

## 第 2 天：正确基线

选一个单节点且不超过分配物理核数的 rank 数，例如 4 或 8；以下 `4 2 2` 仅为命令示例。示例 `N=11520` 的矩阵本身约 0.99 GiB，仍须按实际可用内存重新确认。HPL 的全局矩阵主存约为 `8×N²` 字节。用**作业分配内可用内存**估算，第一轮令矩阵占比不超过约 60–70%，还要给操作系统、MPI、BLAS 和额外缓冲留空间。将 `N` 取为 `NB` 的整数倍有助于做整齐的起步对照；不要为了整齐超过内存上限。

```bash
"$WEEK1/run_hpl.sh" 4 2 2 11520 192
"$WEEK1/run_hpcg.sh" 4 64 64 64 60
```

HPL 结果必须出现通过残差检查的记录（如 `PASSED`），并记下 GFLOPS 与总时间。HPCG 保存程序生成的正式报告；当前源码版本在运行目录写 `HPCG-Benchmark_*.txt`，应以其中 `Final Summary::HPCG result is VALID` 和最终评级为准。60 秒只作短时探索，不当正式成绩。若程序要求更大的局部网格或不同输入格式，以所用版本文档和错误提示调整，并记录原因。两项程序各重复一次基线，确认变化幅度；若差异较大，先查系统负载、频率、绑核、NUMA 和节点共享情况。

**当天验收**：各有两次正确基线，原始输入和 stdout/stderr 均保留，能指出成绩字段和验证字段。

## 第 3 天：HPL 单变量实验

固定二进制、节点、rank 数、线程、绑核和其他参数；按顺序做三组实验，每组只改一个变量。每次记录 `N, NB, P, Q, ranks, threads, GFLOPS, 时间, 验证结果`。

1. `N`：按内存上限选三个规模，例如安全上限的约 60%、80%、100%，但最后一档仍须留上述缓冲。不要让交换分区参与计算；出现 OOM/换页就回退。若一次预计过长，用 `t ≈ 2N³/(3×实测每秒浮点运算数)` 粗估时间。
2. `NB`：固定表现稳定的 `N`，试 128、192、256、384 等可被程序接受的值；有根据时再扩大范围。
3. `P×Q`：始终满足 `P×Q=ranks`，如 4 ranks 比较 `1×4` 与 `2×2`。记录网格形状对通信与成绩的影响。

每组先短测，选前两名各复跑一次；不要一边换 BLAS 一边换 `NB`。最后再讨论是否值得比较 AOCL/BLIS 与 OpenBLAS，这需要**分别保存二进制和版本信息**。

**当天验收**：至少一张单变量对照表，能用计算/通信、缓存或内存解释趋势，且最优项通过正确性检查。

## 第 4 天：HPCG 单变量实验

固定二进制与节点，先用 60–120 秒筛选，保持所有候选的时长一致。每项试验保存 `nx,ny,nz`（**每 rank 的局部尺寸**）、ranks、线程、进程布局、成绩、验证信息、时间。局部尺寸先用每维 8 的倍数且不小于 16，再按所用 HPCG 版本的限制调整。

1. 固定 ranks 和线程，比较 2–3 组局部网格，如 `64³`、`96³`、`128³`，逐步观察内存占用；不要按 HPL 的 `8N²` 公式估 HPCG 内存。
2. 固定局部网格，比较单节点不同 rank 数，例如 1、2、4 ranks。MPI-only 基线设置 `THREADS=1`。此时全局问题随 rank 数变化，应称为弱扩展的初步观察。
3. 资源允许时，固定**总物理核预算**，比较纯 MPI 与 MPI+OpenMP，例如 8×1 和 4×2。确认 HPCG 构建确实启用了 OpenMP，否则这组比较没有意义。把 NUMA/进程绑定写清楚。本周不做跨节点测试。

注意 HPCG 的每 rank 局部问题越大，全局问题也会变，不能把不同规模下的 GFLOPS 直接解释为纯并行扩展效率。要比较扩展性，另做保持全局工作量近似不变的实验并说明切分方式。观察正式报告中 SpMV、MG 和通信相关时间，找主要瓶颈；若版本提供 SymGS 分项，也单独记录。

**当天验收**：至少一张局部规模表和一张并行配置表，所有入围项通过验证，能说明为何改变配置后成绩变化。

## 第 5 天：正式复现与交付

1. 固定前两天挑出的 HPL/HPCG 配置，至少各跑两次；使用相同节点类型、软件栈、绑核和环境。HPCG 最终运行 1800 秒，或以当前比赛/所用实现规定的更严格要求为准。任何筛选用短测都须明确标为 `exploratory`。
2. 将每次的输入文件、stdout/stderr、HPL 验证结果、HPCG 正式报告（当前版本为 `HPCG-Benchmark_*.txt`）与 `environment.txt` 一起归档。脚本在 `OUT_ROOT` 下为每次运行建立独立目录；不要覆盖失败日志。
3. 生成两张结果表：基线与最佳配置的绝对 GFLOPS、相对提升 `(best/base−1)×100%`、复跑波动、正确性、运行时间。附上环境、构建与运行命令，解释性能瓶颈和未解决问题。若未提升，也如实保留结论。
4. 由另一位队员只看文档复跑一次，确认输入、日志和结论对应。正式提交时将最终原始输出按通知放到 `HPL` 和 `HPCG` 目录。

**第一周总验收**：两项基线均正确；每项至少一组单变量实验；最佳配置各有复跑；有完整日志、可复现命令及一页性能分析。GPU/W7900D 若已开放，可另起同样流程做 GPU 基线，但不要和 CPU 结果混在同一对照表，也不要把 CPU 版脚本直接用于 GPU 厂商版本。

## 记录模板

把 `runs.csv` 复制到结果目录，每次运行追加一行。`run_id` 对应脚本生成的目录，`valid` 填验证结果而不是根据 GFLOPS 猜测。报告中至少附上失败案例及失败原因。
