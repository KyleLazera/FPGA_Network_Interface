`ifndef _TX_MAC_SCB
`define _TX_MAC_SCB

`include "tx_mac_trans_item.sv"

/* 
 * Scoreboard Checks:
 * 1) Ensure the preamble abides by the following pattern: 7 bytes of 8'h55 followed by 1 byte of 8'hD5
 * 2) Ensure the payload size is between 46 - 1500 bytes
 * 3) Use a reference model to confirm the CRC calclation
*/

class tx_mac_scb;
    localparam DATA_WIDTH = 8;
    localparam CRC_WIDTH = 32;
    localparam TABLE_DEPTH = (2**DATA_WIDTH);
    
    //Mailbox from monitor
    mailbox scb_mbx;
    event scb_done;
    //LUT Declaration
    logic [CRC_WIDTH-1:0] crc_lut [TABLE_DEPTH-1:0];            
    //Tag for debugging/printing
    string TAG = "Scoreboard";
    
    //Constructor
    function new(mailbox _mbx, event _evt);
        scb_mbx = _mbx;
        scb_done = _evt;
    endfunction : new
    
    task main();
        tx_mac_trans_item mon_item;
        int pckt_num = 0;
        $display("[%s] Starting...", TAG);
        
        //LUT Init
        $readmemb("C:/Users/klaze/Xilinx_FGPA_Projects/FPGA_Based_Network_Stack/Software/CRC_LUT.txt", crc_lut);
        
        forever begin
            //Fetch data from queue
            scb_mbx.get(mon_item);        
            
            /* Check Preamble Pattern */
            assert( {mon_item.preamble[0], mon_item.preamble[1], mon_item.preamble[2], mon_item.preamble[3], 
                    mon_item.preamble[4], mon_item.preamble[5], mon_item.preamble[6], mon_item.preamble[7]} 
                    == {{7{8'h55}}, 8'hD5} ) else $fatal(2, "Preamble mismatch: %0h", {mon_item.preamble[0], mon_item.preamble[1], mon_item.preamble[2], mon_item.preamble[3], 
                    mon_item.preamble[4], mon_item.preamble[5], mon_item.preamble[6], mon_item.preamble[7]});
            
            /* Check Payload Size is between 46 bytes and 1500 bytes*/
            assert(mon_item.payload.size() >= 46 && mon_item.payload.size() <= 1500) 
                else $fatal(2, "Payload Size does not fall within range.");
                
            /* Check CRC Calculation */         
            assert(crc32_reference_model(mon_item.payload) == {mon_item.fcs[3], mon_item.fcs[2], mon_item.fcs[1], mon_item.fcs[0]})
                else $fatal(2, "CRC-32 Failed");
                
            if(pckt_num == 9)
                ->scb_done;
            else
                pckt_num++;
                
        end
                
    endtask : main
    
    
     /*
     * @Brief Reference Model that implements the CRC32 algorithm for each byte passed into it
     * @param i_byte Takes in a byte to pass into the model
     * @retval Returns the CRC32 current CRC value to append to the data message
    */
    function automatic [31:0] crc32_reference_model;
        input [7:0] i_byte_stream[];
        
        /* Intermediary Signals */
        reg [31:0] crc_state = 32'hFFFFFFFF;
        reg [31:0] crc_state_rev;
        reg [7:0] i_byte_rev, table_index;
        integer i;
        
        //Iterate through each byte in the stream
        foreach(i_byte_stream[i]) begin
             /* Reverse the bit order of the byte in question */
             i_byte_rev = 0;
             for(int j = 0; j < 8; j++)
                i_byte_rev[j] = i_byte_stream[i][(DATA_WIDTH-1)-j];
                
             /* XOR this value with the MSB of teh current CRC State */
             table_index = i_byte_rev ^ crc_state[31:24];
             
             /* Index into the LUT and XOR the output with the shifted CRC */
             crc_state = {crc_state[24:0], 8'h0} ^ crc_lut[table_index];
        end
        
        /* Reverse & Invert the final CRC State after all bytes have been iterated through */
        crc_state_rev = 32'h0;
        for(int k = 0; k < 32; k++) 
            crc_state_rev[k] = crc_state[(CRC_WIDTH-1)-k];
        
        crc32_reference_model = ~crc_state_rev;
        
    endfunction : crc32_reference_model   

endclass : tx_mac_scb

`endif