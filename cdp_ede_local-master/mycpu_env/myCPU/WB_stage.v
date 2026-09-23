`include "mycpu_head.v"

module WB_stage(
    input wire clk,
    input wire reset,
    //allowin
    input wire rf_allowin,
    output wire ws_allowin,
    input wire ms_to_ws_valid,
    output wire ws_to_rf_valid,
    input wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    output wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus,
    // data sram interface
    input wire [31:0] data_sram_rdata,
    // block bus
    input wire [`BLOCK_BUS_WD-1:0] block_bus
);

    wire [31:0] alu_result;
    wire        res_from_mem;
    wire        gr_we;
    wire [4:0]  dest;
    wire [31:0] pc;

    reg [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus_r;

    assign {
        alu_result, // 32，MEM 级 alu 结果
        res_from_mem, // 1，是否需要从数据 RAM 取数
        gr_we, // 1
        dest, // 5
        pc // 32
    } = ms_to_ws_bus_r;

    wire [31:0] final_result = res_from_mem ? data_sram_rdata : alu_result;


    wire ws_ready_go = 1;
    reg ws_valid;
    assign ws_allowin = !ws_valid || ws_ready_go && rf_allowin;
    assign ws_to_rf_valid = ws_valid && ws_ready_go;

    assign ws_to_rf_bus = {
        final_result,// 32
        gr_we && ws_valid, // 1
        dest, // 5
        pc // 32
    };

    always @(posedge clk) begin
        if (reset) begin
            ws_valid <= 1'b0;
        end else if (ws_allowin) begin
            ws_valid <= ms_to_ws_valid;
        end
        if (ms_to_ws_valid && ws_allowin) begin
            ms_to_ws_bus_r <= ms_to_ws_bus;
        end
    end
    assign block_bus = ws_valid ? dest : 0;
endmodule
