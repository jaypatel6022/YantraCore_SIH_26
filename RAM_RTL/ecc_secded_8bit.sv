module ecc_secded_8bit (
    input  logic [7:0]  data_in,

    output logic [12:0] codeword_out,

    input  logic [12:0] codeword_in,

    output logic [7:0]  data_out,
    output logic        single_error_corrected,
    output logic        double_error_detected
);

    logic [12:0] cw;

    logic [3:0] syndrome;
    logic       overall_parity;

    integer i;

    // =========================================================
    // ENCODER
    //
    // Codeword positions:
    //
    // Position :  1  2  3  4  5  6  7  8  9 10 11 12 13
    //             P  P  D  P  D  D  D  P  D  D  D  D  OP
    //
    // P  = Hamming parity
    // D  = data
    // OP = overall parity
    // =========================================================

    always_comb begin

        cw = '0;

        // -----------------------------------------------------
        // Put data into codeword
        // -----------------------------------------------------

        cw[2]  = data_in[0];   // position 3
        cw[4]  = data_in[1];   // position 5
        cw[5]  = data_in[2];   // position 6
        cw[6]  = data_in[3];   // position 7
        cw[8]  = data_in[4];   // position 9
        cw[9]  = data_in[5];   // position 10
        cw[10] = data_in[6];   // position 11
        cw[11] = data_in[7];   // position 12

        // -----------------------------------------------------
        // Hamming parity bits
        // -----------------------------------------------------

        // P1 covers positions 1,3,5,7,9,11
        cw[0] = cw[2] ^ cw[4] ^ cw[6] ^
                cw[8] ^ cw[10];

        // P2 covers positions 2,3,6,7,10,11
        cw[1] = cw[2] ^ cw[5] ^ cw[6] ^
                cw[9] ^ cw[10];

        // P4 covers positions 4,5,6,7,12
        cw[3] = cw[4] ^ cw[5] ^ cw[6] ^ cw[11];

        // P8 covers positions 8,9,10,11,12
        cw[7] = cw[8] ^ cw[9] ^ cw[10] ^ cw[11];

        // -----------------------------------------------------
        // Overall parity
        // -----------------------------------------------------

        cw[12] = ^cw[11:0];

        codeword_out = cw;

    end


    // =========================================================
    // DECODER
    // =========================================================

    always_comb begin

        data_out = '0;

        syndrome = '0;

        single_error_corrected = 1'b0;
        double_error_detected   = 1'b0;

        // -----------------------------------------------------
        // Calculate Hamming syndrome
        // -----------------------------------------------------

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

        // -----------------------------------------------------
        // Overall parity
        // -----------------------------------------------------

        overall_parity = ^codeword_in;

        // -----------------------------------------------------
        // SEC-DED decision
        // -----------------------------------------------------

        if (overall_parity == 1'b1) begin

            // -------------------------------------------------
            // Odd number of errors
            //
            // Non-zero syndrome:
            // single-bit error in positions 1-12
            //
            // Zero syndrome:
            // error in overall parity bit
            // -------------------------------------------------

            if (syndrome != 4'd0) begin

                if (syndrome <= 4'd12) begin

                    cw = codeword_in;

                    // Syndrome gives 1-based position.
                    cw[syndrome - 1] =
                        ~cw[syndrome - 1];

                    single_error_corrected = 1'b1;

                end

            end
            else begin

                // Overall parity bit error.
                // Data itself is already correct.

                single_error_corrected = 1'b1;

                cw = codeword_in;

            end

        end

        else begin

            // -------------------------------------------------
            // Even number of errors
            //
            // Syndrome != 0 -> double-bit error
            // Syndrome == 0 -> no error
            // -------------------------------------------------

            if (syndrome != 4'd0) begin

                double_error_detected = 1'b1;

                cw = codeword_in;

            end
            else begin

                cw = codeword_in;

            end

        end

        // -----------------------------------------------------
        // Extract corrected data
        // -----------------------------------------------------

        data_out[0] = cw[2];
        data_out[1] = cw[4];
        data_out[2] = cw[5];
        data_out[3] = cw[6];

        data_out[4] = cw[8];
        data_out[5] = cw[9];
        data_out[6] = cw[10];
        data_out[7] = cw[11];

    end

endmodule