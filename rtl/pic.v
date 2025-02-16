`include "defines.v"

module pic(
    input clk,
    input rst,

    input[15:0] int_pulse,
    output mp_int,

    input[15:0] gpio_in,
    output reg[15:0] gpio_out,

    input evb_cmd_request,
    input[3:0] evb_cmd_addr, //15:4 device id, 3:0 sub id
    input[1:0] evb_cmd_wr_mask,
    input[31:0] evb_cmd_wr_data,
    output reg evb_cmd_finish,
    output reg[31:0] evb_cmd_rd_data
);

reg[15:0] irq_reg;
reg[15:0] irq_mask;

wire[15:0] irq;
assign irq = irq_reg & irq_mask;
assign mp_int = irq[0] || irq[1] || irq[2] || irq[3] ||
                irq[4] || irq[5] || irq[6] || irq[7] ||
                irq[8] || irq[9] || irq[10] || irq[11] ||
                irq[12] || irq[13] || irq[14] || irq[15];

reg[15:0] irq_reset;
reg[31:0] reg_data;
reg[31:0] reg_data_out;
always @(*)
begin
    case(evb_cmd_wr_mask)
    `EVB_MASK_W:     irq_reset <= evb_cmd_wr_data[15:0];
    `EVB_MASK_H:     irq_reset <= 16'h0;
    `EVB_MASK_L:     irq_reset <= evb_cmd_wr_data[15:0];
    `EVB_MASK_DUMMY: irq_reset <= 16'h0;
    endcase
end
always @(*)
begin
    case(evb_cmd_addr)
    1:  reg_data <= irq_mask;
    2:  reg_data <= gpio_out;
    endcase
end
always @(*)
begin
    case(evb_cmd_wr_mask)
    `EVB_MASK_W:     reg_data_out <= evb_cmd_wr_data;
    `EVB_MASK_H:     reg_data_out <= {evb_cmd_wr_data[15:0], reg_data[15:0]};
    `EVB_MASK_L:     reg_data_out <= {reg_data[31:16], evb_cmd_wr_data[15:0]};
    `EVB_MASK_DUMMY: reg_data_out <= reg_data;
    endcase
end

integer i;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        irq_reg <= 16'h0;
        irq_mask <= 16'hff;
        evb_cmd_finish <= 0;
        gpio_out <= 0;
    end else
    if(evb_cmd_finish) evb_cmd_finish <= 0;
    else
    begin
        for(i = 0; i < 16; i = i + 1)
        begin
            if(evb_cmd_request && evb_cmd_addr == 0 && irq_reset[i]) irq_reg[i] <= 0;
            else if(int_pulse[i]) irq_reg[i] <= 1;
        end
        if(evb_cmd_request)
        begin
            evb_cmd_finish <= 1;
            case(evb_cmd_addr)
            0: begin evb_cmd_rd_data <= {16'h0, irq_reg}; end
            1: begin evb_cmd_rd_data <= irq_mask; irq_mask <= reg_data_out; end
            2: begin evb_cmd_rd_data <= gpio_out; gpio_out <= reg_data_out; end
            3: begin evb_cmd_rd_data <= gpio_in; end
            endcase
        end
    end
end

endmodule
