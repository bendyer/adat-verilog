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

// Take a 200MHz+ input clock, and generate a bitclock output matched to the frequency of sync_stream.
// For some reason, this works better with the frequency lock *disabled* -- although this will increase
// high-frequency jitter to at least that of the incoming signal. Ouch!

module sync_adpll
(
	refclk,
	reset,
	sync_stream,
	
	out_bclk
);

	parameter		ACCUM_SIZE = 24;
	parameter		CLK_OVERSAMPLE_LOG2 = 4;	// Clock oversample = 16

	input			refclk, reset, sync_stream;
	output			out_bclk;
	
	// IO regs
	reg				out_bclk;
	
	// Internal regs
	reg [ACCUM_SIZE-1:0]		accum;
	reg [ACCUM_SIZE-1:0]		freq_tuning_word;
	
	// Reset synchroniser
	reg				reset_d, reset_dd;
	always @(posedge refclk) reset_d <= reset;
	always @(posedge refclk) reset_dd <= reset_d;
	
	// Increment accumulator by FTW. We care more about frequency stability than relative phase.
	always @(posedge refclk) begin
		if (transition)
			accum <= 0;
		else
			accum <= accum + freq_tuning_word;
	end
	
	// Detect transitions -- current input XOR previous input = 1; use a 3-stage synchronizer
	// D-FF to reduce chance of metastability
	reg				in_d, in_dd, in_ddd, in_dddd;
	always @(posedge refclk) begin
		in_d <= sync_stream;
		in_dd <= in_d;
		in_ddd <= in_dd;
		in_dddd <= in_ddd;
	end
	
	wire			transition;
	assign transition = in_dddd ^ in_ddd;
	
	// Compare transition point with phase of the accumulator -- if the MSB of the accumulator is 1, increase FTW; otherwise, decrease FTW
	always @(posedge refclk) begin
		//if (reset_dd)
			freq_tuning_word <= (2**ACCUM_SIZE-1)>>CLK_OVERSAMPLE_LOG2;	// Works for a 200MHz clock (16x); 250MHz clock (20x) would require something else
		//else if (transition)
		//	if (accum[ACCUM_SIZE-1])	// Increase FTW
		//		freq_tuning_word <= freq_tuning_word + 32'b1;
		//	else						// Decrease FTW
		//		freq_tuning_word <= freq_tuning_word + (~32'b1 + 1); //2's complement subtraction
	end
	
	always @(posedge refclk) out_bclk <= accum[ACCUM_SIZE-1];
endmodule