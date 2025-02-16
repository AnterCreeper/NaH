`include "defines.v"

`define ADDRESS_ISSUE 0
`define SD_STATUS_ISSUE 1
`define READ_ISSUE 2
`define WRITE_ISSUE 3
`define REG_ISSUE 4
`define DIVIDER_ISSUE 5
    
module sdhci(
    input clk,
    input rst,

    input evb_cmd_request,
    input[3:0] evb_cmd_addr,
    input[1:0] evb_cmd_wr_mask,
    input[31:0] evb_cmd_wr_data,
    output reg evb_cmd_finish,
    output reg[31:0] evb_cmd_rd_data,
    
    output reg tcm_write_request,
    input tcm_request_finish,
    output reg[15:0] tcm_addr,
    output[127:0] tcm_write_data,
    
    output reg spi_cs,
    output spi_clk,
    output spi_mosi,
    input spi_miso,
    
    output reg test,
    output reg[31:0] test_addr
);

reg en, busy, issue;
reg[31:0] block_address;
reg[15:0] base_address;
reg[15:0] divider;

reg[7:0] sr[1:0];

wire evb_cmd_wr;
assign evb_cmd_wr = evb_cmd_wr_mask[1] || evb_cmd_wr_mask[0];

reg[31:0] reg_data;
always @(*)
begin
    case(evb_cmd_addr)
    `ADDRESS_ISSUE: reg_data <= block_address;
    `READ_ISSUE: reg_data <= {16'h0, base_address};
    `DIVIDER_ISSUE: reg_data <= {16'h0, divider};
    `SD_STATUS_ISSUE: reg_data <= {30'h0, en, busy};
    `REG_ISSUE: reg_data <= {16'h0, sr[1], sr[0]};
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
        en <= 0;
        divider <= 0;
        issue <= 0;
        block_address <= 0;
        base_address <= 0;
        sr[0] <= 0; sr[1] <= 0;
        evb_cmd_finish <= 0;
    end else
    if(evb_cmd_finish) 
    begin
        issue <= 0;
        evb_cmd_finish <= 0;
    end else
    begin
        if(evb_cmd_request)
        begin
            if(!busy)
            case(evb_cmd_addr)
            `ADDRESS_ISSUE:
            begin
                evb_cmd_finish <= 1;
                block_address <= cmd;
                evb_cmd_rd_data <= reg_data;
            end
            `READ_ISSUE:
            begin
                evb_cmd_finish <= 1;
                if(evb_cmd_wr) issue <= 1;
                base_address <= cmd;
                evb_cmd_rd_data <= reg_data;
            end
            `WRITE_ISSUE:
            begin
            /* not implemented yet */
            end
            `DIVIDER_ISSUE:
            begin
                evb_cmd_finish <= 1;
                divider <= cmd;
                evb_cmd_rd_data <= reg_data;
            end
            endcase
            case(evb_cmd_addr)
            `SD_STATUS_ISSUE:
            begin
                evb_cmd_finish <= 1;
                en <= cmd[1];
                if(cmd[1] && !en) issue <= 1;
                evb_cmd_rd_data <= reg_data;
            end
            `REG_ISSUE:
            begin
                evb_cmd_finish <= 1;
                evb_cmd_rd_data <= reg_data;
            end
            endcase
        end
    end
end

integer fd_media;
initial
begin
    fd_media = $fopen("stream.flac", "rb");
end

integer cnt;
reg init;
`define READ_DELAY 128

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        test <= 0;
        init <= 0;
        busy <= 0;
        tcm_write_request <= 0;
        tcm_addr <= 0;
    end else
    if(!en)
    begin
        test <= 0;
        init <= 0;
    end else
    if(!busy)
    begin
        if(issue)
        begin
            if(init)
            begin
                cnt <= 0;
                busy <= 1;
                test <= 1;
                test_addr <= base_address;
                block_address <= block_address + 1;
                $display("read 512 bytes from %d to address %d\n", $ftell(fd_media), base_address);
            end else
            begin
                cnt <= 0;
                init <= 1;
                busy <= 1;
            end
        end
    end else
    begin
        test <= 0;
        cnt <= cnt + 1;
        if(cnt == `READ_DELAY) busy <= 0;
    end
end

integer count;
wire worker_en;
assign worker_en = count != 32;

reg[127:0] QA_BE;
assign tcm_write_data = {QA_BE[7:0], QA_BE[15:8], QA_BE[23:16], QA_BE[31:24],
             QA_BE[39:32], QA_BE[47:40], QA_BE[55:48], QA_BE[63:56],
             QA_BE[71:64], QA_BE[79:72], QA_BE[87:80], QA_BE[95:88],
             QA_BE[103:96], QA_BE[111:104], QA_BE[119:112], QA_BE[127:120]};

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        count <= 32;
        tcm_addr <= 0;
        tcm_write_request <= 0;
        QA_BE <= 0;
    end else
    begin
        if(test)
        begin
            count <= 0;
            tcm_addr <= test_addr;
            tcm_write_request <= 0;
        end else
        begin
            count <= worker_en && tcm_request_finish ? count + 1 : count;
            tcm_addr <= tcm_request_finish ? tcm_addr + 16 : tcm_addr;
        end
        if(!worker_en || (tcm_request_finish && count == 31))
        begin
            tcm_write_request <= 0;
        end else
        begin
            tcm_write_request <= 1;
        end
        if((tcm_write_request == 0 && worker_en) || (tcm_request_finish && count != 31)) $fread(QA_BE, fd_media);
        
    end
end

endmodule
