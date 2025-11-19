/*
Jump Unit - Calculates jump targets in ID stage
Handles JAL and JALR instructions with early resolution
*/

module JUMP_UNIT(
    input [31:0] pc,                // Current PC (from IF/ID register)
    input [31:0] pc_plus4,          // PC + 4 (return address)
    input [31:0] immediate,         // Jump offset from immediate generator
    input [31:0] rs1_data,          // Base register value (for JALR)
    input is_jal,                   // Is this JAL?
    input is_jalr,                  // Is this JALR?
    
    output [31:0] jump_target,      // Calculated jump address
    output is_jump,                 // Is this a jump instruction?
    output take_jump,               // Should we take this jump?
    output [31:0] return_address    // Return address (PC+4)
);

    wire [31:0] jal_target;
    wire [31:0] jalr_target;
    
    // JAL: target = PC + immediate
    assign jal_target = pc + immediate;
    
    // JALR: target = (rs1 + immediate) & ~1
    // Clear LSB to ensure even address alignment
    assign jalr_target = (rs1_data + immediate) & 32'hFFFFFFFE;
    
    // Select target based on instruction type
    assign jump_target = is_jalr ? jalr_target : jal_target;
    
    // Jump detection
    assign is_jump = is_jal || is_jalr;
    assign take_jump = is_jump;
    
    // Return address is always PC+4
    assign return_address = pc_plus4;

endmodule