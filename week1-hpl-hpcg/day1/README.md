# 第 1 天交付物：环境与程序

对应 `README.md` 第 1 天（第 45–54 行）与 `WSL2-START.md` 的冒烟测试要求。

- 执行日期：2026-11-13
- 执行环境：WSL2（Ubuntu 26.04.1 LTS，内核 6.18.40.1-microsoft-standard-WSL2）
- 宿主机：i7-14650HX（12 物理核 / 24 逻辑核），31.7 GiB RAM，Windows 11 22631
- 计算资源：WSL2 默认配额 15 GiB 内存 + 4 GiB swap

## 1. 交付文件清单

| 文件 | 来源 | 说明 |
|---|---|---|
| `environment.txt` | `collect_env.sh` 输出 + 人工补写 | 224 行；含 lscpu / free / numactl / 编译器 / MPI / BLAS / 二进制 SHA256 + ldd |
| `HPL/stdout.log` | 运行目录 `HPL_20261113_181446_kYu5Rp` | 冒烟测试 stdout，含残差检查行 `PASSED` |
| `HPL/HPL.dat` | 同上 | 脚本生成的 31 行 HPL 输入文件（N=2048, NB=128, P=1, Q=1） |
| `HPL/parameters.txt` | 同上 | 参数、二进制路径、`exit_code=0`、耗时 |
| `HPCG/HPCG-Benchmark_3.1_2026-11-13_18-15-48.txt` | 运行目录 `HPCG_20261113_181446_CwiUlb` | HPCG 3.1 正式报告，含 `Final Summary::HPCG result is VALID` |
| `HPCG/hpcg.dat` | 同上 | 4 行 HPCG 输入（每 rank 局部 32×32×32，60 秒） |
| `HPCG/parameters.txt` | 同上 | 参数、二进制路径、`exit_code=0`、耗时 |
| `notes.md` | 手写 | 第 1 天第 3 项：HPL 与 HPCG 的流程与源码入口 |

## 2. 冒烟测试结果

### HPL

```
RANKS=1 P=1 Q=1 N=2048 NB=128 THREADS=1 LAUNCHER=mpirun
exit_code=0            elapsed_wall_s=0
WR11R2R4  2048  128  1  1  0.10  5.6766e+01
||Ax-b||_oo/(eps*(||A||_oo*||x||_oo+||b||_oo)*N)= 3.59214136e-03 ...... PASSED
1 tests completed and passed residual checks, 0 failed, 0 skipped
```

- 成绩字段：`WR11R2R4 ... 5.6766e+01` 行末的 **56.77 GFLOPS**
- 验证字段：残差 `3.59214136e-03` ≪ 阈值 16，判 `PASSED`

### HPCG

```
RANKS=1 NX=32 NY=32 NZ=32 SECONDS=60 THREADS=1 LAUNCHER=mpirun
exit_code=0            elapsed_wall_s=62
Benchmark Time Summary::Total=61.1431
GFLOP/s Summary::Raw Total=4.64693
GFLOP/s Summary::Total with convergence and optimization phase overhead=4.50957
Final Summary::HPCG result is VALID with a GFLOP/s rating of=4.50957
```

- 成绩字段：**GFLOP/s rating = 4.50957**（不是 `Raw Total` 4.64693）
- 验证字段：`Final Summary::HPCG result is VALID`

两项均 `exit_code=0` 且验证通过，冒烟测试合格。60 秒 HPCG 属短时学习测试，不作正式成绩。

## 3. 环境与构建身份

| 项目 | 值 |
|---|---|
| OS | Ubuntu 26.04.1 LTS (resolute) |
| 编译器 | gcc / g++ / gfortran 15.2.0 |
| MPI | OpenMPI 5.0.10（`/usr/bin/mpirun`） |
| BLAS | OpenBLAS 0.3.32（pthread 变体，`update-alternatives` 已指向它） |
| HPL 源码 | Netlib 2.3，tarball SHA256 `32c5c17d22330e6f2337b681aded51637fb6008d3f0eb7c277b163fadd612830` |
| HPCG 源码 | commit `114602d458d1034faa52b71e4c15aba9b3a17698`（`hpcg-benchmark/hpcg`） |
| `xhpl` SHA256 | `dd7b2f3bf854eaf50bddf077829a163f85399f9576e3dbfa5d48634fb5a37ddd` |
| `xhpcg` SHA256 | `1b887050659039cc81cbc4d040ce82224905b59c93f2e527f9a294a241238143` |

构建命令（完整版见 `environment.txt` 末尾“补充信息”）：

```bash
# HPL：必须串行，-j 会触发 Make.top 递归竞争
cd ~/asc-week1/src/hpl-2.3
cp setup/Make.Linux_PII_CBLAS Make.Linux_PII_CBLAS
make arch=Linux_PII_CBLAS TOPdir="$PWD" CC=mpicc LINKER=mpicc \
     MPinc= MPlib= LAinc= LAlib=-lopenblas

# HPCG：可并行
cd ~/asc-week1/src/hpcg
cp setup/Make.Linux_MPI Make.Linux_MPI
make arch=Linux_MPI HPCG_DIR="$PWD" TOPdir="$PWD" CXX=mpicxx LINKER=mpicxx -j 8
```

## 4. 复现命令

```bash
export WEEK1=$HOME/asc-week1/week1-hpl-hpcg
export HPL_BIN=$HOME/asc-week1/src/hpl-2.3/bin/Linux_PII_CBLAS/xhpl
export HPCG_BIN=$HOME/asc-week1/src/hpcg/bin/xhpcg
export OUT_ROOT=$HOME/asc-week1/results

"$WEEK1/collect_env.sh" "$OUT_ROOT/environment.txt"
"$WEEK1/run_hpl.sh"  1 1 1 2048 128
"$WEEK1/run_hpcg.sh" 1 32 32 32 60
```

## 5. 已知问题与说明

1. `WSL2-START.md:7`、`:115` 与 `README.md:15` 中的 `/mnt/d/c/ASC/...` 是作者机器的路径，本机实际为 `E:\Program Files\DeepSeek\workspace\asc`（WSL 中 `/mnt/e/Program Files/DeepSeek/workspace/asc`），复制时需替换。
2. 仓库脚本在 Windows 上检出为 CRLF，直接执行会报 `env: $'bash\r': No such file or directory`；需 `sed -i 's/\r$//' *.sh`。
3. `mpirun --version` 会打印 `Sorry! You were supposed to get help about: version`，是 Ubuntu 26.04 的 OpenMPI 包缺帮助文件所致，不影响运行；版本号以 `dpkg-query -W openmpi-bin` 为准（5.0.10-1）。
4. `environment.txt` 前 165 行为 `collect_env.sh` 原样输出，其后为人工补写的“补充信息”段（OS、包版本、源码身份、构建命令、二进制指纹、运行环境说明），依据 `README.md:43` 的要求。
