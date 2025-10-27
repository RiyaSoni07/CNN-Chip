module maxpool (
    input clk,
    input maxpool_enable,
    input signed [15:0] in1, in2, in3, in4, in5, in6, in7, in8,
    output reg signed [15:0] maxpool_out,
    output reg finished_maxpool
);
    always @(posedge clk) begin
        if (maxpool_enable) begin
            maxpool_out <= in1;
            if (in2 > maxpool_out) maxpool_out <= in2;
            if (in3 > maxpool_out) maxpool_out <= in3;
            if (in4 > maxpool_out) maxpool_out <= in4;
            if (in5 > maxpool_out) maxpool_out <= in5;
            if (in6 > maxpool_out) maxpool_out <= in6;
            if (in7 > maxpool_out) maxpool_out <= in7;
            if (in8 > maxpool_out) maxpool_out <= in8;
            finished_maxpool <= 1;
        end else begin
            finished_maxpool <= 0;
        end
    end
endmodule

module Convolution_2 (
    input clk,
    input conv_enable,
    input signed [7:0] input_1, input_2, input_3,
    input signed [7:0] input_4, input_5, input_6,
    input signed [7:0] input_7, input_8, input_9,
    output reg signed [7:0] conv_out,
    output reg finished_conv
);
    always @(posedge clk) begin
        if (conv_enable) begin
            conv_out <= input_1 + input_2 + input_3 +
                        input_4 + input_5 + input_6 +
                        input_7 + input_8 + input_9;
            finished_conv <= 1;
        end else begin
            finished_conv <= 0;
        end
    end
endmodule

module cnn (
    input clk,
    input rst,
    output reg done,
    output signed [15:0] maxpool_out
);
    reg conv_enable = 0;
    reg maxpool_enable = 0;

    reg signed [7:0] input_1, input_2, input_3, input_4, input_5, input_6, input_7, input_8, input_9;
    wire signed [7:0] conv_out;
    wire finished_conv;

    reg signed [15:0] in1, in2, in3, in4, in5, in6, in7, in8;
    wire signed [15:0] maxpool_raw;
    wire finished_maxpool;

    reg [15:0] image [0:16383];  // 128x128 grayscale image
    reg [15:0] pool  [0:16383];

    reg [13:0] index = 0;
    reg [13:0] output_index = 0;

    `ifndef SYNTHESIS
    initial begin
        $readmemh("image.mem", image);
    end
    `endif

    // Convolution module
    Convolution_2 conv (
        .clk(clk),
        .conv_enable(conv_enable),
        .input_1(input_1), .input_2(input_2), .input_3(input_3),
        .input_4(input_4), .input_5(input_5), .input_6(input_6),
        .input_7(input_7), .input_8(input_8), .input_9(input_9),
        .conv_out(conv_out),
        .finished_conv(finished_conv)
    );

    // Maxpooling module
    maxpool pool_op (
        .clk(clk),
        .maxpool_enable(maxpool_enable),
        .in1(in1), .in2(in2), .in3(in3), .in4(in4),
        .in5(in5), .in6(in6), .in7(in7), .in8(in8),
        .maxpool_out(maxpool_raw),
        .finished_maxpool(finished_maxpool)
    );

    // ReLU after maxpool: clip negatives to zero
    wire signed [15:0] relu_out;
    assign relu_out = (maxpool_raw < 0) ? 16'd0 : maxpool_raw;

    // Main controller
    always @(posedge clk) begin
        if (rst) begin
            index <= 0;
            output_index <= 0;
            conv_enable <= 0;
            maxpool_enable <= 0;
            done <= 0;
        end else begin
            // Feed new pixels for convolution
            if (index < 128*128 - 260) begin
                input_1 <= image[index][7:0];
                input_2 <= image[index+1][7:0];
                input_3 <= image[index+2][7:0];
                input_4 <= image[index+128][7:0];
                input_5 <= image[index+129][7:0];
                input_6 <= image[index+130][7:0];
                input_7 <= image[index+256][7:0];
                input_8 <= image[index+257][7:0];
                input_9 <= image[index+258][7:0];
                conv_enable <= 1;
            end else begin
                conv_enable <= 0;
            end

            // After convolution, prepare inputs to maxpool
            if (finished_conv) begin
                // sign-extend conv_out to 16-bit before maxpool
                in1 <= { {8{conv_out[7]}}, conv_out };
                in2 <= { {8{conv_out[7]}}, conv_out } - 1;
                in3 <= { {8{conv_out[7]}}, conv_out } - 2;
                in4 <= { {8{conv_out[7]}}, conv_out } - 3;
                in5 <= { {8{conv_out[7]}}, conv_out } - 4;
                in6 <= { {8{conv_out[7]}}, conv_out } - 5;
                in7 <= { {8{conv_out[7]}}, conv_out } - 6;
                in8 <= { {8{conv_out[7]}}, conv_out } - 7;
                maxpool_enable <= 1;
                index <= index + 1;
            end else begin
                maxpool_enable <= 0;
            end

            // Store output after ReLU
            if (finished_maxpool) begin
                pool[output_index] <= relu_out;
                output_index <= output_index + 1;
            end

            if (output_index >= 128*128 - 260) begin
                done <= 1;
                `ifndef SYNTHESIS
                $writememh("pool_output.mem", pool);
                $display("CNN Pipeline Finished. Output written to pool_output.mem.");
                `endif
            end
        end
    end

    // Output the latest maxpool result
    assign maxpool_out = relu_out;
endmodule

