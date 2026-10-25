//! sram to axi bridge

module sram_axi_bridge(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    input  wire        inst_sram_req,
    input  wire        inst_sram_wr,
    input  wire [1:0]  inst_sram_size,
    input  wire [3:0]  inst_sram_wstrb,
    input  wire [31:0] inst_sram_addr,
    input  wire [31:0] inst_sram_wdata,
    output  wire        inst_sram_addr_ok,
    output  wire        inst_sram_data_ok,
    output  wire [31:0] inst_sram_rdata,
    // data sram interface
    input wire        data_sram_req,
    input wire        data_sram_wr,
    input wire [1:0]  data_sram_size,
    input wire [3:0]  data_sram_wstrb,
    input wire [31:0] data_sram_addr,
    input wire [31:0] data_sram_wdata,
    output  wire        data_sram_addr_ok,
    output  wire        data_sram_data_ok,
    output  wire [31:0] data_sram_rdata,

    ////////////////////////////////////////////

    // AXI read address channel (master -> slave)
    output wire [3 :0] arid,
    output wire [31:0] araddr,
    output wire [7 :0] arlen,
    output wire [2 :0] arsize,
    output wire [1 :0] arburst,
    output wire [1 :0] arlock,
    output wire [3 :0] arcache,
    output wire [2 :0] arprot,
    output wire        arvalid,
    input  wire        arready,

    // AXI read data channel (slave -> master)
    input  wire [3 :0] rid,
    input  wire [31:0] rdata,
    input  wire [1 :0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    // AXI write address channel (master -> slave)
    output wire [3 :0] awid,
    output wire [31:0] awaddr,
    output wire [7 :0] awlen,
    output wire [2 :0] awsize,
    output wire [1 :0] awburst,
    output wire [1 :0] awlock,
    output wire [3 :0] awcache,
    output wire [2 :0] awprot,
    output wire        awvalid,
    input  wire        awready,

    // AXI write data channel (master -> slave)
    output wire [3 :0] wid,
    output wire [31:0] wdata,
    output wire [3 :0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    // AXI write response channel (slave -> master)
    input  wire [3 :0] bid,
    input  wire [1 :0] bresp,
    input  wire        bvalid,
    output wire        bready
);



endmodule
