`include "mycpu_head.v"

module MEM_stage(
    input wire clk,
    input wire reset,
    input wire ws_allowin,
    output wire ms_allowin,
    input wire es_to_ms_valid,
    output wire ms_to_ws_valid,
    input wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus,
    output wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    // data sram interface
    output wire data_sram_en,
    output wire [3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire [`BLOCK_BUS_WD-1:0] block_bus
);

    wire [31:0] alu_result;
    wire [31:0] rkd_value;
    wire [31:0] pc;
    wire res_from_mem;
    wire mem_we;
    wire gr_we;
    wire [4:0] dest;

    reg [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus_r;


    assign {
        alu_result,
        rkd_value,
        res_from_mem,
        mem_we,
        gr_we,
        dest,
        pc
    } =  es_to_ms_bus_r;

    reg ms_valid;


    wire [`MS_TO_WS_BUS_WD-1:0] to_ms_to_ws_bus ={
        alu_result, // 32
        res_from_mem, // 1
        gr_we, // 1
        dest, // 5
        pc // 32
    };

    wire ms_ready_go = 1;
    assign ms_allowin = !ms_valid || ms_ready_go && ws_allowin;
    assign ms_to_ws_valid = ms_valid && ms_ready_go;

    assign data_sram_we = (ms_to_ws_valid && ws_allowin && mem_we) ? 4'b1111 : 4'b0000;
    assign data_sram_en = ms_to_ws_valid && ws_allowin && (mem_we | res_from_mem);
    assign data_sram_addr = alu_result;
    assign data_sram_wdata = rkd_value;

    always @(posedge clk) begin
        if (reset) begin
            ms_valid <= 0;
        end else if (ms_allowin) begin
            ms_valid <= es_to_ms_valid;
        end
        if (es_to_ms_valid && ms_allowin) begin
            es_to_ms_bus_r <= es_to_ms_bus;
        end
    end

    // 本级组合输出总线，由 WB 级寄存并完成 load 数据选择
    assign ms_to_ws_bus = to_ms_to_ws_bus;

    wire [31:0] data_to_rf = res_from_mem ? rkd_value : alu_result;
    wire data_valid = !(mem_we || res_from_mem); // 需要写回寄存器堆，并且数据不来自访存阶段
    assign block_bus = ms_valid ? {gr_we, dest, data_valid, data_to_rf} : `BLOCK_BUS_WD'b0;
endmodule
