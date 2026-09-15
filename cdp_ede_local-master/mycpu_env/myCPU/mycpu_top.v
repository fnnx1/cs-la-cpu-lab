`include "mycpu_head.v"

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

    // 原本这里是用的再延迟一级，感觉没必要，改成组合逻辑
    // 其他地方的“可用”也应该相应改成组合逻辑同步延迟
    wire valid = ~reset;

    IF_stage u_IF_stage(
        .clk            (clk            ),
        .reset          (reset          ),
        .ds_allowin     (ds_allowin     ),
        .br_bus         (br_bus         ),
        .fs_to_ds_valid (fs_to_ds_valid ),
        .fs_to_ds_bus   (fs_to_ds_bus   ),
        .inst_sram_en   (inst_sram_en   ),
        .inst_sram_we   (inst_sram_we   ),
        .inst_sram_addr (inst_sram_addr ),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata)
    );



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

    wire vaild = ~reset;

    assign data_sram_we    = mem_we && valid;
    assign data_sram_addr  = alu_result >> 2;
    assign data_sram_wdata = rkd_value >> 2;

    assign data_sram_en    = (mem_we || res_from_mem) && valid;

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
