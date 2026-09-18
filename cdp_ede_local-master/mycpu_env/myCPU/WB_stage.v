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



    assign rf_we    = gr_we && valid;
    assign rf_waddr = dest;
    assign rf_wdata = final_result;

endmodule