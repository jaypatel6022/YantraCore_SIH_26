`timescale 1ns/1ps

module ecc_encoder_8_13 (
    input  logic [7:0]  data_in,
    output logic [12:0] codeword_out
);

    logic [12:0] cw;

    always_comb begin

        cw = '0;

        // =====================================================
        // Data placement
        //
        // Position:  1  2  3  4  5  6  7  8  9 10 11 12 13
        //            P1 P2 D0 P4 D1 D2 D3 P8 D4 D5 D6 D7 OP
        // =====================================================

        cw[2]  = data_in[0];
        cw[4]  = data_in[1];
        cw[5]  = data_in[2];
        cw[6]  = data_in[3];

        cw[8]  = data_in[4];
        cw[9]  = data_in[5];
        cw[10] = data_in[6];
        cw[11] = data_in[7];

        // =====================================================
        // Hamming parity bits
        // =====================================================

        // P1
        cw[0] =
            cw[2] ^
            cw[4] ^
            cw[6] ^
            cw[8] ^
            cw[10];

        // P2
        cw[1] =
            cw[2] ^
            cw[5] ^
            cw[6] ^
            cw[9] ^
            cw[10];

        // P4
        cw[3] =
            cw[4] ^
            cw[5] ^
            cw[6] ^
            cw[11];

        // P8
        cw[7] =
            cw[8] ^
            cw[9] ^
            cw[10] ^
            cw[11];

        // =====================================================
        // Overall parity
        // =====================================================

        cw[12] = ^cw[11:0];

        codeword_out = cw;

    end

endmodule