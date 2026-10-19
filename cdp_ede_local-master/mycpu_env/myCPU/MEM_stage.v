`include "mycpu_defines.vh"

module MEM_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    input  wire        ws_allowin,  //握手信号(来自 ws 级)
    output wire        ms_allowin,  //该阶段是否可以接收数据
    //from es stage
    input  wire        es_to_ms_valid,
    input  wire [`ES_TO_MS_BUS_WD -1 :0] es_to_ms_bus,  //上一级缓冲区
    //to rf :write back
    output wire        ms_to_ws_valid,  //告知下一级数据是否有效
    output wire [`MS_TO_WS_BUS_WD -1 :0] ms_to_ws_bus,  //写回缓冲区
    //内存访问端口
    output wire [3:0]  data_sram_we,    //数据内存对应字节访问使能
    output wire        data_sram_en,    //数据内存使能
    output wire [31:0] data_sram_addr,  //访问地址
    output wire [31:0] data_sram_wdata //写入数据
);
    reg mem_valid;
    reg [`ES_TO_MS_BUS_WD -1 :0] es_to_ms_bus_r;
    wire ms_ready_go;

    wire mem_we, gr_we,res_from_mem, load_op, load_signed;
    wire [1:0] mem_size ,mem_addr_offset;
    wire [4:0] dest;
    wire [31:0] rkd_value, alu_result, ds_pc, sram_wdata;
    wire [3:0] sram_we;

    assign ms_ready_go     = 1'b1;
    assign ms_allowin      = !mem_valid || ms_ready_go && ws_allowin;
    assign ms_to_ws_valid  = mem_valid && ms_ready_go;
    always @(posedge clk) begin
        if (reset) begin
            mem_valid <= 1'b0;
            es_to_ms_bus_r <= 0;
        end
        else if (ms_allowin) begin
            mem_valid <= es_to_ms_valid;
        end

        if (es_to_ms_valid && ms_allowin) begin
            es_to_ms_bus_r <= es_to_ms_bus;
        end
        else begin
            es_to_ms_bus_r <= 0;
        end
    end

    assign {
            load_signed,  //load指令
            mem_size,
            gr_we,  //写寄存器使能
            dest,  //写寄存器地址
            
            load_op,  //load指令
            res_from_mem,  //结果是否来自内存

            mem_we,  //写内存使能
            rkd_value,  //写内存数据
            alu_result,  //alu计算结果
            ds_pc  //当前指令的pc,用于debug
            } = es_to_ms_bus_r;

    //访存请求只在本级有效时才发出
    assign data_sram_en    = mem_valid && (mem_we | res_from_mem | load_op);

    assign sram_wdata = mem_size == `B ? {4{rkd_value[7:0]}} :
                        mem_size == `H ? {2{rkd_value[15:0]}} :
                        rkd_value;
    assign sram_we    = mem_size == `B ? (alu_result[1:0] == 2'b00 ? 4'b0001 :
                                         alu_result[1:0] == 2'b01 ? 4'b0010 :
                                         alu_result[1:0] == 2'b10 ? 4'b0100 :
                                         4'b1000) :
                        mem_size == `H ? (alu_result[1] == 1'b0 ? 4'b0011 : 4'b1100):
                        4'b1111;
    assign data_sram_addr  = alu_result;
    assign data_sram_wdata = sram_wdata;
    assign data_sram_we    = (mem_valid & mem_we) ? sram_we : 4'b0;

    assign mem_addr_offset = alu_result[1:0];   //内存地址的偏移量
    // ms_to_ws_bus 总位宽 = 1+5+32+32 = 70 bit
    assign ms_to_ws_bus = {
                            mem_addr_offset ,  //[76:75]  内存地址的偏移量
                            load_signed  ,  //[74]     load指令是否有符号扩展
                            mem_size     ,  //[73:72]
                            load_op      ,  //[71]     load标志
                            gr_we        ,  //[70]     写寄存器使能
                            dest         ,  //[69:65]  写寄存器地址
                            res_from_mem ,
                            alu_result ,  //[63:32]  写回数据(load/alu 已 mux)
                            ds_pc           //[31: 0]  当前指令的pc, 用于debug
                          };
endmodule