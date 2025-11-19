/*
Datapath module for the ID stage - only contains register file
for reading registers. The ALU is now in the EX stage.
*/
`include "REG_FILE.v"

module DATAPATH_ID(
    input [4:0] read_reg_num1,
    input [4:0] read_reg_num2,
    input [4:0] write_reg,
    input [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2,
    input regwrite,
    input clock,
    input reset
);

    // Instantiating the register file
    // Read happens in ID stage, write happens in WB stage
    REG_FILE reg_file_module(
        .read_reg_num1(read_reg_num1),
        .read_reg_num2(read_reg_num2),
        .write_reg(write_reg),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2),
        .regwrite(regwrite),
        .clock(clock),
        .reset(reset)
    );

endmodule