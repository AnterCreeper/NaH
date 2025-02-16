`include "defines.v"

`define STATUS_ISSUE 0
`define BCLK_DIV_ISSUE 1
`define LRCLK_DIV_ISSUE 2

module i2s(
    input clk,
    input rst,

    input phy_rd_valid,
    output reg phy_rd,
    input[1:0] phy_rd_chansgn,
    input[16:0] phy_rd_data_chan0,
    input[16:0] phy_rd_data_chan1,

    input evb_cmd_request,
    input[3:0] evb_cmd_addr,
    input[1:0] evb_cmd_wr_mask,
    input[31:0] evb_cmd_wr_data,
    output reg evb_cmd_finish,
    output reg[31:0] evb_cmd_rd_data,

    output io_i2s_lrclk,
    output io_i2s_bclk,
    //tcyc > 390ns
    output reg io_i2s_data
);

reg[31:0] bclk_div;
reg[31:0] lrclk_div;

reg phy_en;
reg busy;

wire evb_cmd_wr;
assign evb_cmd_wr = evb_cmd_wr_mask[1] || evb_cmd_wr_mask[0];

reg[31:0] reg_data;
always @(*)
begin
    case(evb_cmd_addr)
    `STATUS_ISSUE: reg_data <= {30'h0, phy_en, busy};
    `BCLK_DIV_ISSUE: reg_data <= bclk_div;
    `LRCLK_DIV_ISSUE: reg_data <= lrclk_div;
    default:
        reg_data <= 0;
    endcase
end
reg[31:0] cmd;
always @(*)
begin
    case(evb_cmd_wr_mask)
    `EVB_MASK_W: cmd <= evb_cmd_wr_data;
    `EVB_MASK_H: cmd <= {evb_cmd_wr_data[15:0], reg_data[15:0]};
    `EVB_MASK_L: cmd <= {reg_data[31:16], evb_cmd_wr_data[15:0]};
    `EVB_MASK_DUMMY: cmd <= reg_data;
    endcase
end

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        phy_en <= 0;
        bclk_div <= 0;
        lrclk_div <= 0;
        evb_cmd_finish <= 0;
    end else
    if(evb_cmd_finish) evb_cmd_finish <= 0;
    else
    if(evb_cmd_request)
    begin
        if(!phy_en)
        begin
            evb_cmd_finish <= 1;
            case(evb_cmd_addr)
            `BCLK_DIV_ISSUE:
            begin
                bclk_div <= cmd;
                evb_cmd_rd_data <= reg_data;
            end
            `LRCLK_DIV_ISSUE:
            begin
                lrclk_div <= cmd;
                evb_cmd_rd_data <= reg_data;
            end
            endcase
        end
        case(evb_cmd_addr)
        `STATUS_ISSUE:
        begin
            evb_cmd_finish <= 1;
            phy_en <= cmd[1];
            evb_cmd_rd_data <= reg_data;
        end
        default:
        begin
            evb_cmd_finish <= 1;
            evb_cmd_rd_data <= 0;
        end
        endcase
    end
end

reg[31:0] phy_result;

reg pclk;
reg[31:0] bclk_count;
reg[31:0] lrclk_count;
reg phy_tx;
reg phy_chan;

wire phy_word;
assign phy_word = lrclk_count == lrclk_div;
wire phy_bit;
assign phy_bit = bclk_count == bclk_div;

assign io_i2s_lrclk = phy_chan;

integer fd_result;
initial fd_result = $fopen("output_wave.bin", "wb");

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        pclk <= 0;
        bclk_count <= 1;
        lrclk_count <= 1;
        busy <= 0;
        phy_tx <= 1;
        phy_rd <= 0;
        phy_chan <= 0;
        phy_result = 0;
    end else
    begin
        if(phy_en) busy <= 1;
        else if(phy_word) busy <= 0;
        if(busy)
        begin
            pclk <= phy_word ? 0 : (phy_bit ? ~pclk : pclk);
            bclk_count <= phy_word || phy_bit ? 1 : bclk_count + 1; 
            lrclk_count <= phy_word ? 1 : lrclk_count + 1;
            phy_tx <= phy_word;
            phy_rd <= phy_rd_valid && phy_word && phy_chan;
            phy_chan <= phy_word ? ~phy_chan : phy_chan;
            if(phy_rd)
            begin
                case(phy_rd_chansgn)
                0:
                begin
                    phy_result[31:16] = phy_rd_data_chan1;
                    phy_result[15:0] = phy_rd_data_chan0;
                end
                1:
                begin
                    phy_result[31:16] = phy_rd_data_chan0 - phy_rd_data_chan1;
                    phy_result[15:0] = phy_rd_data_chan0;
                end
                2:
                begin
                    phy_result[31:16] = phy_rd_data_chan1;
                    phy_result[15:0] = phy_rd_data_chan0 + phy_rd_data_chan1;
                end
                3:
                begin
                    phy_result[31:16] = phy_rd_data_chan0 - phy_rd_data_chan1[16:1];
                    phy_result[15:0] = phy_rd_data_chan0 + phy_rd_data_chan1[16:1] + phy_rd_data_chan1[0];
                end
                endcase
                $fwrite(fd_result, "%u", phy_result);
            end
        end else
        begin
            pclk <= 0;
            bclk_count <= 1;
            lrclk_count <= 1;
            phy_tx <= 0;
            phy_rd <= 0;
            phy_chan <= 0;
        end
    end
end

reg cke;
reg[4:0] fsm;

assign io_i2s_bclk = cke ? pclk : 0;

always @(negedge pclk or posedge phy_tx)
begin
    if(phy_tx)
    begin
        cke <= 1;
        fsm <= 5'h0f;
        io_i2s_data <= 0;
    end else
    begin
        cke <= ~fsm[4];
        fsm <= fsm[4] ? fsm : fsm - 1;
        io_i2s_data <= fsm[4] ? 0 : phy_result[{phy_chan, fsm[3:0]}];
    end
end

endmodule
