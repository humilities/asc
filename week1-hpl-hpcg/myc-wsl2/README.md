# myc 的 WSL2 单节点实测

2026 年 11 月 15 日，在 Windows 11 的 WSL2 Ubuntu 上运行标准 CPU HPL 和纯 MPI HPCG。编译器、MPI、数学库、源码版本和哈希见 [环境清单](environment.txt)。

## 构建

源码使用 Netlib HPL 2.3 和 HPCG 提交 `114602d458d1034faa52b71e4c15aba9b3a17698`。WSL 下载时出现域名解析超时，改在 Windows 下载源码和 Ubuntu 软件包，再复制到 WSL。将版本均为 `0.3.26+ds-1ubuntu0.1` 的 `libopenblas0-pthread` 和 `libopenblas-pthread-dev` 分别用 `dpkg-deb -x 软件包.deb "$root/openblas"` 解包。

以下命令中的 `root` 指向包含 `src/hpl-2.3`、`src/hpcg` 和 `openblas` 的实验目录。已装系统 OpenBLAS 时，也可按 [WSL2 启动步骤](../WSL2-START.md) 链接系统库。

```bash
blas="$root/openblas/usr/lib/x86_64-linux-gnu/openblas-pthread"
blas_include="$root/openblas/usr/include/x86_64-linux-gnu/openblas-pthread"
export LD_LIBRARY_PATH="$blas"

cd "$root/src/hpl-2.3"
cp setup/Make.Linux_PII_CBLAS Make.Linux_PII_CBLAS
make arch=Linux_PII_CBLAS TOPdir="$PWD" CC=mpicc LINKER=mpicc \
  MPinc= MPlib= "LAinc=-I$blas_include" "LAlib=-L$blas -lopenblas"
export HPL_BIN="$PWD/bin/Linux_PII_CBLAS/xhpl"

cd "$root/src/hpcg"
make arch=Linux_MPI TOPdir="$PWD" CXX=mpicxx LINKER=mpicxx -j 4
export HPCG_BIN="$PWD/bin/xhpcg"
```

## 运行

在 Linux 中进入仓库的 `week1-hpl-hpcg`，设置结果保存目录。每项先跑一次单进程冒烟测试，再跑两次四进程基线。HPCG 网格为每个 MPI 进程的局部尺寸。两类 HPCG 测试均设为 60 秒，属于短时训练。

```bash
export OUT_ROOT="$root/results" THREADS=1
bash run_hpl.sh 1 1 1 2048 128 </dev/null
bash run_hpcg.sh 1 32 32 32 60 </dev/null

for attempt in 1 2; do
  bash run_hpl.sh 4 2 2 11520 192 </dev/null
  bash run_hpcg.sh 4 64 64 64 60 </dev/null
done
```

成绩见 [实验记录](runs.csv)。各次测试目录中有输入参数和原始输出。HPL 读取残差校验和结果行，HPCG 读取最终校验与评级。

[HPL 块大小和 HPCG 局部网格扫描](sweep-2026-11-15/README.md)。
