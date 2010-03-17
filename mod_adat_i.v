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

// Handles ADAT -> RAM input for 8-64 isochronous channels of 24-bit audio.

module mod_adat_i
(
	// clocking (mod_control)
	bclk_4x,
	bclk_8x,
	master_bclk,
	sys_clk,
	recovered_bclk,
	reset,
	error,
	
	// external interface
	adat_i,
	
	// mod_pipeline interface
	frame_done,
	addr,
	data,
	valid,
	
	// test
	bitcount_out
);

	// Parameter definitions
	parameter		ADAT_INPUTS = 1;	// Number of ADAT input streams -- must be 1 to 8
	
	input			master_bclk, sys_clk, bclk_4x, bclk_8x, reset;
	output [ADAT_INPUTS-1:0]	error;
	
	input [ADAT_INPUTS-1:0]	adat_i;
	
	input			frame_done;
	input [7:0]		addr;
	output [31:0]	data;
	output			valid;
	
	output			recovered_bclk;
	
	output [31:0]	bitcount_out;
	
	// Internal connections
	wire			refclk, adpll_refclk;
	wire [ADAT_INPUTS*10-1:0]	adat_subframes;	
	wire [ADAT_INPUTS-1:0]		stream_err;
	wire [ADAT_INPUTS-1:0]		stream_lock;
	
	reg				adat_reset_d, adat_reset_dd;
	wire			adat_reset;
	assign adat_reset = reset;
	always @(posedge master_bclk) adat_reset_d <= adat_reset;
	always @(posedge master_bclk) adat_reset_dd <= adat_reset_d;
	
	// Module instantiation
	assign refclk = bclk_4x;
	assign adpll_refclk = bclk_8x;
	
	sync_adpll mclk_recovery_pll (
		.refclk(adpll_refclk),
		.reset(adat_reset),
		.sync_stream(/*adat_i[0]*/1'b0), // Master clock recovery doesn't work very well, so ignore it -- means that external devices must be slaved to internal clock
		.out_bclk(recovered_bclk)
	);
	
	wire [255:0]		dummy;
	adat_stream_in streams[ADAT_INPUTS-1:0] (
		.refclk(refclk),
		.mclk(master_bclk),
		.reset(adat_reset_dd),
		
		.in(adat_i),
		.out(adat_subframes),		
		.frame_done(frame_done),
		
		.error(stream_err),
		.locked(stream_lock),
		.bitcount_save({dummy[255:32], bitcount_out[31:0]})
	);
	
	adat_i_frame_buf frame_buf (
		.clk(master_bclk),
		.reset(adat_reset_dd),
		
		.subframe_data(adat_subframes),
		
		.frame_done(frame_done),
		.rd_addr(addr),
		.rd_data(data),
		.rd_valid(valid)
	);
	defparam frame_buf.INPUT_STREAMS = ADAT_INPUTS;
	
	assign error = stream_lock; /* stream_lock | ~stream_err; */ // in the absence of functioning master clock recovery, ignore stream errors
endmodule