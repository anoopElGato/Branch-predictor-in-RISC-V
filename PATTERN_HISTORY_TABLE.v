/*
Pattern History Table (PHT)
2-bit saturating counters for branch prediction
Part of two-level local branch predictor
*/

module PATTERN_HISTORY_TABLE #(
    parameter TABLE_SIZE = 1024,    // 1024 entries (2^10)
    parameter INDEX_BITS = 10       // log2(TABLE_SIZE)
)(
    input clock,
    input reset,
    
    // Prediction interface
    input [INDEX_BITS-1:0] index,
    output prediction,
    
    // Update interface
    input [INDEX_BITS-1:0] update_index,
    input update_enable,
    input actual_taken
);

    // PHT storage: array of 2-bit saturating counters
    reg [1:0] pht_table [TABLE_SIZE-1:0];
    
    // Read counter for prediction
    wire [1:0] counter;
    assign counter = pht_table[index];
    
    // Prediction is MSB of counter (1 = taken, 0 = not taken)
    assign prediction = counter[1];
    
    // Update counter on branch resolution
    integer i;
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            // Initialize all counters to weakly not taken (01)
            for (i = 0; i < TABLE_SIZE; i = i + 1) begin
                pht_table[i] <= 2'b01;
            end
        end else if (update_enable) begin
            // 2-bit saturating counter update logic
            case (pht_table[update_index])
                2'b00: begin // Strongly Not Taken
                    if (actual_taken)
                        pht_table[update_index] <= 2'b01; // -> Weakly Not Taken
                    // else stay at 00
                end
                
                2'b01: begin // Weakly Not Taken
                    if (actual_taken)
                        pht_table[update_index] <= 2'b10; // -> Weakly Taken
                    else
                        pht_table[update_index] <= 2'b00; // -> Strongly Not Taken
                end
                
                2'b10: begin // Weakly Taken
                    if (actual_taken)
                        pht_table[update_index] <= 2'b11; // -> Strongly Taken
                    else
                        pht_table[update_index] <= 2'b01; // -> Weakly Not Taken
                end
                
                2'b11: begin // Strongly Taken
                    if (!actual_taken)
                        pht_table[update_index] <= 2'b10; // -> Weakly Taken
                    // else stay at 11
                end
            endcase
        end
    end

endmodule