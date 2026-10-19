`include "mycpu_defines.vh"

module ID_stage(
    input  wire        clk,
    input  wire        reset,
    //allowin
    input  wire        es_allowin,  //握手信号
    output wire        ds_allowin,  //该阶段是否k可以接收数据
    //from if stage
    input  wire        fs_to_ds_valid,
    input  wire [`FS_TO_DS_BUS_WD -1 :0] fs_to_ds_bus,  //上一级缓冲区
    //to ex stage
    output wire        ds_to_es_valid,      //告知下一级数据是否有效
    output wire [`DS_TO_ES_BUS_WD -1 :0] ds_to_es_bus,  //下一级缓冲区
    //to if stage
    output wire [`BR_BUS_WD -1 : 0 ] br_bus,    //跳转信号
    //to rf :write back
    input  wire [`WS_TO_RF_BUS_WD -1 :0] ws_to_rf_bus,   //写回缓冲区
    //处理冲突
    input wire  [`ES_TO_MS_BUS_WD -1 :0] es_to_ms_bus,   //来自es阶段的冲突信号
    input wire  [38 : 0] es_dest,   //load_op , gr_we , dest[5] , data[32]
    input wire  [38 : 0] ms_dest

);

wire br_taken;
wire [31:0] br_target;

wire [31:0] ds_pc;
wire [31:0] ds_inst;

reg         ds_valid;
wire        ds_ready_go;

wire [11:0] alu_op;

wire load_signed;  //加载的数据是否要进行有符号扩展
wire [1:0] mem_size;  //内存写入/读取的数据大小
wire load_op;  //加载信号
wire src1_is_pc; //来自src为pc地址
wire src2_is_imm; //src2为imm
wire res_from_mem; //结果来自mem
wire dst_is_r1;
wire gr_we;
wire mem_we;
wire src_reg_is_rd;
wire [4:0]dest;
wire rj_eq_rd;
wire [31:0]rj_value;
wire [31:0]rkd_value;
wire [31:0]imm;
wire [31:0]br_offs;
wire [31:0]jirl_offs;

//分段
wire [5:0] op_31_26;
wire [3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;

wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;

wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;
wire        inst_pcaddu12i;
wire        inst_slti;
wire        inst_sltui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_sll_w;
wire        inst_sra_w;
wire        inst_srl_w;
wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;
wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;
wire        inst_st_b;
wire        inst_st_h;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire [31:0] alu_src1 ;
wire [31:0] alu_src2;
wire [31:0] alu_result;

wire [31:0] mem_result;
wire [31:0] final_result;

wire rf_we ; //写使能
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;

reg [`FS_TO_DS_BUS_WD -1 :0] fs_to_ds_bus_r;

//冲突信号
wire es_match_rj = es_dest[37] && (es_dest[36:32] == rf_raddr1) && (rf_raddr1 != 5'd0);
wire es_match_rkd = es_dest[37] && (es_dest[36:32] == rf_raddr2) && (rf_raddr2 != 5'd0);
wire ms_match_rj = ms_dest[37] && (ms_dest[36:32] == rf_raddr1) && (rf_raddr1 != 5'd0);
wire ms_match_rkd = ms_dest[37] && (ms_dest[36:32] == rf_raddr2) && (rf_raddr2 != 5'd0);
wire ws_match_rj = ws_to_rf_bus[37] && (ws_to_rf_bus[36:32] == rf_raddr1) && (rf_raddr1 != 5'd0);
wire ws_match_rkd = ws_to_rf_bus[37] && (ws_to_rf_bus[36:32] == rf_raddr2) && (rf_raddr2 != 5'd0);

wire es_load_hazard = es_dest[38] && (es_match_rj || es_match_rkd);
wire ms_load_hazard = ms_dest[38] && (ms_match_rj || ms_match_rkd);
wire load_data_hazard = es_load_hazard || ms_load_hazard;

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25];
assign inst_slti = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_andi = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori = op_31_26_d[6'h00] & op_25_22_d[4'hf];
assign inst_sll_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'he];
assign inst_sra_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_srl_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_blt = op_31_26_d[6'h18];
assign inst_bge = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_ld_b | inst_st_w | inst_st_b | inst_st_h
                    | inst_jirl | inst_bl | inst_pcaddu12i | inst_ld_h | inst_ld_bu | inst_ld_hu;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w ;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w ;
assign alu_op[11] = inst_lu12i_w;

//信号
assign need_ui5  = inst_slli_w | inst_srli_w | inst_srai_w;
assign need_u12  = inst_andi | inst_ori | inst_xori;
assign need_si12 = inst_addi_w | inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | inst_st_w | inst_st_b | inst_st_h 
                                | inst_slti | inst_sltui ;
assign need_si16 = inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20 = inst_lu12i_w | inst_pcaddu12i;
assign need_si26 = inst_b | inst_bl;
assign src2_is_4 = inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4
            : need_si20 ? {i20[19:0], 12'b0}
            : need_u12 ? i12[11:0]
            : need_ui5 ? rk
            : {{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                            {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_st_b | inst_st_h | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_ld_b   |
                       inst_ld_h   |
                       inst_ld_bu   |
                       inst_ld_hu   |
                       inst_st_w   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_lu12i_w|
                       inst_pcaddu12i |
                       inst_slti   |
                       inst_sltui   |
                       inst_andi   |
                       inst_ori   |
                       inst_xori   |
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;   //备战未来（？
assign load_op       = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;   //加载指令标志
assign load_signed = inst_ld_b | inst_ld_w | inst_ld_h ;
assign mem_size = inst_ld_b ? `B :
                  inst_ld_w ? `W :
                  inst_st_w ? `W :
                  inst_st_b ? `B :
                  inst_st_h ? `H :
                  inst_ld_h ? `H :
                  inst_ld_hu ? `H :
                  inst_ld_bu ? `B :
                  0;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_st_b & ~inst_st_h & ~inst_beq & ~inst_bne & ~inst_b & ~inst_blt & ~inst_bge & ~inst_bltu & ~inst_bgeu;
assign mem_we        = inst_st_w | inst_st_b | inst_st_h;
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;

assign rf_we = !reset && ws_to_rf_bus[37];
assign rf_waddr = ws_to_rf_bus[36:32];
assign rf_wdata = ws_to_rf_bus[31:0];

regfile u_regfile(
    .clk    (clk    ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
);


assign rj_value = (es_match_rj && !es_dest[38]) ? es_dest[31:0] :
                  (ms_match_rj && !ms_dest[38]) ? ms_dest[31:0] :
                  ws_match_rj ? ws_to_rf_bus[31:0] : rf_rdata1;
assign rkd_value = (es_match_rkd && !es_dest[38]) ? es_dest[31:0] :
                   (ms_match_rkd && !ms_dest[38]) ? ms_dest[31:0] :
                   ws_match_rkd ? ws_to_rf_bus[31:0] : rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign rj_lt_rd = ($signed(rj_value) < $signed(rkd_value));
assign rj_ltu_rd = ($unsigned(rj_value) < $unsigned(rkd_value));
assign br_taken = (  inst_beq  &&  rj_eq_rd
                  || inst_bne  && !rj_eq_rd
                  || inst_blt  &&  rj_lt_rd
                  || inst_bge  && !rj_lt_rd
                  || inst_bltu &&  rj_ltu_rd
                  || inst_bgeu && !rj_ltu_rd
                  || inst_jirl
                  || inst_bl
                  || inst_b
                  ) && ds_valid && ds_ready_go;
assign br_target = (inst_beq || inst_bne || inst_blt || inst_bl || inst_b || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign br_bus = {br_taken , br_target};

assign {ds_inst,
        ds_pc} = fs_to_ds_bus_r;

// ds_to_es_bus 总位宽 = 1+2+12+1+1+1+1+1+1+5+32+32+32+32+1 = 155 bit
assign ds_to_es_bus = {
                        load_signed,  //[154]     1  bit
                        mem_size     ,  //[153:152] 2  bit
                        alu_op       ,  //[151:140] 12 bit
                        load_op      ,  //[139]      1 bit
                        src1_is_pc   ,  //[138]      1 bit
                        src2_is_imm  ,  //[137]      1 bit
                        src2_is_4    ,  //[136]      1 bit
                        gr_we        ,  //[135]      1 bit
                        mem_we       ,  //[134]      1 bit
                        dest         ,  //[133:129]  5 bit
                        imm          ,  //[128: 97] 32 bit
                        rj_value     ,  //[ 96: 65] 32 bit
                        rkd_value    ,  //[ 64: 33] 32 bit
                        ds_pc        ,  //[ 32:  1] 32 bit
                        res_from_mem    //[  0]      1 bit
                      };

assign ds_ready_go = reset || !load_data_hazard;
// 是否是写指令，且是否寄存器值相等
assign ds_allowin      = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid  = ds_valid && ds_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

endmodule