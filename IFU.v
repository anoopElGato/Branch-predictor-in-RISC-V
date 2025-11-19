/*
Modified Instruction Fetch Unit with Branch Prediction and Jump Support
Priority: Branch Misprediction > Jump > Branch Prediction > PC+4
*/

`include "INST_MEM.v"

module IFU(
    input clock,
    input reset,
    
    // Branch prediction inputs
    input predict_taken,
    input [31:0] predict_target,
    input target_valid,
    
    // Branch misprediction recovery
    input flush,
    input [31:0] correct_pc,
    
    // Jump inputs (higher priority than prediction)
    input take_jump,
    input [31:0] jump_target,
    
    // Outputs
    output [31:0] instruction_code,
    output [31:0] pc_out,
    output [31:0] pc_plus4
);

    reg [31:0] PC = 32'b0;
    wire [31:0] next_pc;
    
    // Instruction memory
    INST_MEM instr_mem(PC, reset, instruction_code);
    
    // PC outputs
    assign pc_out = PC;
    assign pc_plus4 = PC + 4;
    
    // Next PC logic with priority ordering
    // Priority: flush (highest) > jump > branch prediction > PC+4 (lowest)
    assign next_pc = flush ? correct_pc :                                    // Misprediction recovery
                     take_jump ? jump_target :                               // Jump (unconditional)
                     (predict_taken && target_valid) ? predict_target :     // Branch prediction
                     PC + 4;                                                 // Normal increment
    
    // PC update
    always @(posedge clock or posedge reset) begin
        if (reset)
            PC <= 32'b0;
        else
            PC <= next_pc;
    end

endmodule