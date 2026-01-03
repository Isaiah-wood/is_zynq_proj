module Solomon (
    input wire clk  ,
    input wire rst_n,
    input wire start
);
    VecRoll #(
        .OBS_VEC_NUM(49 ),
        .NAV_VEC_NUM(539)
    ) u_vecroll (
        .clk        (clk               ),
        .rst_n      (rst_n             ),
        .start      (start             ),
        .out_valid  (vecroll_out_valid ),
        .next_ready (vecroll_next_ready),
        .navvec_addr(navvec_araddr     ),
        .obsvec_addr(obsvec_araddr     )
    );

    wire navvec_arvalid = vecroll_out_valid;
    wire obsvec_arvalid = vecroll_out_valid;
    VROM #(
        .ROM_DEPTH (15486                ),
        .DATA_WIDTH(1100                 ),
        .INIT_FILE ("./data/lib_vecs.mem")
    ) u_rom_nav (
        .clk    (clk           ),
        .rst_n  (rst_n         ),
        .arvalid(navvec_arvalid),
        .araddr (navvec_araddr ),
        .rvalid (navvec_rvalid ),
        .rready (navvec_rready ),
        .rdata  (navvec        )
    );
    VROM #(
        .ROM_DEPTH (49                   ),
        .DATA_WIDTH(1100                 ),
        .INIT_FILE ("./data/img_vecs.mem")
    ) u_rom_obs (
        .clk    (clk           ),
        .rst_n  (rst_n         ),
        .arvalid(obsvec_arvalid),
        .araddr (obsvec_araddr ),
        .rvalid (obsvec_rvalid ),
        .rready (obsvec_rready ),
        .rdata  (obsvec        )
    );

    assign vecroll_next_ready = navvec_rready & obsvec_rready;

    VecMatch #(.VEC_WIDTH(1100)) u_vecmatch (
        .clk        (clk                ),
        .rst_n      (rst_n              ),
        .img_vec    (obsvec             ),
        .lib_vec    (navvec             ),
        .in_valid   (vecmatch_in_valid  ),
        .this_ready (vecmatch_this_ready),
        .out_valid  (vecmatch_out_valid ),
        .next_ready (vecmatch_next_ready),
        .match_count(match_count        )
    );

    assign vecmatch_in_valid = obsvec_rvalid & navvec_rvalid;
    assign obsvec_rready     = vecmatch_this_ready;
    assign navvec_rready     = vecmatch_this_ready;








endmodule