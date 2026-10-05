`timescale 1ns/1ps

module ecc_sram_debug #(

    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8,
    parameter CODE_WIDTH = 13,
    parameter DEPTH      = 256

)(

    input  logic                  clk,
    input  logic                  rst,

    input  logic                  we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] wdata,

    output logic [DATA_WIDTH-1:0] rdata,

    output logic single_error_corrected,
    output logic double_error_detected,

    // =========================================================
    // DEBUG OUTPUTS
    // =========================================================

    output logic [3:0] syndrome_dbg,

    output logic overall_parity_dbg,

    output logic [3:0] correction_position_dbg,

    output logic correction_applied_dbg,

    output logic [2:0] error_class_dbg,

    output logic uncorrectable_error_dbg

);


    // =========================================================
    // Physical SRAM
    // =========================================================

    logic [CODE_WIDTH-1:0] mem [0:DEPTH-1];


    // =========================================================
    // ECC signals
    // =========================================================

    logic [CODE_WIDTH-1:0] encoded_data;

    logic [CODE_WIDTH-1:0] stored_codeword;

    logic [DATA_WIDTH-1:0] decoded_data;


    // =========================================================
    // Encoder
    // =========================================================

    ecc_encoder_8_13 encoder (

        .data_in      (wdata),

        .codeword_out (encoded_data)

    );


    // =========================================================
    // Debug decoder
    // =========================================================

    ecc_decoder_13_8_debug decoder (

        .codeword_in  (stored_codeword),

        .data_out     (decoded_data),

        .single_error_corrected
                       (single_error_corrected),

        .double_error_detected
                       (double_error_detected),

        .syndrome_dbg
                       (syndrome_dbg),

        .overall_parity_dbg
                       (overall_parity_dbg),

        .correction_position_dbg
                       (correction_position_dbg),

        .correction_applied_dbg
                       (correction_applied_dbg),

        .error_class_dbg
                       (error_class_dbg),

        .uncorrectable_error_dbg
                       (uncorrectable_error_dbg)

    );


    // =========================================================
    // Read physical SRAM
    // =========================================================

    always_comb begin

        stored_codeword = mem[addr];

    end


    // =========================================================
    // SRAM operation
    // =========================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            rdata <= '0;
        end

        else begin

            if (we) begin

                mem[addr] <= encoded_data;
            end

            else begin

                rdata <= decoded_data;
            end

        end

    end

endmodule