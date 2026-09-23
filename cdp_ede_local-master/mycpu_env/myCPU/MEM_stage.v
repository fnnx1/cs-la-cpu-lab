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
    input wire [31:0] data_sram_rdata
);
    // TODO:
    // 从ex级传入访存地址 -> 写数据接到写，读数据传到下一级
    wire [31:0] alu_result;
    wire [31:0] rkd_value;
    wire [31:0] pc;
    wire res_from_mem;
    wire mem_we;
    wire gr_we;
    wire [4:0] dest;

    assign {
        alu_result,
        rkd_value,
        res_from_mem,
        mem_we,
        gr_we,
        dest,
        pc
    } =  es_to_ms_bus;

    reg ms_valid;

    wire [31:0] mem_result = data_sram_rdata;



    reg [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus_r;
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

    // 冒泡期总线保持的是上一条访存的字段，必须用 ms_valid 门控，
    // 否则会重复发请求（store 到 confreg 会重复产生副作用）
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
        if (ms_to_ws_valid && ws_allowin) begin
            ms_to_ws_bus_r <= to_ms_to_ws_bus;
        end
    end

    wire [31:0] alu_result_r = ms_to_ws_bus_r[`MS_TO_WS_BUS_WD-1:`MS_TO_WS_BUS_WD-32];
    wire res_from_mem_r = ms_to_ws_bus_r[`MS_TO_WS_BUS_WD-33];
    // 用内存的读寄存器直接yong zu
    wire [31:0] final_result = res_from_mem_r ? mem_result : alu_result_r;

    assign ms_to_ws_bus = {final_result, ms_to_ws_bus_r[`MS_TO_WS_BUS_WD-33:0]};

endmodule
