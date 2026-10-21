`include "mycpu_defines.vh"

module IF_stage(
    input wire clk, //时钟
    input wire reset,   //复位
    input wire ds_allowin,  //告知是否下个阶段可以接受数据输入
    input wire [`BR_BUS_WD -1 :0] br_bus, //跳转信号
    output wire fs_to_ds_valid,     //告知下个阶段数据是否有效
    output wire [`FS_TO_DS_BUS_WD-1 :0] fs_to_ds_bus,   //传递给下一级的缓冲区
    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [1:0]  inst_sram_size,
    output wire [3:0]  inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,

    input wire [31:0] ex_pc,
    input wire has_ex,  //无条件例外
    input wire int_flush,
    input wire ertn_flush,
    input wire [31:0] ertn_entry
);

    //异常输出处理
    wire if_ex; //if阶段的异常信号
    wire [5:0] if_ecode; //if阶段的异常码
    wire [8:0] if_esubcode; //if阶段的异常子码

    //if级握手信号
    reg         fs_valid;
    wire        fs_ready_go;
    wire        fs_allowin;
    wire        to_fs_valid;

    wire pre_if_ready_go;


    wire [31:0] seq_pc; //顺序的地址
    wire [31:0] next_pc; //下一个执行的地址，可能会跳转

    wire br_stall; //跳转阻塞信号，id级存在即将跳转正在计算的指令
    wire br_taken; //跳转信号
    wire [31:0] br_target;//跳转地址

    reg br_pending; // 待处理跳转
    reg [31:0] br_target_pending; // 待处理跳转地址
    wire br_drop_next_inst; // br 时总是会有一条顺序指令正在读，应该丢弃

    wire br_active;

    wire [31:0] fs_inst; //fs阶段的inst和pc,往后传递
    reg [31:0] fs_pc;
    // 用于完成取指时 ds 不允许进入的情况，暂存指令
    reg [31:0] fs_inst_cache;
    reg fs_inst_cache_valid; // 缓存中的数据是否应该被使用

    reg drop_next_inst; // 丢弃下一条指令，用于发生异常时

    wire any_flush = has_ex || int_flush || ertn_flush;

    wire is_ADEF;

    assign if_ex = is_ADEF; //暂时没有异常处理
    assign if_ecode = is_ADEF ? `ECODE_ADE : 6'b0;
    assign if_esubcode = is_ADEF ? `ESUBCODE_ADEF : 9'b0;
    assign {br_stall,br_taken,br_target} = br_bus; //跳转信号传递

    //if向id传递的bus
    // fs_to_ds_bus 总位宽 = 1+6+9+32+32 = 80 bit
    assign fs_to_ds_bus = {if_ex,        // [79]
                           if_ecode,     // [78:73]
                           if_esubcode,  // [72:64]
                           fs_inst,      // [63:32]
                           fs_pc};       // [31:0]

    // pre-if stage
    // 当请求完成发送完成时，pre-if的pc(next pc)已经可以向下传递，
    // 但 fs 会在确保数据已经读出时才允许同步接收，期间会阻塞pre-if更新与发送请求。
    // 如果 sram 不出错，一次请求发送总是对应一次数据读取完成。
    // 有个缺点，好像要好几拍才取指一次
    assign pre_if_ready_go = inst_sram_req && inst_sram_addr_ok;
    assign to_fs_valid = ~reset && pre_if_ready_go;

    assign seq_pc = fs_pc + 3'h4; //顺序
    assign next_pc = (has_ex || int_flush) ? ex_pc :
                    (ertn_flush) ? ertn_entry :
                    (br_taken)  ? br_target :
                    (br_pending) ? br_target_pending :
                    seq_pc;

    // 这里稍微修了一下，is_ADEF 通过组合逻辑决定fs_inst，而
    // fs_inst 和 fs_pc 应该是同级数据（之前这里是 next_pc)
    assign is_ADEF = fs_pc[1:0] != 2'b0;

    // 异常处理
    always @(posedge clk) begin
        if (reset) begin
            drop_next_inst <= 1'b0;
        end else if (any_flush && (to_fs_valid || (!fs_allowin && !fs_ready_go))) begin
            // 发生异常，且：
            // 1. pre if 刚好发送请求并握手
            // 或
            // 2. (握手后) fs 在等待 data_ok
            drop_next_inst <= 1'b1;
        end else if (inst_sram_data_ok) begin
            // 异常后第一条指令读出时，同步清掉丢弃信号
            // 1. 如果没有出现丢弃，则无影响（本来就是0）
            // 2. 如果出现了丢弃，则置0，下一条指令可以正常执行
            drop_next_inst <= 1'b0;
        end
    end

    // 缓冲指令
    always @(posedge clk)begin
        if(reset || any_flush)begin
            fs_inst_cache <= 32'b0;
            fs_inst_cache_valid <= 1'b0;
        end else if (inst_sram_data_ok && !ds_allowin) begin
            // 当 ds 不允许进入但有新数据读出，帮其暂存
            fs_inst_cache <= inst_sram_rdata;
            fs_inst_cache_valid <= 1'b1;
        end else if (ds_allowin) begin
            // 数据被取走
            fs_inst_cache_valid <= 1'b0;
        end
    end


    //IF stage
    // 指令已经读出或有有效缓冲
    // 感觉ready_go更像是事务完成信号，不保证数据有效
    assign fs_ready_go = inst_sram_data_ok || fs_inst_cache_valid;

    // 允许进入，需要了解下一级是否可以进入目的是可以实现保持停顿
    assign fs_allowin = !fs_valid || fs_ready_go && ds_allowin;

    assign br_active = br_pending || br_taken;
    always @(posedge clk) begin
        if (reset || any_flush) begin
            br_pending <= 1'b0;
            br_target_pending <= 32'b0;
        end else if (br_taken) begin
            br_pending <= 1'b1;
            br_target_pending <= br_target;
        end else if (to_fs_valid && fs_allowin) begin
            br_pending <= 1'b0;
        end
    end

    // fs_valid 应该和可用的[正在取指/已取指]pc绑定
    // 注意异常和跳转都有可能要丢弃最后一条指令
    assign fs_to_ds_valid = fs_valid && fs_ready_go && !drop_next_inst && !br_active;

    always@(posedge clk)begin
        if(reset || any_flush)begin
            // 见手册，if stage异常处理的四种情况都要把fs_valid置0，
            // 所有流水级均应按此规律。
            // 之前的设计不涉及应该是因为固定单周期延迟内存 + pre if总是有效，
            // 异常发生时通过组合逻辑让next pc立即变化提前取指，
            // 异常的第一个时钟升沿那一拍fs直接就能拿到有效的数据（fs_pc和相应的指令数据）；
            // 引入总线后这一点不成立。
            // （个人理解：把与前级的分界缓冲寄存器当作本级“输入”，[x]s_valid表示该“输入”的数据有效）
            fs_valid <= 1'b0;
        end else if(fs_allowin)begin
            // reset 或 flush 的下一周期开始传递前级的数据可用情况
            // 这里 to_fs_valid 在第一次reset后几乎和 pre_if_ready_go 完全等效
            // 表示取到的pc值有效（已经发出读请求）
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

    // 当 fs_allowin == 1 时才发出请求
    // 当 ds 因 load-use 问题阻塞时这里也应阻塞
    // 因为引入总线sram后，!fs_valid 也可能为1，fs_allowin因此为1，
    // pre if会继续发出请求，导致读出跳转前的错误pc的指令
    assign inst_sram_req = !reset && fs_allowin && !br_stall;

    assign inst_sram_addr = next_pc;
    assign inst_sram_wdata = 32'b0;
    assign inst_sram_wstrb = 4'h0;
    assign inst_sram_size = 2'b10;
    assign fs_inst = is_ADEF ? 32'b0
                    : fs_inst_cache_valid ? fs_inst_cache
                    : inst_sram_rdata;

endmodule
