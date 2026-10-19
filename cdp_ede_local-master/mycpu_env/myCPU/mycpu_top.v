/* fs: fetch stage
 * ds: decode stage
 * es: execute stage
 * ms: memory stage
 * ws: write back stage
 */
`include "mycpu_defines.vh"

module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [3:0]  inst_sram_we,    //指令内存对应字节访问使能
    output wire        inst_sram_en,    // block Memory 使能
    output wire [31:0] inst_sram_addr,  //访问地址
    output wire [31:0] inst_sram_wdata, //写入数据
    input  wire [31:0] inst_sram_rdata, //读数据
    // data sram interface
    output wire [3:0]  data_sram_we,
    output wire        data_sram_en,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,         //pc值
    output wire [ 3:0] debug_wb_rf_we,      //写寄存器信号
    output wire [ 4:0] debug_wb_rf_wnum,    //写入的寄存器号
    output wire [31:0] debug_wb_rf_wdata    //写入数据
);
    wire reset;
    assign reset = ~resetn; //复位信号

    wire        ds_allowin, es_allowin, ms_allowin, ws_allowin;
    wire        fs_to_ds_valid, ds_to_es_valid, es_to_ms_valid, ms_to_ws_valid;

    wire [`BR_BUS_WD       -1:0] br_bus;
    wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
    wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
    wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
    wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
    wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;

    // 取指
    IF_stage if_stage(
        .clk(clk), //时钟
        .reset(reset),   //复位
        .ds_allowin(ds_allowin),  //告知是否下个阶段可以接受数据输入
        .br_bus(br_bus), //
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        // inst sram interface
        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_rdata(inst_sram_rdata)
    );

    // 译码
    ID_stage id_stage(
        .clk(clk),
        .reset(reset),
        //allowin
        .es_allowin(es_allowin),  //握手信号
        .ds_allowin(ds_allowin),  //该阶段是否k可以接收数据
        //from if stage
        .fs_to_ds_valid(fs_to_ds_valid),
        .fs_to_ds_bus(fs_to_ds_bus),
        //to ex stage
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),
        //to if stage
        .br_bus(br_bus),
        //to rf :write back
        .ws_to_rf_bus(ws_to_rf_bus),
        .es_to_ms_bus(es_to_ms_bus),
        .es_dest({es_to_ms_bus[98],es_to_ms_bus[104:99], es_to_ms_bus[63:32]}),
        .ms_dest({ms_to_ws_bus[71],ms_to_ws_bus[70:65], ms_to_ws_bus[63:32]})
    );

    EX_stage ex_stage(
        .clk(clk),
        .reset(reset),
        //allowin
        .ms_allowin(ms_allowin),  //握手信号
        .es_allowin(es_allowin),  //该阶段是否k可以接收数据
        //from ds stage
        .ds_to_es_valid(ds_to_es_valid),
        .ds_to_es_bus(ds_to_es_bus),  //上一级缓冲区
        //to ms stage
        .es_to_ms_valid(es_to_ms_valid),  //告知下一级数据是否有效
        .es_to_ms_bus(es_to_ms_bus)       //下一级缓冲区
    );

    MEM_stage mem_stage(
        .clk(clk),
        .reset(reset),
        //allowin
        .ws_allowin(ws_allowin),  //握手信号
        .ms_allowin(ms_allowin),  //该阶段是否可以接收数据
        //from es stage
        .es_to_ms_valid(es_to_ms_valid),
        .es_to_ms_bus(es_to_ms_bus),  //上一级缓冲区
        //to ws stage
        .ms_to_ws_valid(ms_to_ws_valid),  //告知下一级数据是否有效
        .ms_to_ws_bus(ms_to_ws_bus),   //写回缓冲区
        // data sram interface
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata)
    );

    WB_stage wb_stage(
        .clk(clk),
        .reset(reset),
        //allowin
        .ws_allowin(ws_allowin),  //该阶段是否k可以接收数据
        //from ms stage
        .ms_to_ws_valid(ms_to_ws_valid),
        .ms_to_ws_bus(ms_to_ws_bus),  //上一级缓冲区
        //to rf :write back
        .ws_to_rf_bus(ws_to_rf_bus),   //写回缓冲区
        // trace debug interface
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),
        .data_sram_rdata(data_sram_rdata)
    );
endmodule
