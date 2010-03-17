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

// frame_gen maintains a ping-pong data buffer for output audio coming from the RAM buffer, and generates ADAT frame
// data for up to 8 ADAT output streams.

// Tasks:
// * Maintain buffers (a la out_data_buf)
// * Keep track of sub-frame count (use 2 sub-frames of 8, then 24 of 10), and bit count within subframe
// * Generate each data for each sub-frame -- sub-frame 0 is 10000000, 1 is 0001uuuu, subsequent are 1aaaa1aaaa
// * Output sub-frame data 10 bits at at time for each stream, asserting q_valid once per subframe for each stream
// * Reset the sub-frame count and bit count at every frame_done signal

//`define DEBUG_GENERATE_TONE

module adat_o_frame_gen
(
	clk,
	reset,
	
	data,
	addr,
	wr_en,
	frame_done,
	
	q,
	q_valid
);

	input			clk, reset;
	
	input [31:0]	data;
	input [7:0]		addr;
	input			wr_en;
	input			frame_done;
	
	output [9:0]	q;
	output [7:0]	q_valid;
	
	// Internal regs & connections
	reg [9:0]		q;			// Not really a register -- used in combinatorial assignment only
	reg [7:0]		q_valid;	// This is now actually a register, to keep it matched up with q
	
	reg [3:0]		subframe_bit_count;
	reg [4:0]		subframe_idx;
	reg [4:0]		subframe_idx_d;
	
	wire			subframe_done;
	
	reg				oe, oe_d;
	
	// Subframe done signal -- indicates the current bit is the last of the subframe. Happens at bit 7 for subframes 0 and 1, and bit 9 for others
	assign subframe_done = (subframe_bit_count == 4'b0111 && (subframe_idx == 5'b0 || subframe_idx == 5'b1)) || (subframe_bit_count == 4'b1001);
	
	// Handle the subframe bit count -- go from 00000 to 11001.
	always @(posedge clk) begin
		if (!oe || reset || frame_done || subframe_done)
			subframe_bit_count <= 4'b0;
		else
			subframe_bit_count <= subframe_bit_count + 1'b1;
	end
	
	// Handle the subframe index -- don't increment before a full frame has been read
	always @(posedge clk) begin
		if (!oe || reset || frame_done || (subframe_idx == 5'b11001 && subframe_done))
			subframe_idx <= 5'b0;
		else if (subframe_done)
			subframe_idx <= subframe_idx + 1'b1;
			
		subframe_idx_d <= subframe_idx;
	end
	
	// Handle output enable -- keep everything in reset state until frame sync is received
	always @(posedge clk) begin
		if (reset)
			oe <= 1'b0;
		else if (frame_done)
			oe <= 1'b1;
		
		oe_d <= oe;
	end
	
	// Frame data -- 3-way 10-bit mux
	wire [7:0]		audio_data;
	wire [7:0]		subframe_0_data;
	wire [7:0]		subframe_1_data;
	assign subframe_0_data = 8'b10000000;
	assign subframe_1_data = 8'b00010000; // Last 4 bits are user status code
	
	// Combinatorial 3-way mux for output -- either subframe 0, subframe 1, or audio data (or 0 if output is disabled)
	always @(subframe_idx_d or subframe_0_data or subframe_1_data or audio_data or oe_d) begin
		if (!oe_d)
			q = 10'b0;
		else
			case (subframe_idx_d)
				5'b00000: q = {subframe_0_data,2'b0};
				5'b00001: q = {subframe_1_data,2'b0};
				default: q = {1'b1,audio_data[7:4],1'b1,audio_data[3:0]};	// Insert marker codes into audio data before each nibble
			endcase
	end
	
	// Buffer read address logic -- we only need the 3 MSBs of each field of each stereo audio channel, so we need to do some decoding
	// of the subframe bit count and subframe index. Our frame buffer is mapped as cccccbbb (or ffffffbb for mono). This corresponds to
	// an ooofffbb setup, with 8 outputs containing 8 fields of 3 bytes each.
	
	// Combinatorial <subframe index> -> <field+byte component of address> mapping table
	reg [4:0]		field_byte_select;	// Not a register!
`include "../lib/adat_subframe_to_field_byte_addr.v"
	
	// The 3-bit output stream selector is just the 3 LSBs of subframe_bit_count -- although it counts up to 10 on some frames,
	// we don't need to handle the other frames, so it doesn't matter which addresses are read for them.
	wire [7:0]		audio_data_addr;
	assign audio_data_addr = {subframe_bit_count[2:0],field_byte_select};
	
	// And now, generate q_valid for the appropriate output stream register, based on the subframe_bit_count
	always @(posedge clk) begin
		if (reset || !oe)
			q_valid <= 8'b00000000;
		else
			case (subframe_bit_count)
				4'b0000: q_valid <= 8'b00000001;
				4'b0001: q_valid <= 8'b00000010;
				4'b0010: q_valid <= 8'b00000100;
				4'b0011: q_valid <= 8'b00001000;
				4'b0100: q_valid <= 8'b00010000;
				4'b0101: q_valid <= 8'b00100000;
				4'b0110: q_valid <= 8'b01000000;
				4'b0111: q_valid <= 8'b10000000;
				default: q_valid <= 8'b00000000;
			endcase
	end

`ifdef DEBUG_GENERATE_TONE
	// Generate a high-amplitude square wave, with different tones on odd/even channels.
	reg [23:0]		counter;
	always @(posedge clk) counter <= counter + 1'b1;
	assign audio_data = {field_byte_select[2]?1'b0:counter[17],6'b0};
`else
	// Instantiate the buffer
	word_write_pingpong_buf buffer (
		.clk(clk),
		
		.rd_addr({1'b0,audio_data_addr}),
		.rd_data(audio_data),
		
		.wr_addr(addr[6:0]),
		.wr_data(data),
		.wr_en(wr_en),
		
		.switch_buf(frame_done)
	);
`endif
	
endmodule