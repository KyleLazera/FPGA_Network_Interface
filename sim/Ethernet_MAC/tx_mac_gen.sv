`timescale 1ns / 1ps
`ifndef _MAC_TX_GEN
`define _MAC_TX_GEN

//Include transaction Item class
`include "tx_mac_trans_item.sv"

class tx_mac_gen;
    //Mailbox to communicate with driver
    mailbox drv_mbx;
    //Used to control flow of generator from driver
    event drv_done;
    //Tag for printing/debugging
    string TAG = "Generator";
    
    //Constructor    
    function new(mailbox _drv_mbx, event _evt);
        drv_mbx = _drv_mbx;
        drv_done = _evt;
    endfunction : new
    
    task main();
        //Create an instance of teh transaction item that will be sent to teh driver
        tx_mac_trans_item gen_item = new(); 
        $display("[%s] Starting...", TAG);   
        
        //Used to randomize teh size of the packet
        gen_item.randomize();
        
        //Generate the number of bytes based on the packet size
        for(int i = 0; i < gen_item.pckt_size; i++) begin
            //Randomize the byte value
            gen_item.randomize(data_byte);
            //Send the byte to the driver
            drv_mbx.put(gen_item);
            //Wait for driver to indicate it has transmitted the byte
            @(drv_done);
        end
        
    endtask : main
    
endclass : tx_mac_gen

`endif// _MAC_TX_GEN