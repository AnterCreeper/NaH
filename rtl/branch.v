`include "defines.v"

module branch(
    input en,
    input uncon, //jump or branch, aka if unconditional branch
    input[2:0] func3,
    
    input[15:0] pc,
    input[15:0] imm,
    input[4:0] rs1,
    input[15:0] rs2_data,

    input int, //interrupt
    input[15:0] mvec, //interrupt entry pointer
    input mask, //interrupt mask
    output reg clear, //clear interrupt mask output //to be verified

    output reg link, //x2
    output reg[4:0] link_rd,

    output[15:0] pc_plus4,
    output[15:0] pc_nxt
);

wire[15:0] pc_plusi;
wire[15:0] rb;

assign pc_plus4 = pc + 4;
assign pc_plusi = pc + {imm[15:1], 1'b0};
assign rb = {rs2_data[15:1], 1'b0};

wire zero, sign;
assign zero = rs2_data == 16'h0;
assign sign = rs2_data[15];

reg[15:0] pc_jmp;
always @(*)
begin
    if(en)
    begin
        if(uncon)
        case(func3)
        `FUNC_B     : begin pc_jmp <= pc_plusi; link <= 0; clear <= 0; link_rd <= 0; end
        `FUNC_BL    : begin pc_jmp <= pc_plusi; link <= 1; clear <= 0; link_rd <= 2; end
        `FUNC_BLR   : begin pc_jmp <= rb; link <= 1; clear <= 0; link_rd <= rs1; end
        `FUNC_RET   : begin pc_jmp <= rb; link <= 0; clear <= 0; link_rd <= 0; end
        `FUNC_ERET  : begin pc_jmp <= rb; link <= 0; clear <= 1; link_rd <= 0; end
        default: begin pc_jmp <= 16'hx; link <= 1'bx; clear <= 1'bx; link_rd <= 5'bx; end
        endcase
        else
        case(func3)
        `FUNC_CBZ   : begin pc_jmp <= zero ? pc_plusi : pc_plus4; link <= 0; clear <= 0; link_rd <= 0; end
        `FUNC_CBNZ  : begin pc_jmp <= !zero ? pc_plusi : pc_plus4; link <= 0; clear <= 0; link_rd <= 0; end
        `FUNC_CBGE  : begin pc_jmp <= !sign ? pc_plusi : pc_plus4; link <= 0; clear <= 0; link_rd <= 0; end
        `FUNC_CBLT  : begin pc_jmp <= sign ? pc_plusi : pc_plus4; link <= 0; clear <= 0; link_rd <= 0; end
        `FUNC_CBGT  : begin pc_jmp <= !sign && !zero ? pc_plusi : pc_plus4; link <= 0; clear <= 0; link_rd <= 0; end
        `FUNC_CBLE  : begin pc_jmp <= sign || zero ? pc_plusi : pc_plus4; link <= 0; clear <= 0; link_rd <= 0; end
        default: begin pc_jmp <= 16'hx; link <= 1'bx; clear <= 1'bx; link_rd <= 5'bx; end
        endcase
    end else
    begin
        pc_jmp <= 16'hx; link <= 1'b0; clear <= 1'b0; link_rd <= 5'b0; 
    end
end

assign pc_nxt = (int && !mask) ? mvec : (en ? pc_jmp : pc_plus4);

endmodule
