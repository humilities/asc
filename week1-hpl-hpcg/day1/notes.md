# 第 1 天笔记：HPL 和 HPCG 到底在算什么

这两份笔记对应 `README.md` 第 1 天第 3 项：“画出 HPL 的分块 LU → BLAS 计算与面板通信，以及 HPCG 的 SpMV / SymGS / 多重网格 / MPI halo 流程，并在笔记中写出文件名与函数名”。

所有路径均相对于源码根：`~/asc-week1/src/hpl-2.3/` 与 `~/asc-week1/src/hpcg/`。

---

## 1. HPL

### 1.1 它在解什么

解稠密线性方程组 `A x = b`：

- `A` 是 N×N 的双精度矩阵（例如 N = 11520）
- HPL 把 `b` 作为矩阵的**第 N+1 列**一起存，所以实际生成的是 N×(N+1) 的矩阵
- 解法是**带部分选主元的 LU 分解 + 回代**：先把 A 拆成下三角 L 与上三角 U，再解 `Ly = b`、`Ux = y`

运算量约 `2/3·N³` 次浮点运算（HPL 报成绩时用的是 `2/3·N³ + 2·N²`）。N 翻倍，运算量变 8 倍。

### 1.2 调用链（从 main 到 BLAS）

```
testing/ptest/HPL_pdtest.c:53          HPL_pdtest        测试驱动
 ├─ HPL_grid_init()                    src/grid/HPL_grid_init.c   建立 P×Q 进程网格
 ├─ HPL_pdmatgen()                     src/pmatgen/HPL_pdmatgen.c 生成随机矩阵 [A | b]
 ├─ HPL_wtime()                        计时开始
 ├─ HPL_pdgesv()                       src/pgesv/HPL_pdgesv.c:53  LU 分解 + 回代
 ├─ HPL_wtime()                        计时结束 → Gflops = (2/3N³ + 2N²)/time
 └─ HPL_pdlange()                      计算 ||A||₁ ||A||∞ ||x||∞ ||b||∞ → 残差
```

`HPL_pdgesv` 内部（`src/pgesv/HPL_pdgesv.c:99-112`）：

```
A->info = 0
  ├─ depth == 1 → HPL_pdgesv0()        src/pgesv/HPL_pdgesv0.c    单层面板
  └─ depth  > 1 → HPL_pdgesvK1/K2()    src/pgesv/HPL_pdgesvK1.c / K2.c   面板流水线（depth 层预取）
最后 → HPL_pdtrsv()                     src/pgesv/HPL_pdtrsv.c     回代求 x
```

### 1.3 分块 LU 的每一步：哪步是计算、哪步是通信

`src/pgesv/HPL_pdgesv0.c:126` 是主循环：

```c
for( j = 0; j < N; j += nb )      /* 每次处理一个宽 nb 的列块 */
```

每一轮做四件事：

| 步骤 | 函数 | 文件 | 性质 |
|---|---|---|---|
| ① 行交换 | `HPL_pdlaswp00N` / `HPL_pdlaswp01N` | `src/pgesv/HPL_pdlaswp00N.c` | **通信**（列块沿进程行广播）+ 访存 |
| ② 面板三角求解 | `HPL_pdtrsv` | `src/pgesv/HPL_pdtrsv.c` | **通信**（列方向）→ 计算 |
| ③ 面板分发 | `HPL_pdpanel_disp` | `src/panel/HPL_pdpanel_disp.c` | **纯通信**：把当前面板沿进程网格的行、列方向点对点发出 |
| ④ 尾块更新 | `HPL_pdupdateNN` → `HPL_dgemm` → `cblas_dgemm` | `src/pgesv/HPL_pdupdateNN.c`、`src/blas/HPL_dgemm.c:271` | **纯计算**：`A22 -= A21 · A12` |

第 ④ 步就是那个“99% 时间”所在：`HPL_dgemm`（`src/blas/HPL_dgemm.c:410`）直接调 `cblas_dgemm`，真正的浮点运算全在 OpenBLAS 里。HPL 自己只负责切块、排布、通信。

**为什么这么设计对性能有利**：`A22 -= A21·A12` 是矩阵乘矩阵，一个 192×192 的小块被反复复用几百次，命中 L2/L3 缓存，CPU 的 FMA 单元能一直有活干——这叫“计算密集”，瓶颈在浮点单元而不是内存。

### 1.4 计时与验证

- **计时**：`HPL_pdtest` 里用 `HPL_wtime()` 包住 `HPL_pdgesv`，只算分解+回代，不含矩阵生成
- **验证**：分解完用 `HPL_pdlange`（`‖·‖₁`、`‖·‖∞`）算出 `||A||`、`||x||`、`||b||`，然后

```
resid = ||Ax - b||∞ / (eps · (||A||∞·||x||∞ + ||b||∞) · N)
```

判据是 `resid < 16`。日志里那行 `3.59214136e-03 ...... PASSED` 就是它。这一步很关键：MPI 配错、内存踩了，程序可能照样 `exit 0`，但残差会炸成 `FAILED`。

---

## 2. HPCG

### 2.1 它在解什么

同样解 `A x = b`，但：

- `A` 是**稀疏**矩阵——来自三维 27 点差分格式（每个网格点只与周围 26 个邻居相关），绝大部分元素是 0
- 解法是**共轭梯度法（CG）**，用**多重网格（MG）**做预条件

它不追求浮点峰值，而是模拟真实科学计算（CFD、结构力学）的访存模式。

### 2.2 调用链

```
src/main.cpp:122     GenerateGeometry()   把 nx×ny×nz 的全局网格切成 npx×npy×npz 的进程块
src/main.cpp:138     SetupHalo()          建立每个 rank 的 halo 收发索引（邻居、数量、位移）
                     GenerateProblem()    生成 27 点稀疏矩阵 + 已知解
                     OptimizeProblem()    数据重排（本仓库为参考实现，基本是空操作）
src/main.cpp:284     CG(...)              优化版：计时并记录分项时间
src/main.cpp:337     CG(...)              参考版
src/main.cpp:360     ReportResults()      汇总 → 写 HPCG-Benchmark_*.txt
```

### 2.3 一次 CG 迭代里都在调什么

`src/CG.cpp:87-123`，每个 kernel 都用 `TICK()/TOCK()` 单独计时（`src/CG.cpp:36-37`）：

| 顺序 | 调用 | 数学含义 | 时间桶 |
|---|---|---|---|
| 1 | `ComputeSPMV(A, p, Ap)` | `Ap = A·p` | `times[3]` SpMV |
| 2 | `ComputeWAXPBY(1.0, b, -1.0, Ap, r)` | `r = b - Ap` | `times[2]` WAXPBY |
| 3 | `ComputeDotProduct(r, r, normr)` | 内积（含 `MPI_Allreduce` 全局归约） | `times[1]` DDOT |
| 4 | `ComputeMG(A, r, z)` | `z = M⁻¹r`，多重网格预条件 | `times[5]` MG |
| 5 | `ComputeDotProduct(r, z, rtz)` | 内积 | `times[1]` |
| 6 | `ComputeWAXPBY(1.0, z, beta, p, p)` | `p = βp + z` | `times[2]` |
| 7 | `ComputeSPMV(A, p, Ap)` | `Ap = A·p` | `times[3]` |
| 8 | `ComputeDotProduct(p, Ap, pAp)` | `α = p'Ap` | `times[1]` |
| 9 | `ComputeWAXPBY(1.0, x, alpha, p, x)` | `x += αp` | `times[2]` |
| 10 | `ComputeWAXPBY(1.0, r, -alpha, Ap, r)` | `r -= αAp` | `times[2]` |
| 11 | `ComputeDotProduct(r, r, normr)` | 收敛判据 | `times[1]` |

`ComputeSPMV`（`src/ComputeSPMV.cpp`）是核心：遍历每一行的非零元 `A.matrixValues[i]` 与 `x[col]` 相乘累加。**每读一个 double（8 字节）只做 2 次浮点运算**，而 HPL 的 `dgemm` 每读一个数能做几十次——这就是两者成绩差 30 倍的根源。

### 2.4 多重网格（`src/ComputeMG.cpp`）

`ComputeMG` 不是一次乘法，而是一个递归过程：

```
ComputeMG(A, r, z)
 ├─ ComputeSYMGS(A, r, z)        对称 Gauss-Seidel：前扫一遍、后扫一遍（光滑）
 ├─ ComputeResidual → 限制到粗网格（ComputeRestriction_ref）
 ├─ 若还有更粗的层：递归调用 ComputeMG（粗网格层数 = numberOfMgLevels，通常约 log 级）
 └─ ComputeProlongation_ref      插值回细网格，修正
```

`ComputeSYMGS`（`src/ComputeSYMGS.cpp`）是逐点顺序扫描，**天然串行**、难以并行，且每个 rank 的边界点需要邻居的数据——所以它是 HPCG 里最慢的一环之一，也是 halo 通信发生的地方。

### 2.5 halo 通信（`src/ExchangeHalo.cpp:72`）

三维区域分解后，每个 rank 只持有自己那块的网格。做 SymGS 和 SpMV 时，边界点要用到邻居 rank 的数据，这些“影子层”叫 halo。

实现是标准非阻塞点对点：

```c
MPI_Irecv(x_external, n_recv, MPI_DOUBLE, neighbors[i], MPI_MY_TAG, MPI_COMM_WORLD, request+i);
...
MPI_Isend(x_external, n_send, MPI_DOUBLE, neighbors[i], MPI_MY_TAG, MPI_COMM_WORLD, request+...);
MPI_Waitall(...)
```

先发所有 recv（不阻塞），再发所有 send，最后 `Waitall` 统一等——这样收发能重叠，比“发一个等一个”快。

### 2.6 计时与报告（`src/ReportResults.cpp`）

- `:322-328` 写 `Benchmark Time Summary`：`DDOT`、`WAXPBY`、`SpMV`、`MG`、`Optimization phase`、`Total`
- `:352-373` 写 `Final Summary`：把十组 50 次迭代的浮点总量除以总时间，得到 **GFLOP/s rating**

那句 `Final Summary::HPCG result is VALID with a GFLOP/s rating of=4.50957` 就是结果。同一份报告里 `Raw Total=4.64693` 是“只算纯迭代”的瞬时速率，**rating 才是官方认可的成绩**——因为它把收敛过程和数据结构的优化开销都摊进去了。

---

## 3. 两者的本质区别

| 维度 | HPL | HPCG |
|---|---|---|
| 矩阵 | 稠密 N×N（8·N² 字节） | 稀疏，27 点 stencil（约 27·N 个非零元） |
| 核心操作 | `dgemm` 矩阵乘矩阵 | `SpMV` 稀疏矩阵乘向量 |
| 运算/访存比 | 高（数据在缓存里复用几百次） | 极低（每个元素读一次、用一次） |
| 瓶颈 | CPU 浮点单元 | **内存带宽** |
| 并行性 | 好（大块矩阵可任意切分） | 差（SymGS 逐点顺序、halo 同步） |
| 本机成绩 | 192 GFLOPS（4 ranks） | 6.5 GFLOP/s（4 ranks） |
| 比值 | — | 约为 HPL 的 1/30 |

**记住这个 1/30**：它不是 bug，是“计算密集”与“访存密集”的差距。真实应用（流体、结构）大多更接近 HPCG 那一端。

---

## 4. rank、线程、节点、进程网格

第 1 天验收要求能解释这四个词的区别：

| 概念 | 含义 | 我们的取值 |
|---|---|---|
| **节点**（node） | 一台物理机 | 1（WSL2 就是一台“虚拟机节点”） |
| **rank** | 一个 MPI 进程，独立内存空间，靠收发消息协作 | 冒烟 1，基线 4 |
| **线程**（thread） | OpenMP 线程，同一进程内共享内存 | 全程 1（纯 MPI） |
| **进程网格**（P×Q） | rank 在 2D 拓扑上的排布，决定谁和谁通信 | 冒烟 1×1，基线 2×2 |

关系：`ranks = 节点数 × 每节点 rank 数`，且 `P × Q = ranks`。启动命令 `mpirun -np 4 ./xhpl` 里的 `-np 4` 就是 rank 数。

线程与 rank 的取舍：`ranks × THREADS ≤ 物理核数`。本机 12 物理核 / 24 逻辑核，所以 4 ranks × 1 线程是很保守的配置，第 3、4 天可以往 8 ranks 或 4 ranks × 2 线程推。
