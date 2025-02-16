`include "defines.v"

`define EVB_PIC_ADDRESS     1
`define EVB_LPC_ADDRESS     2
`define EVB_PHY_ADDRESS     3
`define EVB_SDHCI_ADDRESS   4
`define EVB_DBG_ADDRESS     5

module bus(
    input clk,

    input mp_evb_cmd_request,
    input[15:0] mp_evb_cmd_addr,
    output reg mp_evb_cmd_finish,
    output reg[31:0] mp_evb_cmd_rd_data,

    output reg pic_evb_cmd_request,
    input pic_evb_cmd_finish,
    input[31:0] pic_evb_cmd_rd_data,
    
    output reg lpc_evb_cmd_request,
    input lpc_evb_cmd_finish,
    input[31:0] lpc_evb_cmd_rd_data,
    
    output reg phy_evb_cmd_request,
    input phy_evb_cmd_finish,
    input[31:0] phy_evb_cmd_rd_data,
    
    output reg sdhci_evb_cmd_request,
    input sdhci_evb_cmd_finish,
    input[31:0] sdhci_evb_cmd_rd_data,
    
    output reg dbg_evb_cmd_request,
    input dbg_evb_cmd_finish,
    input[31:0] dbg_evb_cmd_rd_data
);

wire[3:0] blkaddr;
assign blkaddr = mp_evb_cmd_addr[15:4];

always @(posedge clk or negedge mp_evb_cmd_request)
begin
    if(!mp_evb_cmd_request)
    begin
        pic_evb_cmd_request <= 0;
        lpc_evb_cmd_request <= 0;
        phy_evb_cmd_request <= 0;
        sdhci_evb_cmd_request <= 0;
        dbg_evb_cmd_request <= 0;
        mp_evb_cmd_finish <= 0;
    end else
    begin
        case(blkaddr)
        `EVB_PIC_ADDRESS:
        begin
            pic_evb_cmd_request <= !pic_evb_cmd_finish;
            mp_evb_cmd_finish <= pic_evb_cmd_finish;
            mp_evb_cmd_rd_data <= pic_evb_cmd_rd_data;
        end
        `EVB_LPC_ADDRESS:
        begin
            lpc_evb_cmd_request <= !lpc_evb_cmd_finish;
            mp_evb_cmd_finish <= lpc_evb_cmd_finish;
            mp_evb_cmd_rd_data <= lpc_evb_cmd_rd_data;
        end
        `EVB_PHY_ADDRESS:
        begin
            phy_evb_cmd_request <= !phy_evb_cmd_finish;
            mp_evb_cmd_finish <= phy_evb_cmd_finish;
            mp_evb_cmd_rd_data <= phy_evb_cmd_rd_data;
        end
        `EVB_SDHCI_ADDRESS:
        begin
            sdhci_evb_cmd_request <= !sdhci_evb_cmd_finish;
            mp_evb_cmd_finish <= sdhci_evb_cmd_finish;
            mp_evb_cmd_rd_data <= sdhci_evb_cmd_rd_data;
        end
        `EVB_DBG_ADDRESS:
        begin
            dbg_evb_cmd_request <= !dbg_evb_cmd_finish;
            mp_evb_cmd_finish <= dbg_evb_cmd_finish;
            mp_evb_cmd_rd_data <= dbg_evb_cmd_rd_data;
        end
        endcase
    end
end

endmodule
