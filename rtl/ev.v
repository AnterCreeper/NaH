`include "defines.v"

`define FSM_SEND 0
`define FSM_RECV 1

module ev(
    input clk,
    input rst,

    input en,
    input[2:0] func3,
    input[1:0] tag2,

    input[15:0] ev_addr,
    input ev_data_in_sel,
    input[31:0] ev_data,

    input[1:0] ev_data_fwd,
    input[31:0] ev_data_fwd_data,
    
    output reg[15:0] mvec,
    input[15:0] mepc,
    
    output reg stall,

    output reg ev_data_wr,
    output reg ev_data_wr_f,
    output reg[31:0] ev_data_out,

    output reg evb_cmd_request,
    output reg[15:0] evb_cmd_addr,
    output reg[1:0] evb_cmd_wr_mask,
    output reg[31:0] evb_cmd_wr_data,
    input evb_cmd_finish,
    input[31:0] evb_cmd_rd_data
);

reg fsm;

reg[1:0] mask;
always @(*)
begin
    case(tag2)
    `TAG_W:   mask <= `EVB_MASK_W;
    `TAG_H:   mask <= `EVB_MASK_H;
    `TAG_L:   mask <= `EVB_MASK_L;
    default:
              mask <= 2'bx;
    endcase
end

reg[1:0] wr_mask;
//reg[1:0] rd_mask;

reg[15:0] addr;
wire[3:0] subaddr;
wire[11:0] blkaddr;
assign subaddr = addr[3:0];
assign blkaddr = addr[15:4];

reg dec_data_sel;
reg[31:0] dec_send_data;
wire[31:0] send_data_f;
assign send_data_f = {ev_data_fwd[1] ? ev_data_fwd_data[31:16] : dec_send_data[31:16],
                        ev_data_fwd[0] ? ev_data_fwd_data[15:0] : dec_send_data[15:0]};
wire[15:0] send_data;
assign send_data = dec_data_sel ? send_data_f[31:16] : send_data_f[15:0];

reg backend_en;
reg intreg;
reg cmd_sel;

reg[31:0] rd_data;
always @(*)
begin
    if(intreg)
    case(subaddr)
    0: rd_data <= cmd_sel ? 32'h0 : mvec;
    1: rd_data <= cmd_sel ? 32'h0 : mepc;
    //0: rd_data <= cmd_sel ? {16'h0, mvec[31:16]} : mvec;
    //1: rd_data <= cmd_sel ? {16'h0, mepc[31:16]} : mepc;
    default: rd_data <= 32'hx;
    endcase
    else rd_data <= evb_cmd_rd_data;
end

reg data_wr, data_wr_en;
always @(*)
begin
    if(!stall) ev_data_wr = data_wr;
    else if(data_wr_en) ev_data_wr = data_wr;
    else ev_data_wr = 0;
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        backend_en <= 0;
        stall <= 0;
        data_wr <= 0;
    end else
    if(!stall)
    begin
        if(en)
        begin
            stall <= 1;
            backend_en <= 1;
            intreg <= ev_addr[15:4] == 0;
            data_wr <= func3 != `FUNC_DR;
            ev_data_wr_f <= tag2 == `TAG_W;
            addr <= ev_addr;
            dec_data_sel <= ev_data_in_sel;
            dec_send_data <= ev_data;
            cmd_sel <= tag2 == `TAG_H;
            if(func3 == `FUNC_DW) wr_mask <= `EVB_MASK_DUMMY;
            else wr_mask <= mask;
            //if(func3 == `FUNC_DR) rd_mask <= `EVB_MASK_DUMMY;
            //else rd_mask <= mask;
        end else
        begin
            backend_en <= 0;
            data_wr <= 0;
        end
    end else
    begin
        if(evb_cmd_finish || intreg)
        begin
            stall <= 0;
            backend_en <= 0;
        end
    end
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        mvec <= 0;
        data_wr_en <= 0;
        fsm <= `FSM_SEND;
        evb_cmd_request <= 0;
        evb_cmd_addr <= 0;
        evb_cmd_wr_mask <= 0;
        evb_cmd_wr_data <= 0;
    end else
    if(backend_en)
    begin
        if(intreg)
        begin
            data_wr_en <= 0;
            case(subaddr)
            0: mvec <= {wr_mask[1] ? (ev_data_wr_f ? 16'h0 : send_data) : 16'h0,
                        wr_mask[0] ? (ev_data_wr_f ? send_data_f[15:0] : send_data) : mvec[15:0]};
            //0: mvec <= {wr_mask[1] ? (ev_data_wr_f ? send_data_f[31:16] : send_data) : mvec[31:16],
            //            wr_mask[0] ? (ev_data_wr_f ? send_data_f[15:0] : send_data) : mvec[15:0]};
            endcase
            ev_data_out <= rd_data;
        end else
        begin
            case(fsm)
            `FSM_SEND:
            begin
                data_wr_en <= 0;
                evb_cmd_request <= 1;
                evb_cmd_addr <= addr;
                evb_cmd_wr_mask <= wr_mask;
                evb_cmd_wr_data <= ev_data_wr_f ? send_data_f : send_data;
                fsm <= `FSM_RECV;
            end
            `FSM_RECV:
            begin
                if(evb_cmd_finish)
                begin
                    data_wr_en <= 1;
                    evb_cmd_request <= 0;
                    evb_cmd_addr <= 0;
                    evb_cmd_wr_mask <= 0;
                    evb_cmd_wr_data <= 0;
                    ev_data_out <= rd_data;
                    fsm <= `FSM_SEND;
                end
            end
            endcase
        end
    end else
    begin
        data_wr_en <= 0;
    end
end

endmodule
