module stallable_pipeline #(
    parameter WIDTH = 32
) (
    input wire clk, //时钟
    input wire resetn,  //复位
    input wire validin, //有效使能
    input wire [WIDTH-1:0] datain,  //数据输入32位
    input wire out_allow,   //允许输出
    output wire validout,   //？
    output wire [WIDTH-1:0] dataout //数据输出
);

reg [WIDTH-1:0] pipe1_data;
reg [WIDTH-1:0] pipe2_data;
reg [WIDTH-1:0] pipe3_data;
reg pipe1_valid;
reg pipe2_valid;
reg pipe3_valid;

wire pipe1_allowin;
wire pipe1_ready_go;
wire pipe1_to_pipe2_valid;
assign pipe1_ready_go = ......;
assign pipe1_allowin = ~pipe1_valid || pipe1_ready_go & pipe2_allowin;
assign pipe1_to_pipe2_valid = pipe1_valid & pipe1_ready_go;

always @(posedge clk) begin
    if (~resetn) begin  // 复位使得该触发器数据无效
        pipe1_valid <= 1'b0;
    end else if (pipe1_allowin) begin
        pipe1_valid <= validin;
    end

    if (pipe1_allowin & validin) begin
        pipe1_data <= datain;
    end
end

wire pipe2_allowin;
wire pipe2_ready_go;
wire pipe2_to_pipe3_valid;
assign pipe2_ready_go = ......;
assign pipe2_allowin = ~pipe2_valid || pipe2_ready_go & pipe3_allowin;
assign pipe2_to_pipe3_valid = pipe2_valid & pipe2_ready_go;

always @(posedge clk) begin
    if (~resetn) begin
        pipe2_valid <= 1'b0;
    end else if (pipe2_allowin) begin
        pipe2_valid <= pipe1_to_pipe2_valid;
    end
    if (pipe2_allowin & pipe1_to_pipe2_valid) begin
        pipe2_data <= pipe1_data;
    end
end

wire pipe3_allowin;
wire pipe3_ready_go;
wire pipe3_to_out_valid;  //赋值给validout
assign pipe3_ready_go = ......;
assign pipe3_allowin = ~pipe3_valid || pipe3_ready_go & out_allow;
assign pipe3_to_out_valid = pipe3_valid & pipe3_ready_go;

always @(posedge clk) begin
    if (~resetn) begin
        pipe3_valid <= 1'b0;
    end else if (pipe3_allowin) begin
        pipe3_valid <= pipe2_to_pipe3_valid;
    end
    if (pipe3_allowin & pipe2_to_pipe3_valid) begin
        pipe3_data <= pipe2_data;
    end
end

assign validout = pipe3_to_out_valid;
assign dataout  = pipe3_data;

endmodule