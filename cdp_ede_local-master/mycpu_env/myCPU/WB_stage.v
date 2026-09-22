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
    output wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus
);

    wire [31:0] final_result;
    wire        res_from_mem;
    wire        gr_we;
    wire [4:0]  dest;
    wire [31:0] pc;

    // 写回寄存器
    // MS_TO_WS_BUS_WD=71，res_from_mem 也要解出来，
    // 少解一位会让整个拼接被截成低 70 位（final_result 整体错位）
    assign {
        final_result, // 32，load 的结果来自数据 RAM 的输出寄存器
        res_from_mem, // 1，本模块不用，仅为对齐位域
        gr_we, // 1
        dest, // 5
        pc // 32
    } = ms_to_ws_bus;


    wire ws_ready_go = 1;
    reg ws_valid;
    assign ws_allowin = !ws_valid || ws_ready_go && rf_allowin;
    assign ws_to_rf_valid = ws_valid && ws_ready_go;

    // WS->RF 组合直通：load 数据只在 WB 这一拍有效，再打一拍会与 pc/dest 错位；
    // 写使能与 ws_valid 相与：总线保持旧字段时不能拿当拍的 rdata 去写寄存器
    assign ws_to_rf_bus = {
        final_result,// 32
        gr_we && ws_valid, // 1
        dest, // 5
        pc // 32
    };

    always @(posedge clk) begin
        if (reset) begin
            ws_valid <= 1'b0;
        end
        else if (ws_allowin) begin
            ws_valid <= ms_to_ws_valid;
        end
    end

endmodule
