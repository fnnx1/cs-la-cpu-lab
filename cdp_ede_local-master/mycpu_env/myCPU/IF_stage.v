`include "mycpu_defines.vh"

module IF_stage(
    input wire clk, //时钟
    input wire reset,   //复位
    input wire ds_allowin,  //告知是否下个阶段可以接受数据输入
    input wire [`BR_BUS_WD -1 :0] br_bus, //跳转信号
    output wire fs_to_ds_valid,     //告知下个阶段数据是否有效
    output wire [`FS_TO_DS_BUS_WD-1 :0] fs_to_ds_bus,   //传递给下一级的缓冲区
    // inst sram interface
    output wire inst_sram_en,
    output wire [3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata
);

    //if级握手信号
    reg         fs_valid;
    wire        fs_ready_go;
    wire        fs_allowin;
    wire        to_fs_valid;

    wire [31:0] seq_pc; //顺序的地址
    wire [31:0] next_pc; //下一个执行的地址，可能会跳转

    wire br_taken; //跳转信号
    wire [31:0] br_target;//跳转地址

    assign {br_taken,br_target} = br_bus; //跳转信号传递

    wire [31:0] fs_inst; //fs阶段的inst和pc,往后传递
    reg [31:0] fs_pc;

    //if向id传递的bus
    assign fs_to_ds_bus = {fs_inst,fs_pc};

    //pre-if stage
    assign to_fs_valid = ~reset;
    assign seq_pc = fs_pc + 3'h4; //顺序
    assign next_pc = (br_taken == 1 ) ? br_target :seq_pc;

    //IF stage
    assign fs_ready_go = 1'b1; //可以传输
    assign fs_allowin = !fs_valid || fs_ready_go && ds_allowin; 
    //允许进入，需要了解下一级是否可以进入目的是可以实现保持停顿
    //br_taken 有效时, 本拍正要送往 ds 的那条指令属于跳转后的顺序路径(错误路径), 必须作废
    assign fs_to_ds_valid = fs_valid && fs_ready_go && !br_taken;

    always@(posedge clk)begin
        if(reset)begin
            fs_valid <= 1'b0;
        end else if(fs_allowin)begin
            fs_valid <= to_fs_valid;
        end
    end

    always@(posedge clk)begin
        if(reset)begin
            fs_pc <= 32'h1bfffffc;
        end else if(to_fs_valid && fs_allowin)begin
            fs_pc <= next_pc;
        end
    end

    assign inst_sram_en = to_fs_valid && fs_allowin;
    assign inst_sram_we = 4'h0;
    assign inst_sram_addr = next_pc;
    assign inst_sram_wdata = 32'b0;

    assign fs_inst = inst_sram_rdata;

endmodule