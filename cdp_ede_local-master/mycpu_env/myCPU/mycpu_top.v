module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_we,
    output wire [ 3:0] inst_srame_en,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_we,
    output wire [ 3:0] data_sram_en,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    reg reset;
    // 统一时钟上沿采样
    always @(posedge clk) reset <= ~resetn;

    reg valid; // 数据有效，reset
    always @(posedge clk) begin
        // 同样统一时钟上沿采样
        // reset信号有效时，valid置0，表示这个周期完成刷新操作，数据无效
        // 其余地方的重置逻辑也应该在时钟上沿采样，保证整个设计的同步性
        if (reset) begin
            valid <= 1'b0;
        end
        else begin
            valid <= 1'b1;
        end
    end


    assign imm = src2_is_4 ? 32'h4                      :
                need_si20 ? {i20[19:0], 12'b0}         :
    /*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                {{14{i16[15]}}, i16[15:0], 2'b0} ;

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

    assign src1_is_pc    = inst_jirl | inst_bl;

    assign src2_is_imm   = inst_slli_w |
                        inst_srli_w |
                        inst_srai_w |
                        inst_addi_w |
                        inst_ld_w   |
                        inst_st_w   |
                        inst_lu12i_w|
                        inst_jirl   |
                        inst_bl     ;

    assign res_from_mem  = inst_ld_w;
    assign dst_is_r1     = inst_bl;
    assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b & ~inst_bl;
    assign mem_we        = inst_st_w;
    assign dest          = dst_is_r1 ? 5'd1 : rd;

    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd :rk;
    regfile u_regfile(
        .clk    (clk      ),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (rf_we    ),
        .waddr  (rf_waddr ),
        .wdata  (rf_wdata )
        );

    assign rj_value  = rf_rdata1;
    assign rkd_value = rf_rdata2;

    assign rj_eq_rd = (rj_value == rkd_value);
    assign br_taken = (   inst_beq  &&  rj_eq_rd
                    || inst_bne  && !rj_eq_rd
                    || inst_jirl
                    || inst_bl
                    || inst_b
                    ) && valid;
    assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc + br_offs) :
                                                    /*inst_jirl*/ (rj_value + jirl_offs);

    assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;

    alu u_alu(
        .alu_op     (alu_op    ),
        .alu_src1   (alu_src1  ),
        .alu_src2   (alu_src2  ),
        .alu_result (alu_result)
        );

    assign data_sram_we    = mem_we && valid;
    assign data_sram_addr  = alu_result >> 2;
    assign data_sram_wdata = rkd_value >> 2;

    assign data_sram_en    = (mem_we || res_from_mem) && ;

    assign mem_result   = data_sram_rdata;
    assign final_result = res_from_mem ? mem_result : alu_result;

    assign rf_we    = gr_we && valid;
    assign rf_waddr = dest;
    assign rf_wdata = final_result;

    // debug info generate
    assign debug_wb_pc       = pc;
    assign debug_wb_rf_wen   = {4{rf_we}};
    assign debug_wb_rf_wnum  = dest;
    assign debug_wb_rf_wdata = final_result;

endmodule
