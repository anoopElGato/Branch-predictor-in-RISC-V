/*
Testbench for Pipelined RISC-V Processor with Branch Prediction
Compatible with the original testbench structure
*/

`include "PROCESSOR.v"

module stimulus ();
    
    reg clock;
    reg reset;
    wire zero;
    
    // Optional: Debug signals (can be monitored but not required)
    wire [31:0] debug_pc;
    wire debug_misprediction;
    wire debug_jump;

    // Instantiating the processor with branch prediction
    PROCESSOR test_processor(
        .clock(clock),
        .reset(reset),
        .zero(zero),
        .debug_pc(debug_pc),
        .debug_misprediction(debug_misprediction),
        .debug_jump(debug_jump)
    );

    // Waveform dump for viewing in GTKWave
    initial begin
        $dumpfile("output_wave.vcd");
        $dumpvars(0, stimulus);
    end

    // Reset sequence
    initial begin
        reset = 1;
        #50 reset = 0;
    end

    // Clock generation (40 time units period = 20 up, 20 down)
    initial begin
        clock = 0;
        forever #20 clock = ~clock;
    end

    // Optional: Monitor branch predictions and mispredictions
    always @(posedge clock) begin
        if (!reset && debug_misprediction) begin
            $display("Time=%0t: Misprediction detected at PC=%h", $time, debug_pc);
        end
    end

    // Finish simulation after sufficient cycles
    // Increased from 300 to 1000 to allow loop completion
    initial
    #1000 $finish;
    
endmodule