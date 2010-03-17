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

always @(subframe_idx) begin
	case (subframe_idx)
		//5'b00000: -- non-audio subframe
		//5'b00001: -- non-audio subframe
		
		// Field 0
		5'b00010: field_byte_select = 5'b00000;
		5'b00011: field_byte_select = 5'b00001;
		5'b00100: field_byte_select = 5'b00010;
		
		// Field 1
		5'b00101: field_byte_select = 5'b00100;
		5'b00110: field_byte_select = 5'b00101;
		5'b00111: field_byte_select = 5'b00110;
		
		// Field 2
		5'b01000: field_byte_select = 5'b01000;
		5'b01001: field_byte_select = 5'b01001;
		5'b01010: field_byte_select = 5'b01010;
		
		// Field 3
		5'b01011: field_byte_select = 5'b01100;
		5'b01100: field_byte_select = 5'b01101;
		5'b01101: field_byte_select = 5'b01110;
		
		// Field 4
		5'b01110: field_byte_select = 5'b10000;
		5'b01111: field_byte_select = 5'b10001;
		5'b10000: field_byte_select = 5'b10010;
		
		// Field 5
		5'b10001: field_byte_select = 5'b10100;
		5'b10010: field_byte_select = 5'b10101;
		5'b10011: field_byte_select = 5'b10110;
		
		// Field 6
		5'b10100: field_byte_select = 5'b11000;
		5'b10101: field_byte_select = 5'b11001;
		5'b10110: field_byte_select = 5'b11010;
		
		// Field 7
		5'b10111: field_byte_select = 5'b11100;
		5'b11000: field_byte_select = 5'b11101;
		5'b11001: field_byte_select = 5'b11110;
		
		// Other possible field indices are not valid.
		default: field_byte_select = 5'b11111;
	endcase
end