`include "mycpu_head.v"

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [ 3:0] inst_sram_we,
    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire [ 3:0] data_sram_we,
    output wire        data_sram_en,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    reg reset = 1'b1;
    // 统一时钟上沿采样
    always @(posedge clk) begin 
        reset <= ~resetn;
    end
    reg valid = 1'b0;
    always @(posedge clk) begin
        valid <= ~reset;
    end

    wire [`BR_BUS_WD-1:0] br_bus;

    // 流水线级间总线
    wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus;
    wire ds_allowin; // 前递信号
    wire fs_to_ds_valid; //后递信号
    //
    wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus;
    wire es_allowin;
    wire ds_to_es_valid;
    //
    wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus;
    wire ms_allowin;
    wire es_to_ms_valid;
    //
    wire [`MS_TO_WS_BUS_WD-1:0] ms_to_ws_bus;
    wire ws_allowin;
    wire ms_to_ws_valid;
    //
    wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus;
    wire rf_allowin;
    wire ws_to_rf_valid;

    IF_stage u_IF_stage(
        .clk(clk),
        .reset(reset),
        .ds_allowin(ds_allowin),
        .br_bus(br_bus),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata)
    );

    ID_stage u_ID_stage(
        .clk(clk),
        .reset(reset),
        .ds_allowin(ds_allowin),
        .es_allowin(es_allowin),
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        .br_bus(br_bus),
        .ws_to_rf_bus(ws_to_rf_bus)
    );


    EXE_stage u_EXE_stage(
        .clk(clk),
        .reset(reset),
        .es_allowin(es_allowin),
        .ds_to_es_bus(ds_to_es_bus),
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus(es_to_ms_bus)
    );

    MEM_stage u_MEM_stage(
        .clk(clk),
        .reset(reset),
        .ws_allowin(ws_allowin),
        .ms_allowin(ms_allowin),
        .es_to_ms_bus(es_to_ms_bus),
        .es_to_ms_valid(es_to_ms_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ms_to_ws_valid(ms_to_ws_valid),
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_rdata(data_sram_rdata)
    );

    WB_stage u_WB_stage(
        .clk(clk),
        .reset(reset),
        .rf_allowin(rf_allowin),
        .ws_allowin(ws_allowin),
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),
        .ws_to_rf_bus(ws_to_rf_bus)
    );



    // debug info generate
    /*
    assign debug_wb_pc       = pc;
    assign debug_wb_rf_wen   = {4{rf_we}};
    assign debug_wb_rf_wnum  = dest;
    assign debug_wb_rf_wdata = final_result;
    */
endmodule
