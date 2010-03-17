// Copyright (c) 2008 Ben Dyer
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Decodes an NRZI bitstream (http://en.wikipedia.org/wiki/Non-return-to-zero), oversampling at
// the rate of refclk. Generates data output and recovered clock, with up to 10ns jitter for a 98MHz
// reference clock (8x).

module nrzi_decoder
(
	refclk,
	reset,
	in,
	
	oe,
	out
);

	// IOs
	input			refclk, in, reset;
	output			oe, out;
	
	// IO regs
	reg				out;
	
	// Internal regs
	reg [2:0]		accum;
	
	// Reset sync logic
	reg				reset_d, reset_dd;
	always @(posedge refclk) reset_d <= reset;
	always @(posedge refclk) reset_dd <= reset_d;
	
	// Detect edges -- current input XOR previous input = 1; use a 3-stage synchronizer
	// D-FF to reduce chance of metastability
	reg				in_d, in_dd, in_ddd, in_dddd;
	always @(posedge refclk) begin
		if (reset_dd) begin
			in_d <= 1'b0;
			in_dd <= 1'b0;
			in_ddd <= 1'b0;
			in_dddd <= 1'b0;
		end else begin
			in_d <= in;
			in_dd <= in_d;
			in_ddd <= in_dd;
			in_dddd <= in_ddd;
		end
	end
	
	wire			transition;
	assign transition = in_dddd ^ in_ddd;
	
	// Output enable -- set on bit 4 of the cycle, to keep the design synchronous with refclk

	// Reset the accumulator every 8 cycles, or on an input transition. If it was an input transition,
	// the NRZI-decoded value of this cycle is 1 -- otherwise, it's 0. Data is latched by downstream
	// units on the positive edge of accum[2].
	always @(posedge refclk) begin
		if (reset_dd || transition)
			accum <= 3'b0;
		else
			accum <= accum + 1'b1;
	end
	
	always @(posedge refclk) begin
		if (reset_dd)
			out <= 1'b0;
		else if (transition)
			out <= 1'b1;
		else if (accum == 3'b100)
			out <= 1'b0;
	end
	
	assign oe = (accum == 3'b011 ? 1'b1 : 1'b0);
	
endmodule