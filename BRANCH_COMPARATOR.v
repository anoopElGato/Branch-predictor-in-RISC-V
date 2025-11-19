/*
Branch Comparator Module
Evaluates branch conditions for RISC-V B-type instructions
*/

module BRANCH_COMPARATOR(
    input [31:0] operand1,
    input [31:0] operand2,
    input [2:0] branch_type,    // funct3 field encodes branch type
    output reg condition_met
);

    // Signed comparison helpers
    wire signed [31:0] signed_op1;
    wire signed [31:0] signed_op2;
    assign signed_op1 = operand1;
    assign signed_op2 = operand2;
    
    always @(*) begin
        case (branch_type)
            3'b000: condition_met = (operand1 == operand2);           // BEQ
            3'b001: condition_met = (operand1 != operand2);           // BNE
            3'b100: condition_met = (signed_op1 < signed_op2);        // BLT
            3'b101: condition_met = (signed_op1 >= signed_op2);       // BGE
            3'b110: condition_met = (operand1 < operand2);            // BLTU (unsigned)
            3'b111: condition_met = (operand1 >= operand2);           // BGEU (unsigned)
            default: condition_met = 1'b0;
        endcase
    end

endmodule