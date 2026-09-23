`include "mycpu_head.v"

module IF_stage(
    input wire clk,
    input wire reset,
    input wire ds_allowin,
    input wire [`BR_BUS_WD-1:0] br_bus,
    output wire fs_to_ds_valid,
    output wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus,
    // inst sram interface
    output wire inst_sram_en,
    output wire [3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input wire [31:0] inst_sram_rdata
);

    //if级握手信号
    reg fs_valid; // 本级处于有效状态
    wire fs_ready_go; // 本级计算完成
    wire fs_allowin; // 允许接收上一级的新数据
    wire to_fs_valid; // 下一周期传入fs_valid的状态

    wire [31:0] seq_pc; //顺序的地址
    wire [31:0] next_pc; //下一个执行的地址，可能会跳转

    wire br_taken; //跳转信号
    wire [31:0] br_target; //跳转地址

    assign {br_taken, br_target} = br_bus; //跳转信号传递

    wire [31:0] fs_inst; //fs阶段的inst和pc,往后传递
    reg [31:0] fs_pc; // 定义为已经取好指的最后pc值



    // pre-if stage
    // pc 更新逻辑
    assign to_fs_valid = ~reset;
    assign seq_pc = fs_pc + 3'h4; // 顺序下一指令
    assign next_pc = (br_taken == 1) ? br_target : seq_pc;

    always @(posedge clk) begin
        if (reset) begin
            fs_pc <= 32'h1c00_0000;
        end else if (fs_valid && fs_allowin) begin
            fs_pc <= next_pc;
        end
    end

    reg [2:0] clk1 = 3'b000;
    always @(posedge clk) begin
        clk1 <= clk1 + 1'b1;
    end

    //IF stage
    assign fs_ready_go = 1; // id 阶段解码到跳转时，忽略即将顺序执行的指令
    // 向前级传递可以接收下一数据，即这部分电路的状态允许“被破坏”
    // 个人理解这里的 allow_in 是寄存器准入
    assign fs_allowin = !fs_valid || fs_ready_go && ds_allowin;
    // 向后级传递的是否完成
    assign fs_to_ds_valid = fs_valid && fs_ready_go && !br_taken; // 上一条走出的指令触发跳转，现在即将取的这条指令应该被丢弃

    always @(posedge clk) begin
        if (reset) begin
            fs_valid <= 1'b0;
        end else if (fs_allowin) begin
            fs_valid <= to_fs_valid;
        end
    end

    assign fs_to_ds_bus = {
        fs_inst, // 32
        fs_pc // 32
    };

    assign inst_sram_en = to_fs_valid && fs_allowin;
    assign inst_sram_we = 4'h0; //读
    assign inst_sram_addr = next_pc;
    assign inst_sram_wdata = 32'b0;

    assign fs_inst = inst_sram_rdata;

endmodule
