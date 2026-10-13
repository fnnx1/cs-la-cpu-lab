`include "mycpu_head.v"

module ID_stage(
    input wire clk,
    input wire reset,
    //allowin
    input wire es_allowin,
    output wire ds_allowin,
    //from if stage
    input wire fs_to_ds_valid,
    input wire [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus,
    //to ex stage
    output wire ds_to_es_valid,
    output wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus,
    //to if stage
    output wire [`BR_BUS_WD-1:0] br_bus,
    //to rf :write back
    input wire [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus,
    input wire [`BLOCK_BUS_WD*3-1:0] block_bus_sum
);

    wire br_taken;
    wire [31:0] br_target;

    wire [31:0] ds_pc;
    wire [31:0] ds_inst;

    reg [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus_r;
    assign {ds_inst, ds_pc} = fs_to_ds_bus_r;

    reg ds_valid;
    wire ds_ready_go;

    wire [11:0] alu_op;

    wire src1_is_pc; //来自src为pc地址
    wire src2_is_imm; //src2为imm
    wire res_from_mem; //result来自mem
    wire dst_is_r1;
    wire gr_we;
    wire mem_we;
    wire src_reg_is_rd;
    wire [4:0] dest;
    wire rj_eq_rd;
    wire rj_l_rd;
    wire rj_g_rd;
    wire rj_lu_rd;
    wire rj_gu_rd;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;

    /// 访存类型
    wire mem_b; // 字节访问
    wire mem_h; // 半字访问
    // 默认ld时符号扩展
    wire mem_u; // 无符号扩展，ld.bu、ld.hu

    //分段
    wire [5:0] op_31_26;
    wire [3:0] op_25_22;
    wire [1:0] op_21_20;
    wire [4:0] op_19_15;

    wire [4:0] rd;
    wire [4:0] rj;
    wire [4:0] rk;

    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    wire inst_add_w;
    wire inst_sub_w;
    wire inst_slt;
    wire inst_sltu;
    wire inst_nor;
    wire inst_and;
    wire inst_or;
    wire inst_xor;
    wire inst_slli_w;
    wire inst_srli_w;
    wire inst_srai_w;
    wire inst_addi_w;
    wire inst_ld_w;
    wire inst_st_w;
    wire inst_jirl;
    wire inst_b;
    wire inst_bl;
    wire inst_beq;
    wire inst_bne;
    wire inst_lu12i_w;

    /// 添加
    // 运算、逻辑,9
    wire inst_slti;
    wire inst_sltui;
    wire inst_andi;
    wire inst_ori;
    wire inst_xori;
    wire inst_sll_w;
    wire inst_srl_w;
    wire inst_sra_w;
    wire inst_pcaddu12i;
    // 转移,4
    wire inst_blt;
    wire inst_bge;
    wire inst_bltu;
    wire inst_bgeu;
    // 访存,6
    wire inst_st_b;
    wire inst_st_h;
    wire inst_ld_b;
    wire inst_ld_h;
    wire inst_ld_bu;
    wire inst_ld_hu;
    // 乘除,7
    wire inst_mul_w;
    wire inst_mulh_w;
    wire inst_mulh_wu;
    wire inst_div_w;
    wire inst_mod_w;
    wire inst_div_wu;
    wire inst_mod_wu;

    wire need_ui5;
    wire need_si12;
    wire need_ui12; // 无符号扩展12bits
    wire need_si16;
    wire need_si20;
    wire need_si26;
    wire src2_is_4;

    wire [4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [4:0] rf_raddr2;
    wire [31:0] rf_rdata2;

    wire rf_we; //写使能
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;

    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] alu_result;

    wire [31:0] mem_result;
    wire [31:0] final_result;

    assign op_31_26 = ds_inst[31:26];
    assign op_25_22 = ds_inst[25:22];
    assign op_21_20 = ds_inst[21:20];
    assign op_19_15 = ds_inst[19:15];

    assign rd = ds_inst[4:0];
    assign rj = ds_inst[9:5];
    assign rk = ds_inst[14:10];

    assign i12 = ds_inst[21:10];
    assign i20 = ds_inst[24:5];
    assign i16 = ds_inst[25:10];
    assign i26 = {ds_inst[9:0], ds_inst[25:10]};

    decoder_6_64 u_dec0(.in(op_31_26), .out(op_31_26_d));
    decoder_4_16 u_dec1(.in(op_25_22), .out(op_25_22_d));
    decoder_2_4 u_dec2(.in(op_21_20), .out(op_21_20_d));
    decoder_5_32 u_dec3(.in(op_19_15), .out(op_19_15_d));

    ///////////////////////////////////
    assign inst_add_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_w = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_w = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_jirl = op_31_26_d[6'h13];
    assign inst_b = op_31_26_d[6'h14];
    assign inst_bl = op_31_26_d[6'h15];
    assign inst_beq = op_31_26_d[6'h16];
    assign inst_bne = op_31_26_d[6'h17];
    assign inst_lu12i_w = op_31_26_d[6'h05] & ~ds_inst[25];

    /// 添加
    // rj <(signed) si12 ? => rd*
    assign inst_slti = op_31_26_d[6'h00] & op_25_22_d[4'b1000];
    // rj <(unsigned) si12 ? => rd*
    assign inst_sltui = op_31_26_d[6'h00] & op_25_22_d[4'b1001];
    // rj & ui12 => rd*
    assign inst_andi = op_31_26_d[6'h00] & op_25_22_d[4'b1101];
    // rj | ui12 => rd*
    assign inst_ori = op_31_26_d[6'h00] & op_25_22_d[4'b1110];
    // rj ^ ui12 => rd*
    assign inst_xori = op_31_26_d[6'h00] & op_25_22_d[4'b1111];
    // rj << rk[4:0] => rd*
    assign inst_sll_w = op_31_26_d[6'h00] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b01110];
    // rj >> rk[4:0] => rd*
    assign inst_srl_w = op_31_26_d[6'h00] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b01111];
    // rj >>> rk[4:0] => rd*
    assign inst_sra_w = op_31_26_d[6'h00] & op_25_22_d[4'b0000] & op_21_20_d[2'b01] & op_19_15_d[5'b10000];
    // pc + {si20, 12'b0} => rd*
    assign inst_pcaddu12i = op_31_26_d[6'b000111] & ~ds_inst[25];
    // rj <(signed) rkd ? => br_taken
    assign inst_blt = op_31_26_d[6'b011000];
    // rj >=(signed) rkd ? => br_taken
    assign inst_bge = op_31_26_d[6'b011001];
    // rj <(unsigned) rkd ? => br_taken
    assign inst_bltu = op_31_26_d[6'b011010];
    // rj >=(unsigned) rkd ? => br_taken
    assign inst_bgeu = op_31_26_d[6'b011011];
    // 访存,6
    assign inst_ld_b = op_31_26_d[6'b001010] & op_25_22_d[4'b0000];
    assign inst_ld_h = op_31_26_d[6'b001010] & op_25_22_d[4'b0001];
    assign inst_st_b = op_31_26_d[6'b001010] & op_25_22_d[4'b0100];
    assign inst_st_h = op_31_26_d[6'b001010] & op_25_22_d[4'b0101];
    assign inst_ld_bu = op_31_26_d[6'b001010] & op_25_22_d[4'b1000];
    assign inst_ld_hu = op_31_26_d[6'b001010] & op_25_22_d[4'b1001];

    /////////////////////////////////
    /* 摘自 alu.v，参考用
    wire op_add;   //add operation
    wire op_sub;   //sub operation
    wire op_slt;   //signed compared and set less than
    wire op_sltu;  //unsigned compared and set less than
    wire op_and;   //bitwise and
    wire op_nor;   //bitwise nor
    wire op_or;    //bitwise or
    wire op_xor;   //bitwise xor
    wire op_sll;   //logic left shift
    wire op_srl;   //logic right shift
    wire op_sra;   //arithmetic right shift
    wire op_lui;   //Load Upper Immediate
    */
    assign alu_op[0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_bl | inst_pcaddu12i
                        | inst_ld_b | inst_ld_h | inst_st_b | inst_st_h | inst_ld_bu | inst_ld_hu;
    assign alu_op[1] = inst_sub_w;
    assign alu_op[2] = inst_slt | inst_slti;
    assign alu_op[3] = inst_sltu | inst_sltui;
    assign alu_op[4] = inst_and | inst_andi;
    assign alu_op[5] = inst_nor;
    assign alu_op[6] = inst_or | inst_ori;
    assign alu_op[7] = inst_xor | inst_xori;
    assign alu_op[8] = inst_slli_w | inst_sll_w;
    assign alu_op[9] = inst_srli_w | inst_srl_w;
    assign alu_op[10] = inst_srai_w | inst_sra_w;
    assign alu_op[11] = inst_lu12i_w;

    //信号
    assign need_ui5 = inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12 = inst_addi_w | inst_ld_w | inst_st_w
                        | inst_slti | inst_sltui | // 补充算数
                        | inst_ld_b | inst_ld_h | inst_st_b | inst_st_h | inst_ld_bu | inst_ld_hu; // 补充访存
    assign need_ui12 = inst_andi | inst_ori | inst_xori;
    assign need_si16 = inst_jirl | inst_beq | inst_bne;
    assign need_si20 = inst_lu12i_w | inst_pcaddu12i;
    assign need_si26 = inst_b | inst_bl;
    assign src2_is_4 = inst_jirl | inst_bl;

    assign imm = src2_is_4 ? 32'h4 :
                 need_si20 ? {i20[19:0], 12'b0} :
                 need_ui5 ? rk :
                 need_ui12 ? {20'b0,i12[11:0]} : // 无符号扩展12bits
                 {{20{i12[11]}}, i12[11:0]};

    assign br_offs = need_si26 ? {{4{i26[25]}}, i26[25:0], 2'b0} :
                                 {{14{i16[15]}}, i16[15:0], 2'b0};

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w
                            | inst_blt | inst_bge | inst_bltu | inst_bgeu // 补充转移
                            | inst_st_b | inst_st_h; // 补充访存

    assign src1_is_pc = inst_jirl | inst_bl | inst_pcaddu12i;

    assign src2_is_imm = inst_slli_w |
                        inst_srli_w |
                        inst_srai_w |
                        inst_addi_w |
                        inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu |
                        inst_st_w | inst_st_b | inst_st_h |
                        inst_lu12i_w |
                        inst_jirl |
                        inst_bl |
                        inst_slti |
                        inst_sltui |
                        inst_andi |
                        inst_ori |
                        inst_xori |
                        inst_pcaddu12i;

    assign res_from_mem = inst_ld_w
                        | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
    assign dst_is_r1 = inst_bl;
    assign gr_we = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b
                    & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu
                    & ~inst_st_b & ~inst_st_h;
    assign mem_we = inst_st_w
                    | inst_st_b | inst_st_h;
    assign dest = dst_is_r1 ? 5'd1 : rd;

    assign mem_b = inst_ld_b | inst_ld_bu | inst_st_b;
    assign mem_h = inst_ld_h | inst_ld_hu | inst_st_h;
    assign mem_u = inst_ld_bu | inst_ld_hu;

    assign rf_raddr1 = rj;
    assign rf_raddr2 = src_reg_is_rd ? rd : rk;

    regfile u_regfile(
        .clk(clk),
        .raddr1(rf_raddr1),
        .rdata1(rf_rdata1),
        .raddr2(rf_raddr2),
        .rdata2(rf_rdata2),
        .we(rf_we),
        .waddr(rf_waddr),
        .wdata(rf_wdata)
    );

    // 前递与阻塞
    wire [`BLOCK_BUS_WD-1:0] block_bus[0:2];
    assign {block_bus[2], block_bus[1], block_bus[0]} = block_bus_sum;
    //
    wire [4:0] source0 = rf_raddr1;
    wire [4:0] source1 = rf_raddr2;
    //
    wire        blk_we      [0:2];
    wire [4:0]  dest_blk    [0:2];
    wire        data_valid  [0:2];
    wire [31:0] data_to_rf  [0:2];
    //
    assign {blk_we[0], dest_blk[0], data_valid[0], data_to_rf[0]} = block_bus[0];
    assign {blk_we[1], dest_blk[1], data_valid[1], data_to_rf[1]} = block_bus[1];
    assign {blk_we[2], dest_blk[2], data_valid[2], data_to_rf[2]} = block_bus[2];
    // exe/mem/wb
    wire hit0[0:2];
    wire hit1[0:2];
    wire hit[0:2];
    //
    wire should_blk[0:2];
    //
    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin: gen_blk
            assign hit0[i] = (source0 != 5'b0) && blk_we[i] && (dest_blk[i] == source0);
            assign hit1[i] = (source1 != 5'b0) && blk_we[i] && (dest_blk[i] == source1);
            assign hit[i] = hit0[i] | hit1[i];
            assign should_blk[i] = hit[i] && !data_valid[i];
        end
    endgenerate
    //
    wire should_blk0 = blk_we[0] && !data_valid[0] && (dest_blk[0] != 5'b0) &&
        (dest_blk[0] == source0 || dest_blk[0] == source1);
    wire should_blk1 = blk_we[1] && !data_valid[1] && (dest_blk[1] != 5'b0) &&
        (dest_blk[1] == source0 || dest_blk[1] == source1);
    wire should_blk2 = blk_we[2] && !data_valid[2] && (dest_blk[2] != 5'b0) &&
        (dest_blk[2] == source0 || dest_blk[2] == source1);


    assign rj_value = (hit0[0] && data_valid[0]) ? data_to_rf[0] :
        (hit0[1] && data_valid[1]) ? data_to_rf[1] :
        (hit0[2] && data_valid[2]) ? data_to_rf[2] : rf_rdata1;
    assign rkd_value = (hit1[0] && data_valid[0]) ? data_to_rf[0] :
        (hit1[1] && data_valid[1]) ? data_to_rf[1] :
        (hit1[2] && data_valid[2]) ? data_to_rf[2] : rf_rdata2;


    /* added
    wire inst_blt; // rj <(signed) rkd ? => br_taken
    wire inst_bge; // rj >=(signed) rkd ? => br_taken
    wire inst_bltu; // rj <(unsigned) rkd ? => br_taken
    wire inst_bgeu; // rj >=(unsigned) rkd ? => br_taken
    */
    assign rj_eq_rd = (rj_value == rkd_value);
    assign rj_l_rd = ($signed(rj_value) < $signed(rkd_value));
    assign rj_g_rd = ($signed(rj_value) >= $signed(rkd_value));
    assign rj_lu_rd = (rj_value < rkd_value);
    assign rj_gu_rd = (rj_value >= rkd_value);

    assign br_taken = (inst_beq && rj_eq_rd
                    || inst_bne && !rj_eq_rd
                    || inst_jirl
                    || inst_bl
                    || inst_b
                    || inst_blt && rj_l_rd
                    || inst_bge && rj_g_rd
                    || inst_bltu && rj_lu_rd
                    || inst_bgeu && rj_gu_rd
                    ) && ds_valid;
    assign br_target = (inst_beq || inst_bne || inst_bl || inst_b
                        || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :
                       /*inst_jirl*/ (rj_value + jirl_offs);

    assign br_bus = {br_taken, br_target};

    // 写回相关
    // WS_TO_RF_BUS_WD=70: {wdata[69:38], we[37], waddr[36:32], pc[31:0]}
    assign rf_we    = ws_to_rf_bus[37];
    assign rf_waddr = ws_to_rf_bus[36:32];
    assign rf_wdata = ws_to_rf_bus[69:38];

    wire [`DS_TO_ES_BUS_WD-1:0] to_ds_to_es_bus = {
        alu_op,//12
        src1_is_pc,//1
        src2_is_imm,//1
        src2_is_4,//1
        gr_we,//1
        mem_we,//1
        dest,//5
        imm,//32
        rj_value,//32
        rkd_value,//32
        ds_pc,//32
        res_from_mem,//1
        mem_b,//1
        mem_h,//1
        mem_u//1
    };

    //////////////////////////////////////////////////

    reg [2:0] clk1 = 3'b000;
    always @(posedge clk) begin
        clk1 <= clk1 + 1'b1;
    end

    // 本级无阻塞请求
    assign ds_ready_go = !should_blk[0] && !should_blk[1] && !should_blk[2];
    // 未阻塞
    //
    // 个人理解：
    // 实际上阻塞会堵住取指到本级的全部过程，因为valid、bus、pc寄存器更新都要求allowin，
    // 而allowin会通过组合逻辑往前传递。
    // 本级上周期已经处理好、写进了 本级to下级 寄存器（bus和valid）的数据不受影响。
    assign ds_allowin = !ds_valid/*本级源数据本就无效*/ || ds_ready_go && es_allowin/*本级可以走并且后级允许进入*/;
    assign ds_to_es_valid = ds_valid && ds_ready_go; //本级源数据有效并且本级无阻塞请求，本级输出的总线数据能用
    always @(posedge clk) begin
        if (reset) begin
            ds_valid <= 1'b0;
        end else if (ds_allowin) begin
            ds_valid <= fs_to_ds_valid;// 下一级也有一样的逻辑，如果本级阻塞，下一级如果没阻塞valid会拿到气泡
        end
        if (fs_to_ds_valid && ds_allowin) begin// 下一级也有一样的判断，如果本级阻塞，下一级即使没阻塞也不会更新bus
            fs_to_ds_bus_r <= fs_to_ds_bus;
        end
    end

    assign ds_to_es_bus = to_ds_to_es_bus;

endmodule
