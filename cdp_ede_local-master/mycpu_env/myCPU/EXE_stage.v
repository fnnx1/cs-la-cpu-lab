`include "mycpu_head.v"

module EXE_stage(
    input wire clk,
    input wire reset,
    input wire ms_allowin,
    output wire es_allowin,
    input wire ds_to_es_valid,
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

    reg [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus_r;
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
    } = ds_to_es_bus_r;

    wire [31:0] alu_src1 = src1_is_pc? ds_pc : rj_value;
    wire [31:0] alu_src2 = src2_is_imm? imm : rkd_value;
    wire [31:0] alu_result;

    alu u_alu(
        .alu_op     (alu_op    ),
        .alu_src1   (alu_src1  ),
        .alu_src2   (alu_src2  ),
        .alu_result (alu_result)
    );

    wire [`ES_TO_MS_BUS_WD-1:0] to_es_to_ms_bus = {
        alu_result, // 32
        rkd_value, // 32
        res_from_mem, // 1
        mem_we, // 1
        gr_we, // 1
        dest, // 5
        ds_pc // 32
    };

    wire es_ready_go = 1; // 数据已经准备好
    reg es_valid; // 本级用到的数据可用

    assign es_to_ms_valid = es_valid && es_ready_go; // 传给下一级的数据是有效的
    assign es_allowin = !es_valid || es_ready_go && ms_allowin;

    always @(posedge clk) begin
        if (reset) begin
            es_valid <= 0;
        end else if (es_allowin) begin
            es_valid <= ds_to_es_valid;
        end
        if (ds_to_es_valid && es_allowin) begin
            ds_to_es_bus_r <= ds_to_es_bus;
        end
    end

    assign es_to_ms_bus = to_es_to_ms_bus;


endmodule
