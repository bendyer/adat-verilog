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

// adat_i_frame_buf reads 1-8 isochronous ADAT streams, removes framing information, and writes them into a ping-pong buffer
// for later reading by mod_pipeline.

module adat_i_frame_buf
(
	clk,
	reset,
	
	subframe_data,
	
	frame_done,
	rd_addr,
	rd_data,
	rd_valid
);

	parameter		INPUT_STREAMS = 1;

	// IOs
	input			clk, reset;
	
	input [79:0]	subframe_data;	// Keep this at the maximum possible size, because otherwise we run into trouble with the mux below
	
	input			frame_done;
	input [7:0]		rd_addr;
	output [31:0]	rd_data;
	output			rd_valid;
	
	// Internal connections
	reg [7:0]		wr_data;	// this is not a register
	wire [7:0]		wr_addr;
	wire			wr_en;
	
	// Delay frame_done by one cycle to match input data
	reg				frame_done_d;
	always @(posedge clk) begin
		frame_done_d <= frame_done;
	end
		
	// Multiplexer source stream count
	reg [3:0]		subframe_bit_count;
	reg [4:0]		subframe_idx;
	wire			subframe_done;
	assign subframe_done = (subframe_idx == 5'b00000 || subframe_idx == 5'b000001) ? (subframe_bit_count == 4'b0111) : (subframe_bit_count == 4'b1001);
	
	// Keep track of the subframe position
	always @(posedge clk) begin
		if (reset || frame_done_d)
			subframe_bit_count <= 4'b0111;
		else if (subframe_done)
			subframe_bit_count <= 4'b0;
		else
			subframe_bit_count <= subframe_bit_count + 1'b1;
	end
	
	// Subframe count
	always @(posedge clk) begin
		if (reset || frame_done_d)
			subframe_idx <= 5'b11111;
		else if (subframe_done)
			subframe_idx <= subframe_idx + 1'b1;
	end
	
	// Multiplexing + de-framing logic -- see adat_o_frame_gen for details. frame_check should be 2'b11 for all data frames
	wire [1:0]		frame_check;
	always @(subframe_data or subframe_bit_count) begin
		case (subframe_bit_count)
			4'b0000: {frame_check,wr_data} = {subframe_data[9],subframe_data[4],subframe_data[8:5],subframe_data[3:0]};	// remove 1s from frame
			4'b0001: {frame_check,wr_data} = {subframe_data[19],subframe_data[14],subframe_data[18:15],subframe_data[13:10]};
			4'b0010: {frame_check,wr_data} = {subframe_data[29],subframe_data[24],subframe_data[28:25],subframe_data[23:20]};
			4'b0011: {frame_check,wr_data} = {subframe_data[39],subframe_data[34],subframe_data[38:35],subframe_data[33:30]};
			4'b0100: {frame_check,wr_data} = {subframe_data[49],subframe_data[44],subframe_data[48:45],subframe_data[43:40]};
			4'b0101: {frame_check,wr_data} = {subframe_data[59],subframe_data[54],subframe_data[58:55],subframe_data[53:50]};
			4'b0110: {frame_check,wr_data} = {subframe_data[69],subframe_data[64],subframe_data[68:65],subframe_data[63:60]};
			4'b0111: {frame_check,wr_data} = {subframe_data[79],subframe_data[74],subframe_data[78:75],subframe_data[73:70]};
			default: {frame_check,wr_data} = {2'b11,8'b0};
		endcase
	end
	
	reg [4:0]		field_byte_select; // not a register
`include "../lib/adat_subframe_to_field_byte_addr.v"

	assign wr_addr = {subframe_bit_count[2:0],field_byte_select};
	assign wr_en = (subframe_idx > 5'b00001) && (subframe_bit_count[3] == 1'b0) && (subframe_idx <= 5'b11001);
	
	// Instantiate the buffer
	word_read_pingpong_buf buffer (
		.clk(clk),
		
		.rd_addr(rd_addr[6:0]),
		.rd_data(rd_data),
		
		.wr_addr({1'b0,wr_addr}),
		.wr_data(frame_check == 2'b11 ? wr_data : 8'b0),	// Clear out locations with invalid data
		.wr_en(wr_en),
		
		.switch_buf(frame_done)
	);
	
	// Set read valid
	assign rd_valid = 1'b1;
endmodule