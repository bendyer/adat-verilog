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

module pingpong_buf
(
	clk,
	
	rd_data,
	rd_addr,
	
	wr_data,
	wr_addr,
	wr_en,
	
	switch_buf,
	cur_wr_buf
);

	input			clk;
	
	input [6:0]		rd_addr;
	output [31:0]	rd_data;
	
	input [6:0]		wr_addr;
	input [31:0]	wr_data;
	input			wr_en;
	
	input			switch_buf;
	output			cur_wr_buf;

	// Buffer select logic
	reg				write_buf;
	wire			read_buf;
	wire			buf0_wr_en;
	wire			buf1_wr_en;
	wire [31:0]		buf0_q;
	wire [31:0]		buf1_q;
	
	assign read_buf = !write_buf;
	assign buf0_wr_en = (write_buf == 1'b0);
	assign buf1_wr_en = (write_buf != 1'b0);
	
	assign cur_wr_buf = write_buf;
	
	// Switch over buffers once we hit the end of the frame
	always @(posedge clk) begin
		if (switch_buf)
			write_buf <= ~write_buf;
	end
	
	// Output data from whichever buffer is read-enabled
	assign rd_data = (read_buf == 1'b0 ? buf0_q : buf1_q);
	
	// Instantiate RAMs
	ram_128x32 buf0 (
		.clock(clk),
		.data(wr_data),
		.rdaddress(rd_addr),
		.wraddress(wr_addr),
		.wren(buf0_wr_en && wr_en),
		.q(buf0_q)
	);
	
	ram_128x32 buf1 (
		.clock(clk),
		.data(wr_data),
		.rdaddress(rd_addr),
		.wraddress(wr_addr),
		.wren(buf1_wr_en && wr_en),
		.q(buf1_q)
	);
endmodule