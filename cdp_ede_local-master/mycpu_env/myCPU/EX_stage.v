`include "mycpu_defines.vh"

module EX_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    input  wire        ms_allowin,  //握手信号
    output wire        es_allowin,  //该阶段是否k可以接收数据
    //from ds stage
    input  wire        ds_to_es_valid,
    input  wire [`DS_TO_ES_BUS_WD -1 :0] ds_to_es_bus,  //上一级缓冲区
    //to ms stage
    output wire        es_to_ms_valid,  //告知下一级数据是否有效
    output wire [`ES_TO_MS_BUS_WD -1 :0] es_to_ms_bus  //下一级缓冲区

);
    reg es_valid;
    reg [`DS_TO_ES_BUS_WD -1 :0] ds_to_es_bus_r;
    wire es_ready_go;

    assign es_ready_go    = 1'b1;
    assign es_allowin      = !es_valid || es_ready_go && ms_allowin;
    assign es_to_ms_valid  = es_valid && es_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            es_valid <= 1'b0;
            ds_to_es_bus_r <= 0;
        end
        else if (es_allowin) begin
             es_valid <= ds_to_es_valid;
        end

        if (ds_to_es_valid && es_allowin) begin
            ds_to_es_bus_r <= ds_to_es_bus;
        end
        else begin
            ds_to_es_bus_r <= 0;
        end
    end
    /*assign ds_to_es_bus = {alu_op       ,  //[151:140] 12 bit
                       load_op      ,  //[139]      1 bit
                       src1_is_pc   ,  //[138]      1 bit
                       src2_is_imm  ,  //[137]      1 bit
                       src2_is_4    ,  //[136]      1 bit
                       gr_we        ,  //[135]      1 bit
                       mem_we       ,  //[134]      1 bit
                       dest         ,  //[133:129]  5 bit
                       imm          ,  //[128: 97] 32 bit
                       rj_value     ,  //[ 96: 65] 32 bit   //第一个操作数的值
                       rkd_value    ,  //[ 64: 33] 32 bit   //第二个操作数的值，有可能作为地址
                       ds_pc        ,  //[ 32:  1] 32 bit
                       res_from_mem    //[  0]      1 bit
                      };*/
    wire load_signed;
    wire [1:0] mem_size;
    wire [11:0] alu_op;
    wire load_op;
    wire ex_gr_we;
    wire [4:0] dest;
    wire [31:0] alu_result;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        src2_is_4;
    wire        mem_we;
    wire [31:0] imm;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] ds_pc;
    wire        res_from_mem;

    assign {
            load_signed,
            mem_size,
            alu_op,
            load_op,
            src1_is_pc,
            src2_is_imm,
            src2_is_4,
            ex_gr_we,
            mem_we,
            dest,
            imm,
            rj_value,
            rkd_value,
            ds_pc,
            res_from_mem} = ds_to_es_bus_r;

    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    assign alu_src1 = src1_is_pc  ? ds_pc[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;


    alu _alu(
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );

    assign es_to_ms_bus = {
                        load_signed,  //[107]     1 bit   加载的数据是否要进行有符号扩展
                        mem_size,    //[106:105] 2 bit   内存写入/读取的数据大小
                        ex_gr_we     ,  //[104]     1 bit   写寄存器使能
                        dest         ,  //[103: 99] 5 bit   写寄存器地址

                        load_op      ,  //[ 98]     1 bit   load指令
                        res_from_mem ,  //[ 97]     1 bit   结果是否来自内存

                        mem_we       ,  //[ 96]     1 bit   写内存使能
                        rkd_value    ,  //[ 95: 64] 32 bit  写内存数据
                        alu_result   ,  //[ 63: 32] 32 bit  alu计算结果
                        ds_pc           //[ 31:  0] 32 bit  当前指令的pc,用于debug
                        };
endmodule