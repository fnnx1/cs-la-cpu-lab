`include "mycpu_head.v"

module WB_stage(
    input wire clk,
    input wire reset,
    //allowin
    input wire rf_allowin,
    output wire ws_allowin,
    //from if stage
    input wire ms_to_ws_valid,
    input wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus,
    //to rf :write back
    output wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus
);

    wire [31:0] final_result;
    wire gr_we;
    wire [4:0] dest;
    wire [31:0] pc;

    // TODO:
    // 写回寄存器
    assign {
        final_result,
        gr_we,
        dest,
        pc
    } = ms_to_ws_bus;


    wire ws_ready_go = 1;
    reg ws_valid;
    assign ws_allowin = !ws_valid || ws_ready_go && rf_allowin;
    assign ws_to_rf_valid = ws_valid && ws_ready_go;

    wire [`WS_TO_RF_BUS_WD-1:0] to_ws_to_rf_bus = {
        final_result,// 32
        gr_we, // 1
        dest, // 5
        pc // 32
    };
    reg [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus_r;

    always @(posedge clk) begin
        if (reset) begin
            ws_valid <= 1'b0;
        end
        else if (ws_allowin) begin
            ws_valid <= ms_to_ws_valid;
        end
        else if (ws_ready_go && rf_allowin) begin
            ws_to_rf_bus_r <= to_ws_to_rf_bus;
        end
    end
    assign ws_to_rf_bus = ws_to_rf_bus_r;

endmodule