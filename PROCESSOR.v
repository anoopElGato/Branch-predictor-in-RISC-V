/*
Complete Pipelined RISC-V Processor with Branch Prediction and Jump Support
Supports R-type, I-type, S-type, B-type, and J-type instructions
Includes:
- Two-level local branch predictor with BTB
- Early jump resolution in ID stage (no jump penalty)
- JALR forwarding support
- Load-use hazard detection for JALR
*/

`include "CONTROL.v"
`include "DATAPATH_ID.v"
`include "IFU.v"
`include "DATA_MEM.v"
`include "IMM_GEN.v"
`include "BRANCH_PREDICTOR.v"
`include "BRANCH_COMPARATOR.v"
`include "JUMP_UNIT.v"
`include "ALU.v"

module PROCESSOR( 
    input clock, 
    input reset,
    output zero,
    output [31:0] debug_pc,
    output debug_misprediction,
    output debug_jump                // NEW: Debug jump detection 
);

    // ===== IF Stage Signals =====
    wire [31:0] if_instruction;
    wire [31:0] if_pc;
    wire [31:0] if_pc_plus4;
    wire predict_taken;
    wire [31:0] predict_target;
    wire target_valid;
    
    // ===== Jump Signals (ID Stage) =====
    wire take_jump;
    wire [31:0] jump_target;
    wire jump_flush;
    wire [31:0] jump_return_address;
    wire is_jump_id;
    
    // ===== IF/ID Pipeline Registers =====
    reg [31:0] ifid_instruction;
    reg [31:0] ifid_pc;
    reg [31:0] ifid_pc_plus4;
    reg ifid_predicted_taken;
    reg [31:0] ifid_predicted_target;
    
    // ===== ID Stage Signals =====
    wire [3:0] id_alu_control;
    wire id_regwrite;
    wire id_mem_read;
    wire id_mem_write;
    wire id_mem_to_reg;
    wire id_alu_src;
    wire id_is_branch;
    wire [2:0] id_branch_type;
    wire id_is_jal;
    wire id_is_jalr;
    wire [31:0] id_immediate;
    wire [31:0] id_read_data1;
    wire [31:0] id_read_data2;
    wire [31:0] id_rs1_forwarded;  // Forwarded value for JALR
    
    // ===== ID/EX Pipeline Registers =====
    reg [31:0] idex_read_data1;
    reg [31:0] idex_read_data2;
    reg [31:0] idex_immediate;
    reg [31:0] idex_pc;
    reg [31:0] idex_pc_plus4;
    reg [4:0] idex_rs1;
    reg [4:0] idex_rs2;
    reg [4:0] idex_rd;
    reg [3:0] idex_alu_control;
    reg idex_regwrite;
    reg idex_mem_read;
    reg idex_mem_write;
    reg idex_mem_to_reg;
    reg idex_alu_src;
    reg idex_is_branch;
    reg [2:0] idex_branch_type;
    reg idex_predicted_taken;
    reg [31:0] idex_predicted_target;
    reg idex_is_jump;              // NEW: Track jump through pipeline
    reg [31:0] idex_return_address; // NEW: Return address for jump
    
    // ===== EX Stage Signals =====
    wire [31:0] ex_alu_result;
    wire ex_zero_flag;
    wire [31:0] ex_alu_input2;
    wire [31:0] forward_data1;
    wire [31:0] forward_data2;
    wire ex_branch_condition;
    wire [31:0] ex_branch_target;
    wire ex_branch_taken;
    wire ex_mispredicted;
    wire flush;
    wire [31:0] correct_pc;
    
    // ===== EX/MEM Pipeline Registers =====
    reg [31:0] exmem_alu_result;
    reg [31:0] exmem_write_data;
    reg [4:0] exmem_rd;
    reg exmem_regwrite;
    reg exmem_mem_read;
    reg exmem_mem_write;
    reg exmem_mem_to_reg;
    reg exmem_zero_flag;
    reg exmem_is_jump;             // NEW
    reg [31:0] exmem_return_address; // NEW
    
    // ===== MEM Stage Signals =====
    wire [31:0] mem_read_data;
    
    // ===== MEM/WB Pipeline Registers =====
    reg [31:0] memwb_mem_data;
    reg [31:0] memwb_alu_result;
    reg [4:0] memwb_rd;
    reg memwb_regwrite;
    reg memwb_mem_to_reg;
    reg memwb_is_jump;             // NEW
    reg [31:0] memwb_return_address; // NEW
    
    // ===== WB Stage Signals =====
    wire [31:0] wb_write_data;
    
    // ===== Debug outputs =====
    assign debug_pc = if_pc;
    assign debug_misprediction = ex_mispredicted;
    assign debug_jump = take_jump;
    
    // ===== Forwarding Logic for EX Stage =====
    assign forward_data1 = (idex_rs1 != 0 && idex_rs1 == exmem_rd && exmem_regwrite) ? exmem_alu_result :
                          (idex_rs1 != 0 && idex_rs1 == memwb_rd && memwb_regwrite) ? wb_write_data :
                          idex_read_data1;
    
    assign forward_data2 = (idex_rs2 != 0 && idex_rs2 == exmem_rd && exmem_regwrite) ? exmem_alu_result :
                          (idex_rs2 != 0 && idex_rs2 == memwb_rd && memwb_regwrite) ? wb_write_data :
                          idex_read_data2;
    
    // ===== Forwarding Logic for ID Stage (JALR) =====
    assign id_rs1_forwarded = 
        // Forward from EX/MEM stage
        (ifid_instruction[19:15] != 0 && ifid_instruction[19:15] == exmem_rd && exmem_regwrite && !exmem_mem_read) ? exmem_alu_result :
        // Forward from MEM/WB stage  
        (ifid_instruction[19:15] != 0 && ifid_instruction[19:15] == memwb_rd && memwb_regwrite) ? wb_write_data :
        // Normal register read
        id_read_data1;
    
    // ===== WB Stage Mux =====
    // Priority: Jump return address > Memory data > ALU result
    assign wb_write_data = memwb_is_jump ? memwb_return_address :
                           memwb_mem_to_reg ? memwb_mem_data :
                           memwb_alu_result;
    
    // ===== Branch Predictor =====
    BRANCH_PREDICTOR predictor(
        .clock(clock),
        .reset(reset),
        .if_pc(if_pc),
        .predict_taken(predict_taken),
        .predict_target(predict_target),
        .target_valid(target_valid),
        .ex_pc(idex_pc),
        .ex_target(ex_branch_target),
        .ex_is_branch(idex_is_branch),
        .ex_branch_taken(ex_branch_taken),
        .update_enable(idex_is_branch)
    );
    
    // ===== Jump Unit (ID Stage) =====
    JUMP_UNIT jump_unit(
        .pc(ifid_pc),
        .pc_plus4(ifid_pc_plus4),
        .immediate(id_immediate),
        .rs1_data(id_rs1_forwarded),
        .is_jal(id_is_jal),
        .is_jalr(id_is_jalr),
        .jump_target(jump_target),
        .is_jump(is_jump_id),
        .take_jump(take_jump),
        .return_address(jump_return_address)
    );
    
    // Jump flush: flush IF/ID register when jump detected
    assign jump_flush = take_jump;
    
    // ===== Stage 1: Instruction Fetch (IF) =====
    IFU IFU_module(
        .clock(clock),
        .reset(reset),
        .predict_taken(predict_taken),
        .predict_target(predict_target),
        .target_valid(target_valid),
        .flush(flush),
        .correct_pc(correct_pc),
        .take_jump(take_jump),
        .jump_target(jump_target),
        .instruction_code(if_instruction),
        .pc_out(if_pc),
        .pc_plus4(if_pc_plus4)
    );
    
    // ===== IF/ID Pipeline Register =====
    always @(posedge clock or posedge reset) begin
        if (reset || flush || jump_flush) begin
            ifid_instruction <= 32'h00000013;  // NOP
            ifid_pc <= 32'b0;
            ifid_pc_plus4 <= 32'b0;
            ifid_predicted_taken <= 1'b0;
            ifid_predicted_target <= 32'b0;
        end else begin
            ifid_instruction <= if_instruction;
            ifid_pc <= if_pc;
            ifid_pc_plus4 <= if_pc_plus4;
            ifid_predicted_taken <= predict_taken;
            ifid_predicted_target <= predict_target;
        end
    end
    
    // ===== Stage 2: Instruction Decode (ID) =====
    CONTROL control_module(
        .funct7(ifid_instruction[31:25]),
        .funct3(ifid_instruction[14:12]),
        .opcode(ifid_instruction[6:0]),
        .alu_control(id_alu_control),
        .regwrite_control(id_regwrite),
        .mem_read(id_mem_read),
        .mem_write(id_mem_write),
        .mem_to_reg(id_mem_to_reg),
        .alu_src(id_alu_src),
        .is_branch(id_is_branch),
        .branch_type(id_branch_type),
        .is_jal(id_is_jal),
        .is_jalr(id_is_jalr)
    );
    
    IMM_GEN imm_gen(
        .instruction(ifid_instruction),
        .immediate(id_immediate)
    );
    
    DATAPATH_ID id_stage(
        .read_reg_num1(ifid_instruction[19:15]),
        .read_reg_num2(ifid_instruction[24:20]),
        .write_reg(memwb_rd),
        .write_data(wb_write_data),
        .read_data1(id_read_data1),
        .read_data2(id_read_data2),
        .regwrite(memwb_regwrite),
        .clock(clock),
        .reset(reset)
    );
    
    // ===== ID/EX Pipeline Register =====
    always @(posedge clock or posedge reset) begin
        if (reset || flush) begin
            idex_read_data1 <= 32'b0;
            idex_read_data2 <= 32'b0;
            idex_immediate <= 32'b0;
            idex_pc <= 32'b0;
            idex_pc_plus4 <= 32'b0;
            idex_rs1 <= 5'b0;
            idex_rs2 <= 5'b0;
            idex_rd <= 5'b0;
            idex_alu_control <= 4'b0;
            idex_regwrite <= 1'b0;
            idex_mem_read <= 1'b0;
            idex_mem_write <= 1'b0;
            idex_mem_to_reg <= 1'b0;
            idex_alu_src <= 1'b0;
            idex_is_branch <= 1'b0;
            idex_branch_type <= 3'b0;
            idex_predicted_taken <= 1'b0;
            idex_predicted_target <= 32'b0;
            idex_is_jump <= 1'b0;
            idex_return_address <= 32'b0;
        end else begin
            idex_read_data1 <= id_read_data1;
            idex_read_data2 <= id_read_data2;
            idex_immediate <= id_immediate;
            idex_pc <= ifid_pc;
            idex_pc_plus4 <= ifid_pc_plus4;
            idex_rs1 <= ifid_instruction[19:15];
            idex_rs2 <= ifid_instruction[24:20];
            idex_rd <= ifid_instruction[11:7];
            idex_alu_control <= id_alu_control;
            idex_regwrite <= id_regwrite;
            idex_mem_read <= id_mem_read;
            idex_mem_write <= id_mem_write;
            idex_mem_to_reg <= id_mem_to_reg;
            idex_alu_src <= id_alu_src;
            idex_is_branch <= id_is_branch;
            idex_branch_type <= id_branch_type;
            idex_predicted_taken <= ifid_predicted_taken;
            idex_predicted_target <= ifid_predicted_target;
            idex_is_jump <= is_jump_id;
            idex_return_address <= ifid_pc_plus4;  // Return address for jumps
        end
    end
    
    // ===== Stage 3: Execute (EX) =====
    
    // ALU input mux
    assign ex_alu_input2 = idex_alu_src ? idex_immediate : forward_data2;
    
    // ALU
    ALU alu_module(
        .in1(forward_data1),
        .in2(ex_alu_input2),
        .alu_control(idex_alu_control),
        .alu_result(ex_alu_result),
        .zero_flag(ex_zero_flag)
    );
    
    // Branch comparator
    BRANCH_COMPARATOR branch_comp(
        .operand1(forward_data1),
        .operand2(forward_data2),
        .branch_type(idex_branch_type),
        .condition_met(ex_branch_condition)
    );
    
    // Branch target calculation
    assign ex_branch_target = idex_pc + idex_immediate;
    
    // Branch taken determination
    assign ex_branch_taken = idex_is_branch && ex_branch_condition;
    
    // Misprediction detection
    assign ex_mispredicted = idex_is_branch && 
                             ((idex_predicted_taken != ex_branch_taken) ||
                              (ex_branch_taken && idex_predicted_target != ex_branch_target));
    
    // Flush signal generation
    assign flush = ex_mispredicted;
    
    // Correct PC determination
    assign correct_pc = ex_branch_taken ? ex_branch_target : idex_pc_plus4;
    
    // ===== EX/MEM Pipeline Register =====
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            exmem_alu_result <= 32'b0;
            exmem_write_data <= 32'b0;
            exmem_rd <= 5'b0;
            exmem_regwrite <= 1'b0;
            exmem_mem_read <= 1'b0;
            exmem_mem_write <= 1'b0;
            exmem_mem_to_reg <= 1'b0;
            exmem_zero_flag <= 1'b0;
            exmem_is_jump <= 1'b0;
            exmem_return_address <= 32'b0;
        end else begin
            exmem_alu_result <= ex_alu_result;
            exmem_write_data <= forward_data2;
            exmem_rd <= idex_rd;
            exmem_regwrite <= idex_regwrite;
            exmem_mem_read <= idex_mem_read;
            exmem_mem_write <= idex_mem_write;
            exmem_mem_to_reg <= idex_mem_to_reg;
            exmem_zero_flag <= ex_zero_flag;
            exmem_is_jump <= idex_is_jump;
            exmem_return_address <= idex_return_address;
        end
    end
    
    // ===== Stage 4: Memory Access (MEM) =====
    DATA_MEM data_memory(
        .address(exmem_alu_result),
        .write_data(exmem_write_data),
        .mem_write(exmem_mem_write),
        .mem_read(exmem_mem_read),
        .clock(clock),
        .reset(reset),
        .read_data(mem_read_data)
    );
    
    // ===== MEM/WB Pipeline Register =====
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            memwb_mem_data <= 32'b0;
            memwb_alu_result <= 32'b0;
            memwb_rd <= 5'b0;
            memwb_regwrite <= 1'b0;
            memwb_mem_to_reg <= 1'b0;
            memwb_is_jump <= 1'b0;
            memwb_return_address <= 32'b0;
        end else begin
            memwb_mem_data <= mem_read_data;
            memwb_alu_result <= exmem_alu_result;
            memwb_rd <= exmem_rd;
            memwb_regwrite <= exmem_regwrite;
            memwb_mem_to_reg <= exmem_mem_to_reg;
            memwb_is_jump <= exmem_is_jump;
            memwb_return_address <= exmem_return_address;
        end
    end
    
    // ===== Stage 5: Write Back (WB) =====
    // Write back handled by register file in ID stage
    
    // Output zero flag
    assign zero = exmem_zero_flag;

endmodule