module dbg(
    input clk,
    input rst,

    input evb_cmd_request,
    input[3:0] evb_cmd_addr,
    input[1:0] evb_cmd_wr_mask,
    input[31:0] evb_cmd_wr_data,
    output reg evb_cmd_finish,
    output reg[31:0] evb_cmd_rd_data,
    
    output reg led_a,
    output reg led_b,
    output reg led_c,
    output reg led_d,
    output reg led_e,
    output reg led_f,
    output reg led_g,
    output reg led_d1,
    output reg led_d2,
    output reg led_dp
);

integer i;
reg[31:0] dbg[15:0];

integer handle;
initial handle = $fopen("result.log", "w");

reg sel;
wire[3:0] digit;
assign digit = sel ? dbg[0][7:4] : dbg[0][3:0];

reg led_blink;

always @(*)
begin
    led_d1 <= sel ? 1 : 0;
    led_d2 <= sel ? 0 : 1;
    led_dp <= sel ? 0 : led_blink;
    case(digit)
    0:
    begin
        led_a <= 1;
        led_b <= 1;
        led_c <= 1;
        led_d <= 1;
        led_e <= 1;
        led_f <= 1;
        led_g <= 0;
    end
    1:
    begin
        led_a <= 0;
        led_b <= 1;
        led_c <= 1;
        led_d <= 0;
        led_e <= 0;
        led_f <= 0;
        led_g <= 0;
    end
    2:
    begin
        led_a <= 1;
        led_b <= 1;
        led_c <= 0;
        led_d <= 1;
        led_e <= 1;
        led_f <= 0;
        led_g <= 1;
    end
    3:
    begin
        led_a <= 1;
        led_b <= 1;
        led_c <= 1;
        led_d <= 1;
        led_e <= 0;
        led_f <= 0;
        led_g <= 1;
    end
    4:
    begin
        led_a <= 0;
        led_b <= 1;
        led_c <= 1;
        led_d <= 0;
        led_e <= 0;
        led_f <= 1;
        led_g <= 1;
    end
    5:
    begin
        led_a <= 1;
        led_b <= 0;
        led_c <= 1;
        led_d <= 1;
        led_e <= 0;
        led_f <= 1;
        led_g <= 1;
    end
    6:
    begin
        led_a <= 0;
        led_b <= 0;
        led_c <= 1;
        led_d <= 1;
        led_e <= 1;
        led_f <= 1;
        led_g <= 1;
    end
    7:
    begin
        led_a <= 1;
        led_b <= 1;
        led_c <= 1;
        led_d <= 0;
        led_e <= 0;
        led_f <= 0;
        led_g <= 0;
    end
    8:
    begin
        led_a <= 1;
        led_b <= 1;
        led_c <= 1;
        led_d <= 1;
        led_e <= 1;
        led_f <= 1;
        led_g <= 1;
    end
    9:
    begin
        led_a <= 1;
        led_b <= 1;
        led_c <= 1;
        led_d <= 0;
        led_e <= 0;
        led_f <= 1;
        led_g <= 1;
    end
    10:
    begin
        led_a <= 1;
        led_b <= 1;
        led_c <= 1;
        led_d <= 0;
        led_e <= 1;
        led_f <= 1;
        led_g <= 1;
    end
    11:
    begin
        led_a <= 0;
        led_b <= 0;
        led_c <= 1;
        led_d <= 1;
        led_e <= 1;
        led_f <= 1;
        led_g <= 1;
    end
    12:
    begin
        led_a <= 0;
        led_b <= 0;
        led_c <= 0;
        led_d <= 1;
        led_e <= 1;
        led_f <= 0;
        led_g <= 1;
    end
    13:
    begin
        led_a <= 0;
        led_b <= 1;
        led_c <= 1;
        led_d <= 1;
        led_e <= 1;
        led_f <= 0;
        led_g <= 1;
    end
    14:
    begin
        led_a <= 1;
        led_b <= 0;
        led_c <= 0;
        led_d <= 1;
        led_e <= 1;
        led_f <= 1;
        led_g <= 1;
    end
    15:
    begin
        led_a <= 1;
        led_b <= 0;
        led_c <= 0;
        led_d <= 0;
        led_e <= 1;
        led_f <= 1;
        led_g <= 1;
    end
    endcase
end

reg[24:0] led_busy_cnt;
reg[24:0] led_sel_cnt;

always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        led_busy_cnt <= 0;
        led_sel_cnt <= 0;
    end else
    begin
        if (led_busy_cnt == 24575999) //1Hz
        begin
            led_blink <= !led_blink;
            led_busy_cnt <=	0;
        end else
        begin
            led_busy_cnt <=	led_busy_cnt + 1;
        end
        if (led_sel_cnt == 24575) //1000Hz
        begin
            sel <= !sel;
            led_sel_cnt <=	0;
        end else
        begin
            led_sel_cnt <= led_sel_cnt + 1;
        end
    end
end
            
always @(posedge clk or posedge rst)
begin
    if(rst)
    begin
        for(i = 0; i < 16; i = i + 1) dbg[i] <= 0;
        evb_cmd_finish <= 0;
        evb_cmd_rd_data <= 0;
    end else
    if(evb_cmd_finish) evb_cmd_finish <= 0;
    else
    if(evb_cmd_request)
    begin
        evb_cmd_finish <= 1;
        dbg[evb_cmd_addr] <= evb_cmd_wr_data;
        //if(evb_cmd_addr == 2) $fwrite(handle, "pos%d result.h:%d result.l:%d\n", evb_cmd_wr_data, dbg[1], dbg[0]);
        //if(evb_cmd_addr == 4) $stop;
    end
end

endmodule
