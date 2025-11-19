/*
Extended Control Unit with Branch and Jump Support
Supports R-type, I-type, S-type, B-type, and J-type instructions
*/

module CONTROL(
    input [6:0] funct7,
    input [2:0] funct3,
    input [6:0] opcode,
    output reg [3:0] alu_control,
    output reg regwrite_control,
    output reg mem_read,
    output reg mem_write,
    output reg mem_to_reg,
    output reg alu_src,
    output reg is_branch,
    output reg [2:0] branch_type,
    output reg is_jal,
    output reg is_jalr
);
    
    always @(*) begin
        // Default values
        regwrite_control = 0;
        mem_read = 0;
        mem_write = 0;
        mem_to_reg = 0;
        alu_src = 0;
        alu_control = 4'b0000;
        is_branch = 0;
        branch_type = 3'b000;
        is_jal = 0;
        is_jalr = 0;
        
        case (opcode)
            7'b0110011: begin // R-type instructions
                regwrite_control = 1;
                alu_src = 0;
                mem_to_reg = 0;
                
                case (funct3)
                    3'b000: begin
                        if(funct7 == 7'b0000000)
                            alu_control = 4'b0010; // ADD
                        else if(funct7 == 7'b0100000)
                            alu_control = 4'b0100; // SUB
                    end
                    3'b110: alu_control = 4'b0001; // OR
                    3'b111: alu_control = 4'b0000; // AND
                    3'b001: alu_control = 4'b0011; // SLL
                    3'b101: alu_control = 4'b0101; // SRL
                    3'b010: alu_control = 4'b0110; // MUL
                    3'b100: alu_control = 4'b0111; // XOR
                endcase
            end
            
            7'b0000011: begin // Load instructions (I-type)
                regwrite_control = 1;
                mem_read = 1;
                mem_write = 0;
                mem_to_reg = 1;
                alu_src = 1;
                alu_control = 4'b0010; // ADD for address calculation
            end
            
            7'b0100011: begin // Store instructions (S-type)
                regwrite_control = 0;
                mem_read = 0;
                mem_write = 1;
                mem_to_reg = 0;
                alu_src = 1;
                alu_control = 4'b0010; // ADD for address calculation
            end
            
            7'b0010011: begin // I-type ALU instructions
                regwrite_control = 1;
                mem_to_reg = 0;
                alu_src = 1;
                
                case (funct3)
                    3'b000: alu_control = 4'b0010; // ADDI
                    3'b110: alu_control = 4'b0001; // ORI
                    3'b111: alu_control = 4'b0000; // ANDI
                    3'b100: alu_control = 4'b0111; // XORI
                    3'b001: alu_control = 4'b0011; // SLLI
                    3'b101: alu_control = 4'b0101; // SRLI
                endcase
            end
            
            7'b1100011: begin // B-type branch instructions
                regwrite_control = 0;
                mem_read = 0;
                mem_write = 0;
                mem_to_reg = 0;
                alu_src = 0;
                is_branch = 1;
                branch_type = funct3;
                alu_control = 4'b0010; // ADD for target address calculation
            end
            
            7'b1101111: begin // JAL (Jump and Link)
                regwrite_control = 1;  // Write return address to rd
                mem_read = 0;
                mem_write = 0;
                mem_to_reg = 0;        // Write PC+4, not memory
                alu_src = 0;
                is_jal = 1;
                alu_control = 4'b0000;
            end
            
            7'b1100111: begin // JALR (Jump and Link Register)
                regwrite_control = 1;  // Write return address to rd
                mem_read = 0;
                mem_write = 0;
                mem_to_reg = 0;        // Write PC+4, not memory
                alu_src = 1;           // Use immediate (though not for ALU)
                is_jalr = 1;
                alu_control = 4'b0000;
            end
        endcase
    end

endmodule