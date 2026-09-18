`include "mycpu_head.v"

module MEM_stage(
    input wire clk,
    input wire reset,
    input wire ms_allowin,
    output wire ms_to_ws_valid,
    output wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    // data sram interface
    output wire data_sram_en,
    output wire [3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input wire [31:0] data_sram_rdata
);

endmodule
