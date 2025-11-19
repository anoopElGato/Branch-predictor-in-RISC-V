/*
Test Instruction Memory with Branch Instructions
Demonstrates branch prediction and handling
*/

module INST_MEM(
    input [31:0] PC,
    input reset,
    output [31:0] Instruction_Code
);
    reg [7:0] Memory [127:0];

    assign Instruction_Code = {Memory[PC+3],Memory[PC+2],Memory[PC+1],Memory[PC]};

    always @(reset)
    begin
        if(reset == 1)
        begin
            // Test program with branches and loops
            
            // Instruction 0: addi s0, x0, 10    (s0 = 10, loop counter)
            // PC = 0
            Memory[3] = 8'h00;
            Memory[2] = 8'hA0;
            Memory[1] = 8'h04;
            Memory[0] = 8'h13;
            
            // Instruction 4: addi s1, x0, 0     (s1 = 0, accumulator)
            // PC = 4
            Memory[7] = 8'h00;
            Memory[6] = 8'h00;
            Memory[5] = 8'h04;
            Memory[4] = 8'h93;
            
            // Loop start (PC = 8)
            // Instruction 8: add s1, s1, s0    (s1 = s1 + s0)
            Memory[11] = 8'h00;
            Memory[10] = 8'h84;
            Memory[9] = 8'h84;
            Memory[8] = 8'hB3;
            
            // Instruction 12: addi s0, s0, -1   (s0 = s0 - 1, decrement counter)
            Memory[15] = 8'hFF;
            Memory[14] = 8'hF4;
            Memory[13] = 8'h04;
            Memory[12] = 8'h13;
            
            // Instruction 16: bne s0, x0, -12   (if s0 != 0, branch back to PC=8)
            // Branch offset: -12 bytes = -3 instructions
            // B-type: imm[12|10:5] rs2 rs1 funct3 imm[4:1|11] opcode
            // imm = -12 (0xFFF4 in 13 bits) = 1111111110100
            // imm[12] = 1, imm[11] = 0, imm[10:5] = 111101, imm[4:1] = 0010
            Memory[19] = 8'hFE;
            Memory[18] = 8'h04;
            Memory[17] = 8'h16;
            Memory[16] = 8'h63;
            
            // Instruction 20: sw s1, 0(x0)      (Store result at address 0)
            Memory[23] = 8'h00;
            Memory[22] = 8'h90;
            Memory[21] = 8'h20;
            Memory[20] = 8'h23;
            
            // Instruction 24: lw t0, 0(x0)      (Load result to t0)
            Memory[27] = 8'h00;
            Memory[26] = 8'h00;
            Memory[25] = 8'h22;
            Memory[24] = 8'h83;
            
            // Instruction 28: addi t1, x0, 55   (t1 = 55 for comparison)
            Memory[31] = 8'h03;
            Memory[30] = 8'h70;
            Memory[29] = 8'h03;
            Memory[28] = 8'h13;
            
            // Instruction 32: beq t0, t1, 8     (if t0 == t1, branch forward)
            // Branch offset: +8 bytes = +2 instructions
            Memory[35] = 8'h00;
            Memory[34] = 8'h62;
            Memory[33] = 8'h84;
            Memory[32] = 8'h63;
            
            // Instruction 36: addi t2, x0, 0    (t2 = 0, fail case)
            Memory[39] = 8'h00;
            Memory[38] = 8'h00;
            Memory[37] = 8'h03;
            Memory[36] = 8'h93;
            
            // Instruction 40: NOP (skipped if branch taken)
            Memory[43] = 8'h00;
            Memory[42] = 8'h00;
            Memory[41] = 8'h00;
            Memory[40] = 8'h13;
            
            // Instruction 44: addi t2, x0, 1    (t2 = 1, success case)
            Memory[47] = 8'h00;
            Memory[46] = 8'h10;
            Memory[45] = 8'h03;
            Memory[44] = 8'h93;
            
            // Fill remaining memory with NOPs
            Memory[48] = 8'h00;
            Memory[49] = 8'h00;
            Memory[50] = 8'h00;
            Memory[51] = 8'h13;
            
        end
    end

endmodule

/*
Expected Execution:
1. s0 = 10, s1 = 0
2. Loop 10 times:
   - s1 += s0
   - s0 -= 1
   - Branch back if s0 != 0
3. Result: s1 = 10+9+8+7+6+5+4+3+2+1 = 55
4. Store s1, load to t0
5. Compare t0 with 55
6. Branch forward if equal (should be taken)
7. Set t2 = 1 (success indicator)

Branch prediction will:
- Learn that the BNE usually takes (backwards branch in loop)
- Learn that the BEQ is taken once
- Reduce branch penalties significantly
*/