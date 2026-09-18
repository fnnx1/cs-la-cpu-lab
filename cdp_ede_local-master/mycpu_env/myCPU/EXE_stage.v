`include "mycpu_head.v"

module EXE_stage(
    input wire clk,
    input wire reset,
    input wire ms_allowin,
    output wire es_allowin,
    input wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus,
    output wire es_to_ms_valid,
    output wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus
);
    wire [11:0] alu_op;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        src2_is_4;
    wire        gr_we;
    wire        mem_we;
    wire [ 4:0] dest;
    wire [31:0] imm;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] ds_pc;
    wire        res_from_mem;

    assign {
        alu_op,//12
        src1_is_pc,//1
        src2_is_imm,//1
        src2_is_4,//1
        gr_we,//1
        mem_we,//1
        dest,//5
        imm,//32
        rj_value,//32
        rkd_value,//32
        ds_pc,//32
        res_from_mem//1
    } = ds_to_es_bus;




    assign rj_eq_rd = (rj_value == rkd_value);

    assign alu_src1 = src1_is_pc  ? pc[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;

    alu u_alu(
        .alu_op     (alu_op    ),
        .alu_src1   (alu_src1  ),
        .alu_src2   (alu_src2  ),
        .alu_result (alu_result)
    );

    assign mem_result   = data_sram_rdata >> byte_off;   // 读回数据对齐到最低字节(扩展留给WB)
    assign final_result = res_from_mem ? mem_result : alu_result;

endmodule
