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

// Exactly the same as a pingpong_buf, but with 32-bit writes rather than 8-bit

module word_write_pingpong_buf
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
	
	input [8:0]		rd_addr;
	output [7:0]	rd_data;
	
	input [6:0]		wr_addr;
	input [31:0]	wr_data;
	input			wr_en;
	
	input			switch_buf;
	output			cur_wr_buf;

	// Buffer select logic
	reg				write_buf;
	wire			buf0_rd_en, buf0_wr_en;
	wire			buf1_rd_en, buf1_wr_en;
	wire [7:0]		buf0_q;
	wire [7:0]		buf1_q;
	
	assign buf0_rd_en = (write_buf != 1'b0);
	assign buf0_wr_en = (write_buf == 1'b0);
	assign buf1_rd_en = (write_buf == 1'b0);
	assign buf1_wr_en = (write_buf != 1'b0);
	
	assign cur_wr_buf = write_buf;
	
	// Switch over buffers once we hit the end of the frame
	always @(posedge clk) begin
		if (switch_buf)
			write_buf <= ~write_buf;
	end
	
	// Output data from whichever buffer is read-enabled
	assign rd_data = (buf0_rd_en ? buf0_q : buf1_q);
	
	// Endian swap input data
	wire [31:0]		wr_data_enswap;
	assign wr_data_enswap = {wr_data[7:0],wr_data[15:8],wr_data[23:16],wr_data[31:24]};
	
	// Instantiate RAMs
	ram_8rd32wr buf0 (
		.clock(clk),
		.data(wr_data_enswap),
		.rdaddress(rd_addr),
		.wraddress(wr_addr),
		.wren(buf0_wr_en && wr_en),
		.q(buf0_q)
	);
	
	ram_8rd32wr buf1 (
		.clock(clk),
		.data(wr_data_enswap),
		.rdaddress(rd_addr),
		.wraddress(wr_addr),
		.wren(buf1_wr_en && wr_en),
		.q(buf1_q)
	);
endmodule