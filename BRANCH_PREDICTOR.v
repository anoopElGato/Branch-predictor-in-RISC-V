/*
Branch Predictor Top Module
Combines BHT, PHT, and BTB for two-level local branch prediction
*/

`include "BRANCH_HISTORY_TABLE.v"
`include "PATTERN_HISTORY_TABLE.v"
`include "BRANCH_TARGET_BUFFER.v"

module BRANCH_PREDICTOR(
    input clock,
    input reset,
    
    // Prediction interface (IF stage)
    input [31:0] if_pc,
    output predict_taken,
    output [31:0] predict_target,
    output target_valid,
    
    // Update interface (EX stage)
    input [31:0] ex_pc,
    input [31:0] ex_target,
    input ex_is_branch,
    input ex_branch_taken,
    input update_enable
);

    // Parameters
    parameter HISTORY_BITS = 4;
    parameter BHT_SIZE = 256;
    parameter PHT_SIZE = 1024;
    parameter BTB_SIZE = 256;
    
    // Internal wires
    wire [HISTORY_BITS-1:0] if_history;
    wire [HISTORY_BITS-1:0] ex_history;
    wire [9:0] if_pht_index;
    wire [9:0] ex_pht_index;
    
    // Compute PHT index: XOR of PC bits and history
    assign if_pht_index = if_pc[11:2] ^ {{(10-HISTORY_BITS){1'b0}}, if_history};
    assign ex_pht_index = ex_pc[11:2] ^ {{(10-HISTORY_BITS){1'b0}}, ex_history};
    
    // Branch History Table
    BRANCH_HISTORY_TABLE #(
        .HISTORY_BITS(HISTORY_BITS),
        .TABLE_SIZE(BHT_SIZE),
        .INDEX_BITS(8)
    ) bht (
        .clock(clock),
        .reset(reset),
        .pc(if_pc),
        .history(if_history),
        .update_pc(ex_pc),
        .update_enable(update_enable && ex_is_branch),
        .taken(ex_branch_taken)
    );
    
    // For reading ex_history (needed for update)
    reg [HISTORY_BITS-1:0] ex_history_reg;
    always @(posedge clock or posedge reset) begin
        if (reset)
            ex_history_reg <= {HISTORY_BITS{1'b0}};
        else
            ex_history_reg <= if_history;
    end
    assign ex_history = ex_history_reg;
    
    // Pattern History Table
    PATTERN_HISTORY_TABLE #(
        .TABLE_SIZE(PHT_SIZE),
        .INDEX_BITS(10)
    ) pht (
        .clock(clock),
        .reset(reset),
        .index(if_pht_index),
        .prediction(predict_taken),
        .update_index(ex_pht_index),
        .update_enable(update_enable && ex_is_branch),
        .actual_taken(ex_branch_taken)
    );
    
    // Branch Target Buffer
    BRANCH_TARGET_BUFFER #(
        .TABLE_SIZE(BTB_SIZE),
        .INDEX_BITS(8),
        .TAG_BITS(22)
    ) btb (
        .clock(clock),
        .reset(reset),
        .if_pc(if_pc),
        .target(predict_target),
        .valid(target_valid),
        .update_pc(ex_pc),
        .update_target(ex_target),
        .update_enable(update_enable && ex_is_branch && ex_branch_taken)
    );

endmodule