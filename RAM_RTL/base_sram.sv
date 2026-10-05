module base_sram(
    input  logic       clk,
    input  logic       rst,

    input  logic       we,
    input  logic [7:0] addr,
    input  logic [7:0] wdata,

    // Synthesizable SEU injection interface
    input  logic       seu_inject,
    input  logic [2:0] seu_bit,

    output logic [7:0] rdata
);

    // 256 words × 8 bits
    logic [7:0] mem [0:255];

    integer i;

    always_ff @(posedge clk) begin

        if (rst) begin

            for (i = 0; i < 256; i = i + 1)
                mem[i] <= 8'h00;

            rdata <= 8'h00;
        end

        else begin

            // =================================================
            // Synthesizable single-bit SEU injection
            // =================================================

            if (seu_inject) begin

                mem[addr][seu_bit] <=
                    ~mem[addr][seu_bit];

            end

            // =================================================
            // Normal write
            // =================================================

            else if (we) begin

                mem[addr] <= wdata;

            end

            // =================================================
            // Synchronous read
            // =================================================

            rdata <= mem[addr];

        end

    end

endmodule