`ifndef MYCPU_H
`define MYCPU_H

// 流水级: FS=IF 取指, DS=ID 译码, ES=EXE 执行, MS=MEM 访存, WS=WB 写回, RF=寄存器堆
// x_TO_y_BUS = x 级传给 y 级的总线(拼成一拍传), _WD = 位宽

`define BR_BUS_WD 33        // 分支 {br_taken, br_target[31:0]} DS→FS
`define FS_TO_DS_BUS_WD 64  // IF→ID {指令[31:0], PC[31:0]}
`define DS_TO_ES_BUS_WD 151 // ID→EXE 译码结果(alu_op/imm/源操作数/pc 等)
`define ES_TO_MS_BUS_WD 48  // EXE→MEM 执行结果, 待填
`define MS_TO_WS_BUS_WD 48  // MEM→WB 访存结果, 待填
`define WS_TO_RF_BUS_WD 38  // WB→RF 写口 {写使能, 写地址[4:0], 写数据[31:0]}
`endif
