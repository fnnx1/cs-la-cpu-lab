`include "mycpu_defines.vh"

module WB_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    output wire        ws_allowin,  //该阶段是否可以接收数据(最后一级, 恒为1)
    //from ms stage
    input  wire        ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD -1 :0] ms_to_ws_bus,  //上一级缓冲区
    //to rf :write back
    output wire [`WS_TO_RF_BUS_WD -1 :0] ws_to_rf_bus,  //写回缓冲区
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    input  wire [31:0] data_sram_rdata  //访存数据
);
    reg ws_valid;
    reg [`MS_TO_WS_BUS_WD -1 :0] ms_to_ws_bus_r;
    wire ws_ready_go;

    wire [7:0] sram_rdata_byte0, sram_rdata_byte1, sram_rdata_byte2, sram_rdata_byte3;  //字节选
    wire [15:0] sram_rdata_half0, sram_rdata_half1;  //半字选
    wire [7:0] sram_rdata_byte;
    wire [15:0] sram_rdata_half;
    wire [1:0] mem_size , mem_addr_offset;  //内存访问的大小和地址偏移量

    wire load_signed;   //是否要符号扩展

    wire [31:0] sram_rdata;

    assign ws_ready_go     = 1'b1;
    //最后一级, 没有下游 allowin
    assign ws_allowin      = !ws_valid || ws_ready_go;
    assign mem_size = ms_to_ws_bus_r[73:72];
    assign mem_addr_offset = ms_to_ws_bus_r[76:75];

    assign load_signed = ms_to_ws_bus_r[74];

    assign sram_rdata_byte0 = data_sram_rdata[7:0];
    assign sram_rdata_byte1 = data_sram_rdata[15:8];
    assign sram_rdata_byte2 = data_sram_rdata[23:16];
    assign sram_rdata_byte3 = data_sram_rdata[31:24];
    assign sram_rdata_half0 = data_sram_rdata[15:0];
    assign sram_rdata_half1 = data_sram_rdata[31:16];

    assign sram_rdata_byte = mem_addr_offset == 2'b00 ? sram_rdata_byte0 :
                             mem_addr_offset == 2'b01 ? sram_rdata_byte1 :
                             mem_addr_offset == 2'b10 ? sram_rdata_byte2 :
                             sram_rdata_byte3;
    assign sram_rdata_half = mem_addr_offset[1] == 1'b0 ? sram_rdata_half0 :
                             sram_rdata_half1;

    assign sram_rdata = (mem_size == `B) ? (load_signed ? {{24{sram_rdata_byte[7]}}, sram_rdata_byte} : {24'b0, sram_rdata_byte}) :
                        (mem_size == `H) ? (load_signed ? {{16{sram_rdata_half[15]}}, sram_rdata_half} : {16'b0, sram_rdata_half}) :
                        data_sram_rdata;

    assign ws_to_rf_bus = {ws_valid && ms_to_ws_bus_r[71],  //[38]    load标志
                           ws_valid && ms_to_ws_bus_r[70],  //[37]    写寄存器使能
                           ms_to_ws_bus_r[69:65],           //[36:32] 写寄存器地址
                           ms_to_ws_bus_r[64] ? sram_rdata : ms_to_ws_bus_r[63:32]//[31: 0] 写回数据
                          };

    // debug info generate
    assign debug_wb_pc       = ws_valid ? ms_to_ws_bus_r[31:0] : 32'b0;
    assign debug_wb_rf_we    = {4{ws_valid && ms_to_ws_bus_r[70]}};
    assign debug_wb_rf_wnum  = ws_valid ? ms_to_ws_bus_r[69:65] : 5'b0;
    assign debug_wb_rf_wdata = ws_valid ? ws_to_rf_bus[31:0] : 32'b0;
    always @(posedge clk) begin
        if (reset) begin
            ws_valid <= 1'b0;
            ms_to_ws_bus_r <= 0;
        end
        else if (ws_allowin) begin
            ws_valid <= ms_to_ws_valid;
        end

        if (ms_to_ws_valid && ws_allowin) begin
            ms_to_ws_bus_r <= ms_to_ws_bus;
        end
        else begin
            ms_to_ws_bus_r <= 0;
        end
    end
endmodule