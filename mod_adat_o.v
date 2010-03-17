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

// Handles RAM -> ADAT output for 8-64 channels of 32-bit audio (no dithering... there's a potential improvement...).

module mod_adat_o
(
	// clocking (mod_control)
	master_bclk,
	reset,
	
	// external interface
	adat_o,
	
	// mod_pipeline interface
	frame_done,
	addr,
	data,
	valid
);

	// Parameter definitions
	parameter		ADAT_OUTPUTS = 1;	// Number of ADAT output streams -- must be 1 to 8
	
	// IOs
	input			master_bclk;
	input			reset;
	
	output [ADAT_OUTPUTS-1:0]	adat_o;
	
	input			frame_done;
	input [7:0]		addr;
	input [31:0]	data;
	input			valid;
	
	// Internal connections
	wire [9:0]		subframe_data;
	wire [ADAT_OUTPUTS-1:0]	channel_le;
	
	wire [ADAT_OUTPUTS-1:0]	adat_o_modulated;
	
	// Module instantiation
	
	// frame_buf is a ping-pong M4K buffer containing the entire frame's audio data.
	// On the ADAT side, it controls all frame timing, and is responsible for outputting data
	// at the correct rate -- we need 24 bit data with 8 bits per channel every 10 clk cycles.
	// Also generates ADAT framing information, and outputs the frame data one byte at a time.
	adat_o_frame_gen frame_gen (
		.clk(master_bclk),
		.reset(reset),
		
		.data(data),
		.addr(addr),
		.wr_en(valid),
		.frame_done(frame_done),
		
		.q(subframe_data),
		.q_valid(channel_le)
	);
	
	sreg_10 shifters[ADAT_OUTPUTS-1:0] (
		.clk(master_bclk),
		
		.data(subframe_data),
		.load(channel_le),
		.en(1'b1),
		
		.q(adat_o_modulated)
	);
	
	nrzi_encoder encoders[ADAT_OUTPUTS-1:0] (
		.clk(master_bclk),
		
		.in(adat_o_modulated),
		.out(adat_o)
	);
	
endmodule