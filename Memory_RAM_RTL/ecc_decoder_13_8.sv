`timescale 1ns/1ps

module ecc_decoder_13_8 (

    input  logic [12:0] codeword_in,

    output logic [7:0]  data_out,

    output logic        single_error_corrected,

    output logic        double_error_detected

);

    logic [12:0] corrected_codeword;

    logic [3:0] syndrome;

    logic overall_parity;


    always_comb begin

        // =====================================================
        // Defaults
        // =====================================================

        syndrome = 4'b0000;

        overall_parity = 1'b0;

        corrected_codeword = codeword_in;

        single_error_corrected = 1'b0;

        double_error_detected = 1'b0;

        data_out = 8'b0;


        // =====================================================
        // Calculate Hamming syndrome
        // =====================================================

        // P1
        syndrome[0] =
            codeword_in[0] ^
            codeword_in[2] ^
            codeword_in[4] ^
            codeword_in[6] ^
            codeword_in[8] ^
            codeword_in[10];


        // P2
        syndrome[1] =
            codeword_in[1] ^
            codeword_in[2] ^
            codeword_in[5] ^
            codeword_in[6] ^
            codeword_in[9] ^
            codeword_in[10];


        // P4
        syndrome[2] =
            codeword_in[3] ^
            codeword_in[4] ^
            codeword_in[5] ^
            codeword_in[6] ^
            codeword_in[11];


        // P8
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


        // =====================================================
        // SEC-DED decision
        // =====================================================

        if (overall_parity == 1'b1) begin

            // -------------------------------------------------
            // Odd number of errors
            // -------------------------------------------------

            if (syndrome != 4'd0) begin

                // Single-bit error in positions 1-12

                if (syndrome <= 4'd12) begin

                    corrected_codeword[syndrome - 1] =
                        ~corrected_codeword[syndrome - 1];

                    single_error_corrected = 1'b1;

                end
                else begin

                    // Syndrome points outside the codeword (13..15):
                    // >=3 bit error, cannot be corrected -> flag it
                    double_error_detected = 1'b1;

                end

            end
            else begin

                // Error only in overall parity bit

                single_error_corrected = 1'b1;

            end

        end

        else begin

            // -------------------------------------------------
            // Even number of errors
            // -------------------------------------------------

            if (syndrome != 4'd0) begin

                // Double-bit error

                double_error_detected = 1'b1;

            end

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