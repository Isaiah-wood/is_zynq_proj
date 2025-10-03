// 参数头文件
`ifndef CONFIG_VH
`define CONFIG_VH



// data config
`define CFG_IMG_VEC_NUM 49
`define CFG_LIB_VEC_NUM 539
`define CFG_VEC_WIDTH 1200
`define CFG_COEFF_WIDTH 24
`define CFG_VEC_POPCOUNT_WIDTH ($clog2(1200 + 1))          // 11

// data file paths
`define CFG_IMG_VEC_FILE "dat/is_PatImg.dat"
`define CFG_LIB_VEC_FILE "dat/is_PatLib.dat"
`define CFG_LIB_COEFF_FILE "dat/is_CoeffLib.dat"
`define CFG_ZONE_LIB_FILE "dat/is_ZoneLib.dat"
`define CFP_STAR_LIB_FILE "dat/is_StarLib.dat"

`define CFG_MATCHMAT_FILE "dat/is_MatchMat.dat"


// LookupTable and AdderTree
`define CFG_LUT_IN_WIDTH 6
`define CFG_LUT_OUT_WIDTH ($clog2(`CFG_LUT_IN_WIDTH + 1))         // 3

`define CFG_ADDER_TREE_LEAF_NUM ((1200 + `CFG_LUT_IN_WIDTH - 1) / `CFG_LUT_IN_WIDTH)            // 200

// latency
`define CFG_ROM_LATENCY 1
`define CFG_POPCOUNT_LATENCY ($clog2(`CFG_ADDER_TREE_LEAF_NUM) + 1)         // 9





// zone config
`define CFG_ZONE_NUM 92




















`endif