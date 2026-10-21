// External vendor IP stubs used only by the VS Code Icarus lint command.
// They keep single-file linting from reporting a missing divider module when
// the generated Xilinx divider IP is not present in the workspace.

module div_signed (
    input  wire        aclk,
    input  wire [31:0] s_axis_dividend_tdata,
    input  wire        s_axis_dividend_tvalid,
    output wire        s_axis_dividend_tready,
    input  wire [31:0] s_axis_divisor_tdata,
    input  wire        s_axis_divisor_tvalid,
    output wire        s_axis_divisor_tready,
    output wire [63:0] m_axis_dout_tdata,
    output wire        m_axis_dout_tvalid
);
    assign s_axis_dividend_tready = 1'b0;
    assign s_axis_divisor_tready  = 1'b0;
    assign m_axis_dout_tdata      = 64'b0;
    assign m_axis_dout_tvalid     = 1'b0;
endmodule

module div_unsigned (
    input  wire        aclk,
    input  wire [31:0] s_axis_dividend_tdata,
    input  wire        s_axis_dividend_tvalid,
    output wire        s_axis_dividend_tready,
    input  wire [31:0] s_axis_divisor_tdata,
    input  wire        s_axis_divisor_tvalid,
    output wire        s_axis_divisor_tready,
    output wire [63:0] m_axis_dout_tdata,
    output wire        m_axis_dout_tvalid
);
    assign s_axis_dividend_tready = 1'b0;
    assign s_axis_divisor_tready  = 1'b0;
    assign m_axis_dout_tdata      = 64'b0;
    assign m_axis_dout_tvalid     = 1'b0;
endmodule
