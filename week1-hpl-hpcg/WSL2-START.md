# WSL2 单节点启动步骤

本页适用于你们当前的 Windows + WSL2 环境。先在 **PowerShell** 输入 `wsl` 进入已有 Linux 发行版；以下命令均在 **WSL2 的 Bash** 内执行。工作目录建议放在 Linux 文件系统（`~/asc-week1`），通常比直接在 `/mnt/d` 编译和跑基准更稳定。将此目录复制进去：

```bash
mkdir -p ~/asc-week1
cp -a /mnt/d/c/ASC/week1-hpl-hpcg ~/asc-week1/
cd ~/asc-week1/week1-hpl-hpcg
chmod +x *.sh
```

先确认发行版和可用资源：

```bash
cat /etc/os-release
nproc
free -h
df -h ~
```

如果是 Ubuntu/Debian，且还没有编译工具和库，可在 WSL2 内安装：

```bash
sudo apt update
sudo apt install build-essential gfortran openmpi-bin libopenmpi-dev libopenblas-dev git curl tar numactl
```

其他发行版请使用其包管理器安装同类软件。安装后确认 `mpicc --version`、`mpicxx --version`、`mpirun --version`，并核对 `ldconfig -p | grep -E 'lib(openblas|blas)'`。如果已经装好，跳过安装。

## 取得并编译程序（Ubuntu/Debian 示例）

以下在 WSL2 Bash 中执行。HPL 固定为 Netlib 2.3；HPCG 克隆后立即记录完整提交号，后续复现使用同一提交号。不要将 `~/asc-week1/src` 放进结果目录。

```bash
mkdir -p ~/asc-week1/src
cd ~/asc-week1/src
curl -fL --retry 3 -o hpl-2.3.tar.gz https://www.netlib.org/benchmark/hpl/hpl-2.3.tar.gz
sha256sum hpl-2.3.tar.gz | tee sources.sha256
tar -xzf hpl-2.3.tar.gz
git clone https://github.com/hpcg-benchmark/hpcg.git
git -C hpcg rev-parse HEAD | tee hpcg-commit.txt
git -C hpcg remote get-url origin
git -C hpcg checkout --detach "$(cat hpcg-commit.txt)"
```

HPL 使用随源码提供的 CBLAS 模板；OpenBLAS 开发包提供 `-lopenblas`。先核对模板名称及安装路径：

```bash
cd ~/asc-week1/src/hpl-2.3
ls setup/Make.*CBLAS*
mpicc --showme:link
ldconfig -p | grep libopenblas
```

如果存在 `setup/Make.Linux_PII_CBLAS`，以下命令可作为 Ubuntu/Debian 上的第一次构建。`TOPdir`、MPI 包装编译器和 BLAS 链接参数由命令行显式覆盖，不依赖模板里旧机器的路径：

```bash
cp setup/Make.Linux_PII_CBLAS Make.Linux_PII_CBLAS
make arch=Linux_PII_CBLAS TOPdir="$PWD" CC=mpicc LINKER=mpicc \
  MPinc= MPlib= LAinc= LAlib=-lopenblas -j "$(nproc)"
find "$PWD" -type f -name xhpl -print
```

若模板名称不同，先查看 `setup/Make.*CBLAS*`，复制合适模板并将上面命令中的 `Linux_PII_CBLAS` 同时改成复制后的文件名（去掉 `Make.` 前缀）。编译失败时保留完整错误日志；不要只改编译选项直到它“碰巧能过”。

HPCG 的 MPI 模板通常是 `setup/Make.Linux_MPI`。先核对它存在，再构建：

```bash
cd ~/asc-week1/src/hpcg
ls setup/Make.Linux_MPI
cp setup/Make.Linux_MPI Make.Linux_MPI
make arch=Linux_MPI HPCG_DIR="$PWD" TOPdir="$PWD" CXX=mpicxx LINKER=mpicxx -j "$(nproc)"
find "$PWD" -type f -name xhpcg -print
```

不同版本的 HPCG 模板可能使用其他编译器或源码目录变量；若 `make` 输出中没有 `mpicxx` 或源码路径不对，用 `grep -nE '^(CXX|LINKER|TOPdir|HPCG_DIR|HPCG_DEFS)' Make.Linux_MPI` 查明变量后修正。第一次先按 MPI-only（`THREADS=1`）实验；混合 OpenMP 实验前再检查构建命令是否含 OpenMP 开关。

找到两个程序后，设置绝对路径并核对动态库；`ldd` 中不能出现 `not found`，且编译与运行必须使用同一 MPI 实现：

```bash
export HPL_BIN="$(find ~/asc-week1/src/hpl-2.3 -type f -name xhpl | head -n 1)"
export HPCG_BIN="$(find ~/asc-week1/src/hpcg -type f -name xhpcg | head -n 1)"
test -x "$HPL_BIN" && test -x "$HPCG_BIN"
printf 'HPL_BIN=%s\nHPCG_BIN=%s\n' "$HPL_BIN" "$HPCG_BIN"
ldd "$HPL_BIN"
ldd "$HPCG_BIN"
sha256sum "$HPL_BIN" "$HPCG_BIN" | tee ~/asc-week1/src/binaries.sha256
```

若源码网站暂时无法访问，可让队友或老师提供原始源码包，并在本机运行 `sha256sum` 记录文件身份。Ubuntu/Debian 还可用 `apt-cache policy hpl hpcg` 查看是否有发行版软件包；只安装实际存在的包，再用 `dpkg -L <包名>` 找可执行文件。软件包版只作练习基线，记录 `dpkg-query -W <包名>`，与源码构建版分开比较。

## 第一次运行

先把目录和二进制路径改成你机器上的真实值：

```bash
export WEEK1=$HOME/asc-week1/week1-hpl-hpcg
export HPL_BIN=/absolute/path/to/xhpl
export HPCG_BIN=/absolute/path/to/xhpcg
export OUT_ROOT=$HOME/asc-week1/results
mkdir -p "$OUT_ROOT"
"$WEEK1/collect_env.sh" "$OUT_ROOT/environment.txt"
```

先用小规模做**冒烟测试**，只检查输入格式、MPI 启动和正确性；它们不是性能成绩：

```bash
"$WEEK1/run_hpl.sh" 1 1 1 2048 128
"$WEEK1/run_hpcg.sh" 1 32 32 32 60
```

如果此前已把脚本复制到 WSL2，而 Windows 工作区中的脚本后来更新，请先同步再运行。以下只覆盖脚本，不改动已保存的运行结果：

```bash
cp /mnt/d/c/ASC/week1-hpl-hpcg/*.sh "$WEEK1/"
chmod +x "$WEEK1"/*.sh
```

如果这两条成功，再按 [实验手册](README.md) 的第 2 天步骤建立 4-rank 基线。运行前确认 WSL2 至少有 4 个可用物理核、约 2 GB 以上空闲内存；不足就把 HPL 的 `N` 降低，并用 1–2 ranks。HPCG 的 `nx,ny,nz` 是**每个 MPI rank** 的局部尺寸。

### 检查两项冒烟测试结果

以下使用你们已完成的两次运行目录。后续重跑时，把 `HPL_RUN` 和 `HPCG_RUN` 改成脚本新打印的目录；不要混看不同轮次的结果。

```bash
HPL_RUN="$HOME/asc-week1/results/HPL_20261113_103953_RiChas"
HPCG_RUN="$HOME/asc-week1/results/HPCG_20261113_094959_h8r0Bl"

# HPL：先看退出码，再看残差检查和性能行
cat "$HPL_RUN/parameters.txt"
grep -nE 'PASSED|FAILED|Gflops|Gflop|WR[0-9]+[A-Z]' "$HPL_RUN/stdout.log" || true
tail -n 35 "$HPL_RUN/stdout.log"
cat "$HPL_RUN/stderr.log"

# HPCG 3.1：正式报告是 .txt，stdout/stderr 可能为空
cat "$HPCG_RUN/parameters.txt"
find "$HPCG_RUN" -maxdepth 1 -type f -name 'HPCG-Benchmark_*.txt' -print
grep -hE 'Benchmark Time Summary::Total=|GFLOP/s Summary::Total with convergence and optimization phase overhead=|Final Summary::HPCG result is|Final Summary::Results are valid' "$HPCG_RUN"/HPCG-Benchmark_*.txt
cat "$HPCG_RUN/stderr.log"
```

HPL 需要同时看到 `exit_code=0` 和 `PASSED`；GFLOPS 数值通常在以 `WR` 开头的结果行末尾。当前脚本将 HPL 输出写到 `stdout.log`，所以没有 `HPL.out` 也正常。HPCG 需要同时看到 `exit_code=0` 和 `Final Summary::HPCG result is VALID`；记录该行的 **GFLOP/s rating**，而非 `Raw Total`。若 `grep` 找不到对应字段，先用 `ls -lah "$HPL_RUN" "$HPCG_RUN"` 看实际文件，再检查完整报告。60 秒 HPCG 仍属于短时学习测试。

如果 `mpirun` 报 slots 不足，就降低 rank 数，不要用 oversubscribe 伪造基线。如果程序报缺库、输入读取失败或验证失败，先保留那个运行目录和日志，再修复环境或参数；不要只记录成功结果。

## 转到老师的服务器时

重新采集环境、重新编译或核对可执行文件与 MPI/数学库、重新跑两项基线。WSL2 的 GFLOPS 与服务器成绩分开记录。只有在服务器提供多个节点后，才增加跨节点通信实验；若 W7900D 平台开放，再按相应 GPU 实现单独做基线。
