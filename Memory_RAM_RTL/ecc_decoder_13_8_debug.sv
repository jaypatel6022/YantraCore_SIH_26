`timescale 1ns/1ps

module ecc_decoder_13_8_debug (

    input  logic [12:0] codeword_in,

    output logic [7:0]  data_out,

    output logic        single_error_corrected,
    output logic        double_error_detected,

    // =========================================================
    // DEBUG OUTPUTS
    // =========================================================

    output logic [3:0] syndrome_dbg,
    output logic       overall_parity_dbg,

    output logic [3:0] correction_position_dbg,
    output logic       correction_applied_dbg,

    output logic [2:0] error_class_dbg,

    // NEW
    output logic       uncorrectable_error_dbg

);

    // =========================================================
    // Internal signals
    // =========================================================

    logic [12:0] corrected_codeword;

    logic [3:0] syndrome;

    logic overall_parity;


    // =========================================================
    // Error classification
    //
    // 0 = NO_ERROR
    // 1 = SINGLE_BIT_CORRECTION
    // 2 = DOUBLE_BIT_DETECTED
    // 3 = OVERALL_PARITY_ERROR
    // 4 = UNCORRECTABLE
    // =========================================================

    localparam logic [2:0] CLASS_NO_ERROR =
        3'd0;

    localparam logic [2:0] CLASS_SINGLE =
        3'd1;

    localparam logic [2:0] CLASS_DOUBLE =
        3'd2;

    localparam logic [2:0] CLASS_OVERALL_PARITY =
        3'd3;

    localparam logic [2:0] CLASS_UNCORRECTABLE =
        3'd4;


    // =========================================================
    // Decoder
    // =========================================================

    always_comb begin

        // -----------------------------------------------------
        // Defaults
        // -----------------------------------------------------

        syndrome = 4'b0000;

        overall_parity = 1'b0;

        corrected_codeword = codeword_in;

        data_out = 8'b0;

        single_error_corrected = 1'b0;

        double_error_detected = 1'b0;

        uncorrectable_error_dbg = 1'b0;


        // Debug defaults

        syndrome_dbg = 4'b0000;

        overall_parity_dbg = 1'b0;

        correction_position_dbg = 4'b0000;

        correction_applied_dbg = 1'b0;

        error_class_dbg = CLASS_NO_ERROR;


        // =====================================================
        // Hamming syndrome
        // =====================================================

        syndrome[0] =
            codeword_in[0] ^
            codeword_in[2] ^
            codeword_in[4] ^
            codeword_in[6] ^
            codeword_in[8] ^
            codeword_in[10];

        syndrome[1] =
            codeword_in[1] ^
            codeword_in[2] ^
            codeword_in[5] ^
            codeword_in[6] ^
            codeword_in[9] ^
            codeword_in[10];

        syndrome[2] =
            codeword_in[3] ^
            codeword_in[4] ^
            codeword_in[5] ^
            codeword_in[6] ^
            codeword_in[11];

        syndrome[3] =
            codeword_in[7] ^
            codeword_in[8] ^
            codeword_in[9] ^
            codeword_in[10] ^
            codeword_in[11];


        // =====================================================
        // Overall parity
        // =====================================================

        overall_parity = ^codeword_in;


        // Debug outputs

        syndrome_dbg = syndrome;

        overall_parity_dbg = overall_parity;


        // =====================================================
        // SEC-DED decoding
        // =====================================================

        if ((overall_parity == 1'b0) &&
            (syndrome == 4'd0)) begin

            // -------------------------------------------------
            // No detected error
            // -------------------------------------------------

            error_class_dbg = CLASS_NO_ERROR;

        end

        else if ((overall_parity == 1'b1) &&
                 (syndrome != 4'd0)) begin

            // -------------------------------------------------
            // Single-bit error
            //
            // Valid Hamming positions are 1..12.
            // -------------------------------------------------

            if (syndrome <= 4'd12) begin

                correction_position_dbg = syndrome;

                corrected_codeword[syndrome - 1] =
                    ~corrected_codeword[syndrome - 1];

                correction_applied_dbg = 1'b1;

                single_error_corrected = 1'b1;

                error_class_dbg = CLASS_SINGLE;

            end

            else begin

                // Syndrome 13,14,15 is outside the
                // valid 12-bit Hamming position range.

                uncorrectable_error_dbg = 1'b1;

                error_class_dbg = CLASS_UNCORRECTABLE;

            end

        end

        else if ((overall_parity == 1'b1) &&
                 (syndrome == 4'd0)) begin

            // -------------------------------------------------
            // Error only in overall parity bit
            //
            // Data bits are already valid.
            // -------------------------------------------------

            single_error_corrected = 1'b1;

            correction_position_dbg = 4'd13;

            correction_applied_dbg = 1'b0;

            error_class_dbg = CLASS_OVERALL_PARITY;

        end

        else if ((overall_parity == 1'b0) &&
                 (syndrome != 4'd0)) begin

            // -------------------------------------------------
            // Double-bit error detected.
            //
            // DO NOT CORRECT.
            // -------------------------------------------------

            double_error_detected = 1'b1;

            error_class_dbg = CLASS_DOUBLE;

        end

        else begin

            // -------------------------------------------------
            // Defensive fallback
            // -------------------------------------------------

            uncorrectable_error_dbg = 1'b1;

            error_class_dbg = CLASS_UNCORRECTABLE;

        end


        // =====================================================
        // Extract data
        // =====================================================

        data_out[0] = corrected_codeword[2];
        data_out[1] = corrected_codeword[4];
        data_out[2] = corrected_codeword[5];
        data_out[3] = corrected_codeword[6];

        data_out[4] = corrected_codeword[8];
        data_out[5] = corrected_codeword[9];
        data_out[6] = corrected_codeword[10];
        data_out[7] = corrected_codeword[11];

    end

endmodule