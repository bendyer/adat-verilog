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

module frame_detector
(
	clk,
	reset,
	in,
	enable,
   
	subframe_data,
	subframe_rdy,
	frame_rdy,
	error
);

	// IOs
	input			clk, reset;
	
	input			in, enable;
	
	output [9:0]	subframe_data;
	output			subframe_rdy;
	output			frame_rdy;
	output			error;
	
	// IO regs
	reg				error;
	
	// Internal regs + connections
	wire			sync_frame, le;
	reg [3:0]		bit_count;
	reg [9:0]		sreg;
	reg				prev_frame_was_sync;
	
	// Shift data every clock cycle
	always @(posedge clk) begin
		if (reset)
			sreg <= 10'b0;
		else if (enable)
			sreg <= {sreg[8:0], in};
	end
	
	// Look for a synchronisation frame start, and then handle the next part of it.
	assign sync_frame = (sreg[6:0] == 7'b1000000 && in == 1'b0);//(sreg[7:0] == 8'b10000000);
	always @(posedge clk) begin
		if (reset)
			prev_frame_was_sync <= 1'b0;
		else if (le)
			prev_frame_was_sync <= (sreg[7:0] == 8'b10000000);
	end
	
	// Maintain the bit count, and latch the contents of the shift register every 8 or 10 bits, depending on whether or not it's a header frame
	assign le = (bit_count == 4'b1001) || (sreg[7:0] == 8'b10000000) || (bit_count == 4'b0111 && prev_frame_was_sync);
	always @(posedge clk) begin
		if (reset || frame_rdy || subframe_rdy)
			bit_count <= 4'b0;
		else if (enable)
			bit_count <= bit_count + 1'b1;
	end
	
	assign frame_rdy = sync_frame;
	assign subframe_data = sreg;
	assign subframe_rdy = le && enable;
	
	// Look for error conditions
	always @(posedge clk) begin
		error <= (sreg == 10'b0 && in == 0 && !prev_frame_was_sync);	// >10 consecutive zeros is an error
	end
endmodule