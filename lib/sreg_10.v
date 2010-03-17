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

// Shifts one bit out of Q every clock cycle for which en is asserted, MSB-first. Synchronous load from values at data when load is asserted.

module sreg_10
(
	clk,
	load,
	
	data,
	
	en,
	q
);

	input			clk;
	input			load;
	
	input [9:0]		data;
	
	input			en;
	output			q;
	
	// IO regs
	reg [9:0]		sreg;
	
	always @(posedge clk) begin
		if (load)
			sreg <= data;
		else if (en)
			sreg <= {sreg[8:0], 1'b0};
	end
	
	assign q = sreg[9];
	
endmodule