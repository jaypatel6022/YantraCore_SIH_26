`timescale 1ns/1ps

module button_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  logic clk,
    input  logic rst,
    input  logic btn_in,

    output logic btn_pulse
);

    localparam integer COUNT_MAX =
        (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

    localparam integer COUNT_WIDTH =
        (COUNT_MAX <= 1) ? 1 : $clog2(COUNT_MAX);

    logic btn_sync_1;
    logic btn_sync_2;

    logic btn_state;

    logic [COUNT_WIDTH-1:0] counter;


    // =========================================================
    // Synchronize asynchronous button to FPGA clock
    // =========================================================

    always_ff @(posedge clk) begin
        if (rst) begin
            btn_sync_1 <= 1'b0;
            btn_sync_2 <= 1'b0;
        end
        else begin
            btn_sync_1 <= btn_in;
            btn_sync_2 <= btn_sync_1;
        end
    end


    // =========================================================
    // Debounce + one-shot pulse generation
    // =========================================================

    always_ff @(posedge clk) begin

        if (rst) begin

            btn_state <= 1'b0;
            counter   <= '0;
            btn_pulse <= 1'b0;

        end

        else begin

            // Default: pulse is only one clock cycle
            btn_pulse <= 1'b0;

            // Button state differs from stable state
            if (btn_sync_2 != btn_state) begin

                if (counter < COUNT_MAX - 1) begin

                    counter <= counter + 1'b1;

                end

                else begin

                    // New stable button state accepted
                    btn_state <= btn_sync_2;
                    counter   <= '0;

                    // Generate pulse only on rising edge
                    if (btn_sync_2 == 1'b1)
                        btn_pulse <= 1'b1;

                end

            end

            else begin

                counter <= '0;

            end

        end

    end

endmodule