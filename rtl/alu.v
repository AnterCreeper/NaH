`include "defines.v"

module clz(
    input[15:0] a,
    output[15:0] y
);

wire[3:0] ai;
wire[7:0] z;
genvar i;
generate
for (i = 0; i < 4; i = i + 1)
begin:tmp
    assign ai[i    ] = ~|a[i*4+3:i*4];
    assign  z[i*2+1] = ~(a[i*4+3]|a[i*4+2]);
    assign  z[i*2  ] = ~((~a[i*4+2] & a[i*4+1]) | a[i*4+3]);
end
endgenerate

assign y = ai[3] ? (
            ai[2] ? (
            ai[1] ? (
            ai[0] ? 16'h0010
                : {14'h0003, z[1:0]})
                : {14'h0002, z[3:2]})
                : {14'h0001, z[5:4]})
                : {14'h0000, z[7:6]};

endmodule

module xmul(
    input s, //s ? clmulh : clmul
    input[15:0] a,
    input[15:0] b,
    output reg[15:0] y
);

wire[15:0] ai, bi;
assign ai = s ? {a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12], a[13], a[14], a[15]} : a;
assign bi = s ? {b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]} : b;

reg[15:0] z;

integer i, j;
always @(*)
begin
    z = 0;
    for (i = 0; i < 16; i = i + 1)
        for (j = 0; j < i + 1; j = j + 1)
        begin
            z[i] = z[i] ^ (ai[i-j] & bi[j]);
        end
    y = s ? {1'b0, z[0], z[1], z[2], z[3], z[4], z[5], z[6], z[7], z[8], z[9], z[10], z[11], z[12], z[13], z[14]} : z;
end

endmodule

module arith(
    input clk,
    input rst,

    input en,

    input ari,
    input lgc,
    input sft,
    input bit,
    input cmv,
    input lea,

    input[2:0] tag3,

    input[15:0] data_in1,
    input[15:0] data_in2,

    input fwd_en1,
    input fwd_en2,
    input[15:0] fwd_data1,
    input[15:0] fwd_data2,

    output data_out_wr,
    output data_out_wr_f,

    output reg[31:0] data_out
);

reg en_in;
reg ari_en,
    lgc_en,
    sft_en,
    bit_en,
    cmv_en,
    lea_en;
    
reg[2:0] tag_in;
reg[15:0] dec_data_in1, dec_data_in2;

wire[15:0] ari_data_in1, ari_data_in2;
wire[15:0] lgc_data_in1, lgc_data_in2;
wire[15:0] sft_data_in1, sft_data_in2;
wire[15:0] bit_data_in1, bit_data_in2;
wire[15:0] cmv_data_in1, cmv_data_in2;
wire[15:0] lea_data_in1, lea_data_in2;
assign ari_data_in1 = !ari_en ? 0 : (fwd_en1 ? fwd_data1 : dec_data_in1);
assign ari_data_in2 = !ari_en ? 0 : (fwd_en2 ? fwd_data2 : dec_data_in2);
assign lgc_data_in1 = !lgc_en ? 0 : (fwd_en1 ? fwd_data1 : dec_data_in1);
assign lgc_data_in2 = !lgc_en ? 0 : (fwd_en2 ? fwd_data2 : dec_data_in2);
assign sft_data_in1 = !sft_en ? 0 : (fwd_en1 ? fwd_data1 : dec_data_in1);
assign sft_data_in2 = !sft_en ? 0 : (fwd_en2 ? fwd_data2 : dec_data_in2);
assign bit_data_in1 = !bit_en ? 0 : (fwd_en1 ? fwd_data1 : dec_data_in1);
assign bit_data_in2 = !bit_en ? 0 : (fwd_en2 ? fwd_data2 : dec_data_in2);
assign cmv_data_in1 = !cmv_en ? 0 : (fwd_en1 ? fwd_data1 : dec_data_in1);
assign cmv_data_in2 = !cmv_en ? 0 : (fwd_en2 ? fwd_data2 : dec_data_in2);
assign lea_data_in1 = !lea_en ? 0 : (fwd_en1 ? fwd_data1 : dec_data_in1);
assign lea_data_in2 = !lea_en ? 0 : (fwd_en2 ? fwd_data2 : dec_data_in2);

reg[31:0] ari_data_out;
reg[31:0] lgc_data_out;
reg[31:0] sft_data_out;
reg[31:0] bit_data_out;
reg[31:0] cmv_data_out;
reg[31:0] lea_data_out;

always @(posedge clk or posedge rst)
begin
    if(rst) begin 
        en_in <= 0;
        ari_en <= 0;
        lgc_en <= 0;
        sft_en <= 0;
        bit_en <= 0;
        cmv_en <= 0;
        lea_en <= 0;
    end else
    if(en)
    begin
        en_in <= 1;
        tag_in <= tag3;
        dec_data_in1 <= data_in1;
        dec_data_in2 <= data_in2;
        if(ari) begin ari_en <= 1; end else ari_en <= 0;
        if(lgc) begin lgc_en <= 1; end else lgc_en <= 0;
        if(sft) begin sft_en <= 1; end else sft_en <= 0;
        if(bit) begin bit_en <= 1; end else bit_en <= 0;
        if(cmv) begin cmv_en <= 1; end else cmv_en <= 0;
        if(lea) begin lea_en <= 1; end else lea_en <= 0;
        //$display("debug: arith issue, tag:%x, in1:%x, in2:%x", tag3, data_in1, data_in2);
    end else
    begin
        en_in <= 0;
        ari_en <= 0;
        lgc_en <= 0;
        sft_en <= 0;
        bit_en <= 0;
        cmv_en <= 0;
        lea_en <= 0;
    end
end

always @(*)
begin
    case({ari_en, lgc_en, sft_en, bit_en, cmv_en, lea_en})
    6'b100000: data_out <= ari_data_out;
    6'b010000: data_out <= lgc_data_out;
    6'b001000: data_out <= sft_data_out;
    6'b000100: data_out <= bit_data_out;
    6'b000010: data_out <= cmv_data_out;
    6'b000001: data_out <= lea_data_out;
    default: data_out <= 32'hx;
    endcase
end

assign data_out_wr = cmv_en ? (tag_in[2] ? cmv_data_in1 != 0 : cmv_data_in1 == 0) : en_in;
assign data_out_wr_f = (tag_in == `TAG_ADC || tag_in == `TAG_SBB) && ari_en;

//arithmetic
wire[15:0] slt_result, sltu_result;
assign slt_result = $signed(ari_data_in1) < $signed(ari_data_in2) ? 1 : 0;
assign sltu_result = ari_data_in1 < ari_data_in2 ? 1 : 0;
always @(*)
begin
    case(tag_in)
    `TAG_ADD:  begin ari_data_out[31:16] <= 16'hx; ari_data_out[15:0] <= ari_data_in1 + ari_data_in2; end
    `TAG_SUB:  begin ari_data_out[31:16] <= 16'hx; ari_data_out[15:0] <= ari_data_in1 - ari_data_in2; end
    `TAG_ADC:  begin ari_data_out[31:17] <= 15'b0; ari_data_out[16:0] <= {1'b0, ari_data_in1} + {1'b0, ari_data_in2}; end
    `TAG_SBB:  begin ari_data_out[31:17] <= 15'b0; ari_data_out[16:0] <= {1'b1, ari_data_in1} - {1'b0, ari_data_in2}; end
    `TAG_SLT:  begin ari_data_out[31:16] <= 16'hx; ari_data_out[15:0] <= slt_result;  end
    `TAG_SLTU: begin ari_data_out[31:16] <= 16'hx; ari_data_out[15:0] <= sltu_result; end
    default: ari_data_out <= 32'hx; 
    endcase
end

//logic
always @(*)
begin
    lgc_data_out[31:16] <= 16'hx;
    case(tag_in)
    `TAG_OR:   lgc_data_out[15:0] <= lgc_data_in1 | lgc_data_in2;
    `TAG_AND:  lgc_data_out[15:0] <= lgc_data_in1 & lgc_data_in2;
    `TAG_XOR:  lgc_data_out[15:0] <= lgc_data_in1 ^ lgc_data_in2;
    `TAG_NOR:  lgc_data_out[31:0] <= ~(lgc_data_in1 | lgc_data_in2);
    default: lgc_data_out[15:0] <= 16'hx;
    endcase
end

//shift
wire[31:0] srr_input;
assign srr_input = {sft_data_in1, sft_data_in1};
always @(*)
begin
    sft_data_out[31:16] <= 16'hx;
    case(tag_in)
    `TAG_SLL: sft_data_out[15:0] <= sft_data_in2[4] ? 16'h0 : sft_data_in1 << sft_data_in2[3:0];
    `TAG_SRL: sft_data_out[15:0] <= sft_data_in2[4] ? 16'h0 : (sft_data_in1 >> sft_data_in2[3:0]);
    `TAG_SRA: sft_data_out[15:0] <= sft_data_in2[4] ? {16{sft_data_in1[15]}} : ($signed($signed(sft_data_in1) >>> sft_data_in2[3:0]));
    `TAG_SRR: sft_data_out[15:0] <= srr_input >> sft_data_in2[3:0]; //truncated
    default: sft_data_out[15:0] <= 16'hx;
    endcase
end

//bit operands
wire[15:0] clz_result;
clz misc0(
    .a(bit_data_in1),
    .y(clz_result)
);
reg xmul_tag;
wire[15:0] xmul_result;
xmul misc1(
    .s(xmul_tag),
    .a(bit_data_in1),
    .b(bit_data_in2),
    .y(xmul_result)
);
reg[15:0] bfx_mask;
always @(*)
begin
    case(bit_data_in2[11:8])
    0:  bfx_mask <= 16'h0001;
    1:  bfx_mask <= 16'h0003;
    2:  bfx_mask <= 16'h0007;
    3:  bfx_mask <= 16'h000f;
    4:  bfx_mask <= 16'h001f;
    5:  bfx_mask <= 16'h003f;
    6:  bfx_mask <= 16'h007f;
    7:  bfx_mask <= 16'h00ff;
    8:  bfx_mask <= 16'h01ff;
    9:  bfx_mask <= 16'h03ff;
    10: bfx_mask <= 16'h07ff;
    11: bfx_mask <= 16'h0fff;
    12: bfx_mask <= 16'h1fff;
    13: bfx_mask <= 16'h3fff;
    14: bfx_mask <= 16'h7fff;
    15: bfx_mask <= 16'hffff;
    endcase
end
always @(*)
begin
    bit_data_out[31:16] <= 16'hx;
    case(tag_in)
    `TAG_XMUL:  xmul_tag = 0;
    `TAG_XMULH: xmul_tag = 1;
    default: xmul_tag = 1'bx;
    endcase
    case(tag_in)
    `TAG_REV: 
    begin
        bit_data_out[15:0] <= {bit_data_in1[0], bit_data_in1[1], bit_data_in1[2], bit_data_in1[3],
                                bit_data_in1[4], bit_data_in1[5], bit_data_in1[6], bit_data_in1[7],
                                bit_data_in1[8], bit_data_in1[9], bit_data_in1[10], bit_data_in1[11],
                                bit_data_in1[12], bit_data_in1[13], bit_data_in1[14], bit_data_in1[15]};
    end
    `TAG_BPAK:  begin bit_data_out[15:0] <= {bit_data_in1[7:0], bit_data_in2[15:8]}; end
    `TAG_BFX:   begin bit_data_out[15:0] <= (bit_data_in1 >> bit_data_in2[3:0]) & bfx_mask; end
    `TAG_CLZ:   begin bit_data_out[15:0] <= clz_result; end
    `TAG_XMUL:  begin bit_data_out[15:0] <= xmul_result; end
    `TAG_XMULH: begin bit_data_out[15:0] <= xmul_result; end
    `TAG_BET:
    begin 
        bit_data_out[15:0] <= {bit_data_in1[15:8] == bit_data_in2[15:8] ? 8'hff : 8'h0,
                               bit_data_in1[7:0] == bit_data_in2[7:0] ? 8'hff : 8'h0};
    end
    default: bit_data_out[15:0] <= 16'hx;
    endcase
end

//conditional move
always @(*)
begin
    cmv_data_out[31:16] <= 16'bx;
    cmv_data_out[15:0] <= cmv_data_in2;
end

//address
always @(*)
begin
    lea_data_out[31:16] <= 16'bx;
    lea_data_out[15:0] <= lea_data_in1 + (lea_data_in2 << (tag_in + 1));
end
endmodule
