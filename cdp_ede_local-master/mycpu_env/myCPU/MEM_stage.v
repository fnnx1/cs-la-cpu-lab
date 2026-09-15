`include "mycpu_head.v"

module MEM_stage(
    input wire clk,
    input wire reset,
    input wire ds_allowin,
    input wire [`BR_BUS_WD-1:0] br_bus,
    output wire fs_to_ds_valid,
    output wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus,
    // inst sram interface
    output wire inst_sram_en,
    output wire [3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input wire [31:0] inst_sram_rdata
);

endmodule