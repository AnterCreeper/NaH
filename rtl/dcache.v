`include "defines.v"

`define READY           3'b001
`define REPLACE_OUT     3'b010
`define REPLACE_IN      3'b100

`ifdef TARGET_FPGA
module clrf( //32 sets
    input CLK,
    input CEN,
    input[15:0] WEN,
    input[4:0] A,
    input[127:0] D,
    output[127:0] Q
);

reg[4:0] addr;
(* ram_style = "distributed" *) reg[127:0] ram[31:0];

assign Q = ram[addr];

integer i;
always @(posedge CLK)
begin
    if(!CEN)
    begin
        addr <= A;
        for(i = 0; i < 16; i = i + 1) if(!WEN[i]) ram[A][i*8+:8] <= D[i*8+:8];
    end
end
endmodule
`endif

module dcache (
    input clk,
    input rst,

    input en,
    input loadstore,
    input flush,
    input zero,
    input[1:0] tag2,
    
    input[15:0] mem_addr_in,
    
    input[1:0] mem_data_fwd,
    input[31:0] mem_data_fwd_data,

    input mem_data_in_sel,
    input[31:0] mem_data_in,
    
    output reg mem_data_wr,
    output reg mem_data_wr_f,
    output reg[31:0] mem_data_out,

    output reg stall,
    
    input tcm_invalid,
    input[15:0] tcm_invalid_addr,
    output reg tcm_read_request, tcm_write_request,
    input tcm_request_finish,
    output reg[15:0] tcm_addr,
    input[127:0] tcm_read_data,
    output reg[127:0] tcm_write_data
);

reg[2:0] fsm;

reg cache_cen;
reg cache_row;
reg cache_flush;
reg cache_zero;
reg[1:0] cache_rw_tag;

reg[15:0] cache_addr;

wire[3:0] cache_offset;
wire[4:0] cache_set;
wire[6:0] cache_tag;
assign cache_offset = cache_addr[3:0];
assign cache_set = cache_addr[8:4];
assign cache_tag = cache_addr[15:9];

reg dec_data_sel;
reg[31:0] dec_data;
wire[31:0] cache_data_f;
assign cache_data_f = {mem_data_fwd[1] ? mem_data_fwd_data[31:16] : dec_data[31:16],
                     mem_data_fwd[0] ? mem_data_fwd_data[15:0] : dec_data[15:0]};
wire[15:0] cache_data;
assign cache_data = dec_data_sel ? cache_data_f[31:16] : cache_data_f[15:0];

reg wr, wr_en;
always @(*)
begin
    if(!stall) mem_data_wr = wr;
    else if(wr_en) mem_data_wr = wr;
    else mem_data_wr = 0;
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        cache_cen <= 0;
        wr <= 0;
    end else
    if(!stall)
    begin
        if(en)
        begin
            cache_cen <= 1;
            cache_row <= loadstore;
            cache_flush <= flush;
            cache_zero <= zero;
            cache_rw_tag <= tag2;
            cache_addr <= mem_addr_in;
            dec_data_sel <= mem_data_in_sel;
            dec_data <= mem_data_in;
            wr <= loadstore;
        end else
        begin
            cache_cen <= 0;
            wr <= 0;
        end
    end else
    begin
        cache_cen <= 0;
    end
end

reg[6:0] tag[31:0];
reg[31:0] valid;
reg[31:0] dirty;

wire hit;
assign hit = !cache_flush && valid[cache_set] && cache_tag == tag[cache_set];

reg rf_cen;
reg[15:0] rf_wen; //register file write mask
reg[4:0] rf_addr_set;
reg[127:0] rf_data_in;
wire[127:0] rf_data_out;

clrf cache_lines( //32 sets
    .CLK(!clk),
    .CEN(~rf_cen),
    .WEN(~rf_wen),
    .A(rf_addr_set), 
    .D(rf_data_in), 
    .Q(rf_data_out)
);

reg[15:0] rf_mask;
reg[3:0] rf_mask_partition;

reg[127:0] rf_sft_data_in;
reg[31:0] rf_sft_data_out;

reg[31:0] rf_data_partition;

always @(*)
begin
    //TODO
    //to slow from rf_mask to rf_wen
    if(cache_row)
    begin
        rf_mask_partition = 0;
        rf_mask = 0;
    end else
    begin
        case(cache_rw_tag)
        `TAG_LSW:   rf_mask_partition = 4'b1111;
        `TAG_LSH:   rf_mask_partition = cache_offset[1] ? 4'b1100 : 4'b0011;
        `TAG_LSB, `TAG_LBU:
            case(cache_offset[1:0])
            2'b00: rf_mask_partition = 4'b0001;
            2'b01: rf_mask_partition = 4'b0010;
            2'b10: rf_mask_partition = 4'b0100;
            2'b11: rf_mask_partition = 4'b1000;
            endcase
        endcase
        case(cache_offset[3:2])
        2'b00:  rf_mask = {12'h0, rf_mask_partition};
        2'b01:  rf_mask = {8'h0, rf_mask_partition, 4'h0};
        2'b10:  rf_mask = {4'h0, rf_mask_partition, 8'h0};
        2'b11:  rf_mask = {rf_mask_partition, 12'h0};
        endcase
    end
    
    //TODO
    //too slow from rf_data_out to fwd data reg
    case(cache_offset[3:2])
    2'b00:  rf_data_partition = rf_data_out[31:0];
    2'b01:  rf_data_partition = rf_data_out[63:32];
    2'b10:  rf_data_partition = rf_data_out[95:64];
    2'b11:  rf_data_partition = rf_data_out[127:96];
    endcase
    case(cache_rw_tag)
    `TAG_LSW: 
    begin
        rf_sft_data_in <= cache_data_f << (8 * {cache_offset[3:2], 2'b0});
        mem_data_out = rf_data_partition;
    end
    `TAG_LSH:
    begin
        rf_sft_data_in <= cache_data << (8 * {cache_offset[3:1], 1'b0});
        mem_data_out = {16'h0, cache_offset[1] ? rf_data_partition[31:16] : rf_data_partition[15:0]};
    end
    `TAG_LSB:
    begin
        rf_sft_data_in <= cache_data << (8 * cache_offset);
        case(cache_offset[1:0])
        2'b00: mem_data_out = {{24{rf_data_partition[7]}},  rf_data_partition[7:0]};
        2'b01: mem_data_out = {{24{rf_data_partition[15]}}, rf_data_partition[15:8]};
        2'b10: mem_data_out = {{24{rf_data_partition[23]}}, rf_data_partition[23:16]};
        2'b11: mem_data_out = {{24{rf_data_partition[31]}}, rf_data_partition[31:24]};
        endcase
    end
    `TAG_LBU:
    begin
        rf_sft_data_in <= cache_data << (8 * cache_offset);
        case(cache_offset[1:0])
        2'b00: mem_data_out = {24'h0, rf_data_partition[7:0]};
        2'b01: mem_data_out = {24'h0, rf_data_partition[15:8]};
        2'b10: mem_data_out = {24'h0, rf_data_partition[23:16]};
        2'b11: mem_data_out = {24'h0, rf_data_partition[31:24]};
        endcase
    end
    endcase
end

reg rf_comb_cen;
reg[15:0] rf_comb_wen;
reg[4:0] rf_comb_addr_set;
reg[127:0] rf_comb_data_in;

always @(*)
begin
    case(fsm)
    `READY: stall <= cache_cen ? (hit ? 0 : !cache_zero) : 0;
    `REPLACE_OUT: stall <= 1;
    `REPLACE_IN: stall <= 1;
    default: stall <= 1'bx;
    endcase
    if(cache_cen)
    begin
        if(!hit) //not hit
        begin
            if(dirty[cache_set]) //dirty write back
            begin
                rf_cen <= 1;
                rf_wen <= 0;
                rf_addr_set <= cache_set;
                rf_data_in <= 0;
            end else
            begin //zero or do nothing
                rf_cen <= cache_zero;
                rf_wen <= 16'hffff;
                rf_addr_set <= cache_set;
                rf_data_in <= 0;
            end
        end else
        begin //hit
            rf_cen <= 1;
            rf_wen <= cache_zero ? 16'hffff : rf_mask; //whether zero all
            rf_addr_set <= cache_set;
            rf_data_in <= rf_sft_data_in;
        end
    end else
    begin
        rf_cen <= rf_comb_cen;
        rf_wen <= rf_comb_wen;
        rf_addr_set <= rf_comb_addr_set;
        rf_data_in <= rf_comb_data_in;
    end  
    mem_data_wr_f <= cache_rw_tag == `TAG_LSW;
end

wire[4:0] invalid_set; //32 sets
wire[6:0] invalid_tag; //tags
assign invalid_set = tcm_invalid_addr[8:4];
assign invalid_tag = tcm_invalid_addr[15:9];

wire true_invalid;
assign true_invalid = tcm_invalid && (tag[invalid_set] == invalid_tag);
wire invalid_collision;
assign invalid_collision = true_invalid && (invalid_set == cache_set);
reg invalid_skip;

integer i;
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        fsm <= `READY;
        valid <= 0;
        dirty <= 0;
        tcm_read_request  <= 0;
        tcm_write_request <= 0;
        rf_comb_cen <= 0;
        wr_en <= 0;
        for(i = 0; i < 32; i = i + 1) tag[i] <= 0;
        invalid_skip <= 0;
    end else
    begin
        if(true_invalid)
        begin
            valid[invalid_set] <= 0; //should be higher priority.
            dirty[invalid_set] <= 0;
        end
        case(fsm)
        `READY:
        begin
            rf_comb_cen <= 0;
            wr_en <= 0;
            if(cache_cen)
            begin
                if(hit && !cache_row) dirty[cache_set] <= 1;
                if(!hit)
                begin
                    if(dirty[cache_set])
                    begin
                        //$display("write back set %d.", cache_set);
                        invalid_skip <= invalid_collision;
                        fsm <= cache_zero ? `REPLACE_IN : `REPLACE_OUT;
                        tcm_read_request  <= 0;
                        tcm_write_request <= !invalid_collision;
                        tcm_addr <= {tag[cache_set], cache_set, 4'b0};
                        tcm_write_data <= rf_data_out;
                    end else
                    begin
                        if(cache_zero) 
                        begin
                            //$display("fake allocate set %d.", cache_set);
                            if(!invalid_collision) valid[cache_set] <= 1;
                            dirty[cache_set] <= 1; //who cares what data it holds, just zero it.
                            tag[cache_set] <= cache_tag;
                            //FIXME: if the data is actually zeroed? need test further.
                        end else
                        begin
                            //$display("allocate set %d and load data from mem.", cache_set);
                            fsm <= `REPLACE_IN;
                            tcm_read_request  <= 1;
                            tcm_write_request <= 0;
                            tcm_addr <= {cache_tag, cache_set, 4'b0};
                            tcm_write_data <= 0;
                        end
                    end
                end
            end
        end
        `REPLACE_OUT:
        begin
            invalid_skip <= 0;
            if (tcm_request_finish || invalid_skip)
            begin
                fsm <= `REPLACE_IN;
                tcm_read_request <= 1;
                tcm_write_request <= 0;
                tcm_addr <= {cache_tag, cache_set, 4'b0};
                tcm_write_data <= 0;
            end
        end
        `REPLACE_IN:
        begin
            invalid_skip <= 0;
            if (tcm_request_finish || invalid_skip)
            begin
                fsm <= `READY;
                wr_en <= 1;
                rf_comb_cen <= 1;
                rf_comb_wen <= 16'hffff;
                rf_comb_addr_set <= cache_set;
                for(i = 0; i < 16; i = i + 1)
                    rf_comb_data_in[i*8+:8] <= cache_zero ? 0 : rf_mask[i] ? rf_sft_data_in[i*8+:8] : tcm_read_data[i*8+:8];
                tcm_read_request  <= 0;
                tcm_write_request <= 0;
                tcm_addr <= 0;
                tcm_write_data <= 0;
                if(!invalid_collision) valid[cache_set] <= 1;
                dirty[cache_set] <= !cache_row;
                tag[cache_set] <= cache_tag;
            end
        end
        endcase
    end
end

endmodule
