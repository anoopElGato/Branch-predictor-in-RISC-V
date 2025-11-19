/* 
Data Memory module for RISC-V processor
Supports byte-addressable memory with 128 locations (32 words)
Supports load word (lw) and store word (sw) instructions
*/

module DATA_MEM(
    input [31:0] address,        // Memory address
    input [31:0] write_data,     // Data to write
    input mem_write,             // Write enable signal
    input mem_read,              // Read enable signal
    input clock,
    input reset,
    output [31:0] read_data      // Data read from memory
);
    
    reg [7:0] Memory [127:0];    // Byte addressable memory with 128 locations
    
    // Read operation (combinational)
    assign read_data = mem_read ? {Memory[address+3], Memory[address+2], 
                                   Memory[address+1], Memory[address]} : 32'b0;
    
    // Write operation (sequential)
    always @(posedge clock) begin
        if (mem_write) begin
            Memory[address]   <= write_data[7:0];
            Memory[address+1] <= write_data[15:8];
            Memory[address+2] <= write_data[23:16];
            Memory[address+3] <= write_data[31:24];
        end
    end
    
    // Initialize memory on reset
    integer i;
    always @(posedge reset) begin
        if (reset) begin
            for (i = 0; i < 128; i = i + 1) begin
                Memory[i] <= 8'b0;
            end
        end
    end

endmodule