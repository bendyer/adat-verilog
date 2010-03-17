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

module adat_stream_in
(
	refclk,
	mclk,
	reset,
	
	in,
	frame_done,
	
	out,
	
	error,
	locked,
	bitcount_save
);

	// IOs
	input			refclk, mclk, reset;
	
	input			in, frame_done;
	output [9:0]	out;
	output			error, locked;
	output [31:0]	bitcount_save;
	
	// Internal connections
	wire			data;		// Decoded data
	wire			latch_data;	// Decoded data latch enable for FIFO
	
	wire [8:0]		fifo_words;
	reg				fifo_synced;	// asserted if the FIFO is in sync with the RAM buffer cycles bus
	wire			fifo_out;
	wire			fifo_out_ack;		// Read acknowledge command for the FF -- pops the current value off the end
	reg				fifo_clear;
	
	wire			fd_subframe_rdy, fd_rdy, fd_error;
	wire [9:0]		fd_subframe_data;
	
	// Delayed fifo_out_ack
	reg				fifo_out_ack_d, frame_done_d;
	always @(posedge mclk) begin
		fifo_out_ack_d <= fifo_out_ack;
		frame_done_d <= frame_done;
	end
	
	// Module instantiation
	
	// Decode the input bitstream, and generate an output 
	nrzi_decoder decoder (
		.refclk(refclk),
		.reset(reset),
		.in(in),
		
		.out(data),
		.oe(latch_data)
	);
	
	fifo_512x1 buffer (
		.data(data),
		.wrclk(refclk),
		.wrreq(latch_data),
		
		.rdclk(mclk),
		.rdreq(fifo_out_ack),
		.q(fifo_out),
		
		.rdusedw(fifo_words),
		.aclr(fifo_clear)
	);
	
	frame_detector frame_detector (
		.clk(mclk),
		.reset(reset),
		.in(fifo_out),
		.enable(fifo_out_ack),
		
		.subframe_data(fd_subframe_data),
		.subframe_rdy(fd_subframe_rdy),
		.frame_rdy(fd_rdy),
		.error(fd_error)
	);
	
	// Set fifo_synced if frame_done coincides with fd_rdy
	always @(posedge mclk) begin
		if (reset || fd_error)
			fifo_synced <= 1'b0;
		else if (frame_done)
			fifo_synced <= fd_rdy;
	end
	
	// Reset the FIFO if sync is lost
	always @(posedge mclk) begin
		if (fifo_synced && frame_done && !fd_rdy)
			fifo_clear <= 1'b1;
		else
			fifo_clear <= 1'b0;
	end
	
	// Latch output data whenever subframe_rdy is asserted
	reg [9:0]		out;
	always @(posedge mclk) begin
		if (reset || !fifo_synced)
			out <= 10'b0;
		else if (fd_subframe_rdy || fd_rdy)
			out <= fd_subframe_data;
	end
	
	// Read from the FIFO until the frame is ready, then pause until the next frame_done signal
	assign fifo_out_ack = fd_error || fifo_synced || (frame_done && fd_rdy) || !fd_rdy;
	
	reg [7:0]		frame_done_bitcount;
	reg [7:0]		fd_rdy_bitcount;
	reg [31:0]		bitcount_save;
	always @(posedge mclk) begin
		if (reset || frame_done)
			frame_done_bitcount <= 8'b0;
		else
			frame_done_bitcount <= frame_done_bitcount + 1'b1;
	end
	
	always @(posedge mclk) begin
		if (reset || fd_rdy)
			fd_rdy_bitcount <= 8'b0;
		else
			fd_rdy_bitcount <= fd_rdy_bitcount + 1'b1;
	end
	
	always @(posedge mclk) begin
		if (reset)
			bitcount_save <= 32'b0;
		else
			bitcount_save <= {bitcount_save[31:27],fd_rdy,frame_done,fifo_synced,fifo_words[8:0],fd_rdy_bitcount[7:0],frame_done_bitcount[7:0]};
	end
	
	// Set output error
	assign error = fd_error;
	assign locked = (fd_rdy != frame_done); //fifo_synced && !fd_error;
endmodule