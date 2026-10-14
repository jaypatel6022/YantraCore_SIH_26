`timescale 1ns/1ps

module ecc_sram #(
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

    output logic [DATA_WIDTH-1:0] rdata,       // auto-corrected (what a normal read returns)
    output logic [DATA_WIDTH-1:0] rdata_raw,   // uncorrected bits straight from storage

    output logic                  single_error_corrected,
    output logic                  double_error_detected,

    input  logic                  seu_inject,
    input  logic [3:0]            seu_bit,

    // One-shot manual scrub: re-encode the corrected data and write it
    // back into storage at the current address, physically repairing the
    // codeword. Ignored on an uncorrectable (double) error, since
    // decoded_data is not valid in that case.
    input  logic                  scrub
);

    logic [CODE_WIDTH-1:0] mem [0:DEPTH-1];

    logic [CODE_WIDTH-1:0] stored_codeword;
    logic [DATA_WIDTH-1:0] decoded_data;
    logic [DATA_WIDTH-1:0] raw_data;

    logic [DATA_WIDTH-1:0] encoder_din;
    logic [CODE_WIDTH-1:0] encoded_data;

    // On scrub, encode the *corrected* data instead of the switch data,
    // so the write-back repairs the codeword rather than overwriting it.
    assign encoder_din = scrub ? decoded_data : wdata;

    ecc_encoder_8_13 encoder (
        .data_in      (encoder_din),
        .codeword_out (encoded_data)
    );

    ecc_decoder_13_8 decoder (
        .codeword_in            (stored_codeword),
        .data_out               (decoded_data),
        .single_error_corrected (single_error_corrected),
        .double_error_detected  (double_error_detected)
    );

    always_comb stored_codeword = mem[addr];

    // Raw extraction: same bit positions the encoder uses, but with NO
    // correction applied. This is what's physically sitting in the array.
    always_comb begin
        raw_data[0] = stored_codeword[2];
        raw_data[1] = stored_codeword[4];
        raw_data[2] = stored_codeword[5];
        raw_data[3] = stored_codeword[6];
        raw_data[4] = stored_codeword[8];
        raw_data[5] = stored_codeword[9];
        raw_data[6] = stored_codeword[10];
        raw_data[7] = stored_codeword[11];
    end

    integer i;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= '0;
            rdata     <= '0;
            rdata_raw <= '0;
        end
        else begin
            if (seu_inject) begin
                if (seu_bit < CODE_WIDTH)
                    mem[addr][seu_bit] <= ~mem[addr][seu_bit];
            end
            else if (scrub && !double_error_detected) begin
                mem[addr] <= encoded_data;
            end
            else if (we) begin
                mem[addr] <= encoded_data;
            end

            rdata     <= decoded_data;
            rdata_raw <= raw_data;
        end
    end

endmodule
