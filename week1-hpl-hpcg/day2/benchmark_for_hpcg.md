# HPCG 基准测试报告

- **版本 (Version)**：3.1
- **发布日期 (Release date)**：2019年3月28日

## 一、 机器与问题规模摘要 (Machine & Problem Summary)

### 1. 机器配置

- **分布式进程数 (Distributed Processes)**：4
- **每个进程的线程数 (Threads per processes)**：1

### 2. 全局问题维度 (Global Problem Dimensions)

- **全局网格 X 向 (Global nx)**：128
- **全局网格 Y 向 (Global ny)**：128
- **全局网格 Z 向 (Global nz)**：64

### 3. 进程网格维度 (Processor Dimensions)

- **X 向进程数 (npx)**：2
- **Y 向进程数 (npy)**：2
- **Z 向进程数 (npz)**：1

### 4. 本地域维度 (Local Domain Dimensions)

- **本地网格 X 向 (nx)**：64
- **本地网格 Y 向 (ny)**：64
- **本地网格 Z 向 (nz)**：64
- **Z 向进程上下界 (ipz)**：底层 `0`，顶层 `0`

## 二、 问题摘要 (Problem Summary)

### 1. 设置信息 (Setup Information)

- **设置耗时 (Setup Time)**：0.417636 秒

### 2. 线性系统信息 (Linear System Information)

- **方程总数 (Number of Equations)**：1,048,576
- **非零元素总数 (Number of Nonzero Terms)**：27,725,560

### 3. 多重网格信息 (Multigrid Information)

- **粗网格层数 (Number of coarse grid levels)**：3
  - **网格级别 1 (Grid Level 1)**：
    - 方程数：131,072 | 非零元素数：3,393,400
    - 预平滑步数：1 | 后平滑步数：1
  - **网格级别 2 (Grid Level 2)**：
    - 方程数：16,384 | 非零元素数：406,456
    - 预平滑步数：1 | 后平滑步数：1
  - **网格级别 3 (Grid Level 3)**：
    - 方程数：2,048 | 非零元素数：46,552
    - 预平滑步数：1 | 后平滑步数：1

## 三、 内存使用摘要 (Memory Use Summary)

- **数据总内存消耗 (Total memory used for data)**：0.750145 Gbytes
- **优化问题数据内存 (Memory used for OptimizeProblem data)**：0 Gbytes
- **每个方程字节数 (Bytes per equation)**：715.394 字节
- **线性系统与 CG 求解内存 (Memory used for linear system and CG)**：0.660083 Gbytes
- **粗网格内存消耗**：
  - 网格级别 1：0.0789329 Gbytes
  - 网格级别 2：0.00988744 Gbytes
  - 网格级别 3：0.00124171 Gbytes

## 四、 验证与确认测试摘要 (V&V Testing Summary)

### 1. 谱收敛测试 (Spectral Convergence Tests)

- **测试结果**：**通过 (PASSED)**
- **非预条件 (Unpreconditioned)**：最大迭代次数 11（预期 12）
- **预条件 (Preconditioned)**：最大迭代次数 2（预期 2）

### 2. 对称性偏离检查 (Departure from Symmetry)

- **计算公式**：$\frac{\vert{}x'Ay - y'Ax\vert{}}{2 \cdot \Vert{}x\Vert{} \cdot \Vert{}A\Vert{} \cdot \Vert{}y\Vert{} \cdot \epsilon}$
- **测试结果**：**通过 (PASSED)**
- **SpMV 偏离值**：$2.30762 \times 10^{-7}$
- **MG 偏离值**：$1.24645 \times 10^{-7}$

## 五、 迭代摘要 (Iterations Summary)

- **迭代次数信息结果**：**通过 (PASSED)**
- **每组参考 CG 迭代次数**：50
- **每组优化 CG 迭代次数**：50
- **参考迭代总次数**：850
- **优化迭代总次数**：850

## 六、 可复现性摘要 (Reproducibility Summary)

- **可复现性结果**：**通过 (PASSED)**
- **缩放残差均值**：$7.35709 \times 10^{-8}$
- **缩放残差方差**：0

## 七、 性能摘要 (Performance Summary)

### 1. 基准测试耗时摘要（单位：秒）

- **优化阶段 (Optimization phase)**：$1.8 \times 10^{-7}$ 秒
- **DDOT（向量点积）**：2.60965 秒
- **WAXPBY（向量更新）**：1.00758 秒
- **SpMV（稀疏矩阵向量乘法）**：8.80928 秒
- **MG（多重网格）**：50.7173 秒
- **总耗时 (Total)**：63.1482 秒

### 2. 浮点运算次数摘要 (Floating Point Operations Summary)

- **原始 DDOT**：$5.38339 \times 10^9$ FLOPs
- **原始 WAXPBY**：$5.38339 \times 10^9$ FLOPs
- **原始 SpMV**：$4.80761 \times 10^{10}$ FLOPs
- **原始 MG**：$2.68124 \times 10^{11}$ FLOPs
- **总计**：$3.26967 \times 10^{11}$ FLOPs
- **包含收敛开销的总计**：$3.26967 \times 10^{11}$ FLOPs

### 3. 内存带宽摘要 (GB/s Summary)

- **原始读取带宽 (Raw Read B/W)**：31.9094 GB/s
- **原始写入带宽 (Raw Write B/W)**：7.3747 GB/s
- **原始总带宽 (Raw Total B/W)**：39.2841 GB/s
- **包含收敛与优化阶段开销的总带宽**：38.8473 GB/s

### 4. 浮点性能摘要 (GFLOP/s Summary)

- **原始 DDOT 性能**：2.06288 GFLOP/s
- **原始 WAXPBY 性能**：5.34287 GFLOP/s
- **原始 SpMV 性能**：5.45744 GFLOP/s
- **原始 MG 性能**：5.28665 GFLOP/s
- **原始总性能**：5.17777 GFLOP/s
- **包含收敛开销的总性能**：5.17777 GFLOP/s
- **包含收敛与优化阶段开销的总性能**：5.12021 GFLOP/s

## 八、 其他系统指标

- **用户优化开销**：
  - 优化阶段耗时：$1.8 \times 10^{-7}$ 秒
  - 优化阶段耗时与参考 SpMV+MG 耗时之比：$2.45869 \times 10^{-6}$
- **DDOT 耗时变异**：
  - 最小 DDOT MPI_Allreduce 耗时：1.92688 秒
  - 最大 DDOT MPI_Allreduce 耗时：2.04989 秒
  - 平均 DDOT MPI_Allreduce 耗时：1.96533 秒

## 九、 最终总结 (Final Summary)

- **HPCG 测试结果有效性**：**有效 (VALID)**，评级为 **5.12021 GFLOP/s**
- **出于历史原因的 HPCG 2.4 评级**：5.17777 GFLOP/s
- **警告提示**：
  - 使用了参考版本的 `ComputeDotProduct`，性能极可能是次优的 (suboptimal)。
  - 使用了参考版本的 `ComputeSPMV`，性能极可能是次优的。
  - 使用了参考版本的 `ComputeMG`，性能极可能是次优的。
  - 使用了参考版本的 `ComputeWAXPBY`，性能极可能是次优的。
- **执行时间状态**：结果有效，但实际运行时间为 **63.1482 秒**。
- **官方要求提示**：官方正式结果的执行时间**必须至少达到 1800 秒**。