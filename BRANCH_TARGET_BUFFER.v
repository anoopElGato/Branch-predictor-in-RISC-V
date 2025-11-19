/*
Branch Target Buffer (BTB)
Caches branch target addresses to avoid recalculation
Direct-mapped cache structure
*/

module BRANCH_TARGET_BUFFER #(
    parameter TABLE_SIZE = 256,     // 256 entries
    parameter INDEX_BITS = 8,       // log2(TABLE_SIZE)
    parameter TAG_BITS = 22         // 32 - INDEX_BITS - 2 (word aligned)
)(
    input clock,
    input reset,
    
    // Lookup interface (IF stage)
    input [31:0] if_pc,
    output [31:0] target,
    output valid,
    
    // Update interface (EX stage)
    input [31:0] update_pc,
    input [31:0] update_target,
    input update_enable
);

    // BTB entry structure: {valid, tag, target}
    reg btb_valid [TABLE_SIZE-1:0];
    reg [TAG_BITS-1:0] btb_tag [TABLE_SIZE-1:0];
    reg [31:0] btb_target [TABLE_SIZE-1:0];
    
    // Index and tag extraction
    wire [INDEX_BITS-1:0] read_index;
    wire [TAG_BITS-1:0] read_tag;
    wire [INDEX_BITS-1:0] write_index;
    wire [TAG_BITS-1:0] write_tag;
    
    assign read_index = if_pc[INDEX_BITS+1:2];
    assign read_tag = if_pc[31:INDEX_BITS+2];
    assign write_index = update_pc[INDEX_BITS+1:2];
    assign write_tag = update_pc[31:INDEX_BITS+2];
    
    // Hit detection
    wire hit;
    assign hit = btb_valid[read_index] && (btb_tag[read_index] == read_tag);
    assign valid = hit;
    
    // Target output
    assign target = hit ? btb_target[read_index] : 32'b0;
    
    // Update BTB on branch execution
    integer i;
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            // Initialize all entries as invalid
            for (i = 0; i < TABLE_SIZE; i = i + 1) begin
                btb_valid[i] <= 1'b0;
                btb_tag[i] <= {TAG_BITS{1'b0}};
                btb_target[i] <= 32'b0;
            end
        end else if (update_enable) begin
            // Write new entry
            btb_valid[write_index] <= 1'b1;
            btb_tag[write_index] <= write_tag;
            btb_target[write_index] <= update_target;
        end
    end

endmodule