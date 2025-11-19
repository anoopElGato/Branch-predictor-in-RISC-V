/*
Branch History Table (BHT)
Stores the last N outcomes for each branch instruction
Part of two-level local branch predictor
*/

module BRANCH_HISTORY_TABLE #(
    parameter HISTORY_BITS = 4,     // Track last 4 outcomes
    parameter TABLE_SIZE = 256,     // 256 entries
    parameter INDEX_BITS = 8        // log2(TABLE_SIZE)
)(
    input clock,
    input reset,
    
    // Prediction interface (IF stage)
    input [31:0] pc,
    output [HISTORY_BITS-1:0] history,
    
    // Update interface (EX stage)
    input [31:0] update_pc,
    input update_enable,
    input taken
);

    // BHT storage: array of history shift registers
    reg [HISTORY_BITS-1:0] bht_table [TABLE_SIZE-1:0];
    
    // Index calculation (use PC[9:2] for word-aligned addresses)
    wire [INDEX_BITS-1:0] read_index;
    wire [INDEX_BITS-1:0] write_index;
    
    assign read_index = pc[INDEX_BITS+1:2];
    assign write_index = update_pc[INDEX_BITS+1:2];
    
    // Read history for prediction
    assign history = bht_table[read_index];
    
    // Update history on branch resolution
    integer i;
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            // Initialize all histories to 0 (not taken)
            for (i = 0; i < TABLE_SIZE; i = i + 1) begin
                bht_table[i] <= {HISTORY_BITS{1'b0}};
            end
        end else if (update_enable) begin
            // Shift history left, insert new outcome at LSB
            bht_table[write_index] <= {bht_table[write_index][HISTORY_BITS-2:0], taken};
        end
    end

endmodule