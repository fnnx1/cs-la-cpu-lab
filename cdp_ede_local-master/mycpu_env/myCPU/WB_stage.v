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
    output wire [`BLOCK_BUS_WD-1:0] block_bus
);

    wire [31:0] alu_result;
    wire        res_from_mem;
    wire        gr_we;
    wire [4:0]  dest;
    wire [31:0] pc;
    wire mem_b;
    wire mem_h;
    wire mem_u;

    reg [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus_r;

    assign {
        alu_result, // 32，MEM 级 alu 结果
        res_from_mem, // 1，是否需要从数据 RAM 取数
        gr_we, // 1
        dest, // 5
        pc, // 32
        mem_b, // 1
        mem_h, // 1
        mem_u  // 1
    } = ms_to_ws_bus_r;
    wire [1:0] mem_offset = alu_result[1:0];
    wire [15:0] mem_halfword = (mem_offset == 2'b00) ? data_sram_rdata[15:0] :
                        (mem_offset == 2'b10) ? data_sram_rdata[31:16] : 16'b0;
    wire [7:0] mem_byte = (mem_offset == 2'b00) ? data_sram_rdata[7:0] :
                        (mem_offset == 2'b01) ? data_sram_rdata[15:8] :
                        (mem_offset == 2'b10) ? data_sram_rdata[23:16] :
                        (mem_offset == 2'b11) ? data_sram_rdata[31:24] : 8'b0;
    wire [31:0] final_mem_data = mem_b ? {{24{mem_u ? 1'b0 : mem_byte[7]}}, mem_byte} :
                                mem_h ? {{16{mem_u ? 1'b0 : mem_halfword[15]}}, mem_halfword} :
                                data_sram_rdata;
    wire [31:0] final_result = res_from_mem ? final_mem_data: alu_result;


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

    wire [31:0] data_to_rf = final_result;
    wire data_valid = 1'b1;
    assign block_bus = {gr_we, dest, data_valid, data_to_rf};
endmodule
