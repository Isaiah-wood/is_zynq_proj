## 模块 AdderTree
**参数:** `parameter integer LEAF_NUM = `CFG_ADDER_TREE_LEAF_NUM,  // 操作数个数         parameter integer MAXVAL   = `CFG_LUT_IN_WIDTH,         // 单个操作数最大可能值（用于求和位宽）         parameter integer INW      = `CFG_LUT_OUT_WIDTH,         parameter integer IN_WIDTH = LEAF_NUM*INW,         // parameter integer OUT_WIDTH = `CFG_VEC_POPCOUNT_WIDTH         parameter integer OUT_WIDTH = $clog2(LEAF_NUM*MAXVAL+1)`

| 端口方向 | 端口名 |
| --- | --- |
| input | wire |
| input | wire |
| input | wire |
| input | wire |
| output | wire |
| output | wire |
| output | wire |
| input | wire |
