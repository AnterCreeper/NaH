`timescale 100ps/100ps

`define DELAY 20

module testbench_xmul();

reg clk;
reg sel;
reg[15:0] a, b;
wire[15:0] y;

xmul xm(
    .s(sel),
    .a(a),
    .b(b),
    .y(y)
);

integer i, j;
integer fd;
initial
begin
    sel = 1;
    clk = 0;
    a = 14;
    b = 11;
    #50
    $stop();
end
endmodule
