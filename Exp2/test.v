module fpadd (
    clk, reset, start,
    a, b,
    sum, 
    done
);

    input wire 		clk, reset, start;
    input wire [31:0] 	a, b;
    output reg [31:0] 	sum;
    output reg	 	done;

localparam ZERO = 3'd0,
	   ONE = 3'd1,
	   TWO = 3'd2,
	   THREE = 3'd3,
	   FOUR = 3'd4,
	   final = 3'd5;
	   
reg [2:0] CurrentState;
reg [2:0] NextState;

	reg sign_a, sign_b;		// 1 bit
	reg [7:0] exp_a, exp_b;		// 8 bits
	reg signed [24:0] mant_a, mant_b;	
	// 23 bits + 1 bit for the one of 1.xx + 1 for sign extension
	// signed reg used for arithmetic shift  
	reg [7:0] ediff;
	reg sign_r;
	reg [7:0] exp_r;
	reg [25:0] mant_r;
	reg b23, b24;
	reg [4:0] one_index;
	

always @(posedge clk) begin
	if (reset) CurrentState <= ZERO;
	else CurrentState <= NextState;

	// default
	
	case (CurrentState)
		ZERO: begin
			if (reset) begin
				done 	= 	0;
				sum  	= 	32'b0;
				sign_a 	= 	31'b0;
				sign_b 	= 	31'b0;
				exp_a 	= 	8'b0;
				exp_b 	= 	8'b0;
				mant_a 	= 	25'b0;
				mant_b 	= 	25'b0;
				NextState  = ZERO;
			end
			else if (start) begin
				// 1. Start parsing input data
				// $display ("a = %b, b = %b", a, b);
				done 	= 	0;
				sum  	= 	32'b0;
				sign_a 	= 	a[31];
				sign_b 	= 	b[31];
				exp_a 	= 	a[30:23];
				exp_b 	= 	b[30:23];
				mant_a 	= 	{2'b00, a[22:0]};   
				mant_b 	= 	{2'b00, b[22:0]};
				
				// just the mantissa read for now, will update later
				
				// 2. special cases
				if ((exp_a == 0) && (mant_a == 0)) begin
					sum 	= b;  // a = 0
					done 	= 1'b1;
					NextState  = ZERO;
				end
				else if ((exp_b == 0) && (mant_b == 0)) begin	
					sum 	= a;  // b = 0
					done 	= 1'b1;
					NextState  = ZERO;
				end
				else if (exp_a == 8'hFF) begin
					sum 	= a;	// NaN or Inf
					done	= 1'b1;
					NextState  = ZERO;
				end
				else if (exp_b == 8'hFF) begin
					sum 	= b;
					done	= 1'b1;
					NextState  = ZERO;
				end
				else begin
					// 3. actual non-exceptional computation
					$display ("No special case.");
					NextState = ONE;
				end
			end
			else NextState = ZERO;
		end
		ONE: begin
			mant_a 	= 	{2'b01, a[22:0]};   // add 1 to make 1.xx
			mant_b 	= 	{2'b01, b[22:0]};   // a total 25-bit value
			
			// adjust mantissa sign, one bit used for sign extension
			if (sign_a) begin
				mant_a = -mant_a;
				$display("arg A was negative\nchng from %b to %b\n", -mant_a, mant_a);
			end
			if (sign_b) begin
				mant_b = -mant_b;
				$display("arg B was negative\n");
			end
			
			// 3.2 compare exponents
			if (exp_a > exp_b) begin
				$display ("A had a bigger exponent.");
                begin
			ediff  = exp_a - exp_b;
			exp_r  = exp_a;
			mant_b = mant_b >>> ediff; // arithmetic shift to retain MSB
			NextState = TWO;
		    end 
			end
			else if (exp_a < exp_b) begin
				$display ("B had a bigger exponent.n");
				 begin
			    ediff 	= exp_b - exp_a;
			    exp_r 	= exp_b;
			    mant_a = mant_a >>> ediff;
			    NextState = TWO;
		         end
			end
			else begin // they are equal
				$display ("Equal exponents.");
				exp_r = exp_a;
				NextState = TWO;
			end
		end
		TWO: begin
			// 3.3 Compute Addition
			mant_r = {mant_a[24] ,mant_a} + {mant_b[24] ,mant_b};
			$display("mant_a = %b, mant_b = %b\nmant_r = %b\n", mant_a , mant_b, mant_r);
			// 3.4 Sign of the result
			if (mant_r[25]) begin
				// sign bit is MSB
				// negative
				$display("result negative.");
				sign_r = 1;
				mant_r = -mant_r;
			end
			else begin
				// postitive
				$display("result positive.");
				sign_r = 0;
			end
			NextState = THREE;
		end
		THREE: begin
			// 3.5 Normalize
			// mant_r is now unsigned
			b23 = mant_r[23];
			b24 = mant_r[24];
			if (!mant_r) begin
				// 3.5.1 numbers cancelled out
				exp_r = 0;
				NextState = FOUR;
			end
			else if ((!b24) && (b23)) begin
				// 3.5.2 already normalized 
				$display("no need to normalize");
				NextState = FOUR;
			end
			else if (b24) begin
				// 3.5.3 Overflow
				$display("normalize for overflow\n");
				mant_r = {1'b0, mant_r[25:1]};
				exp_r  = exp_r + 1'b1;
				NextState = FOUR;
			end
			else begin 
				// 3.5.4 Search for leading one
				if(b23) begin
					// normalized
					$display("normalized for small delta\n");
					NextState = FOUR;
				end
				else begin 
                    // checking all places				
					$display("normalize for small delta.");
					case (1)
						mant_r[22]: begin one_index = 22; end
						mant_r[21]: begin one_index = 21; end
						mant_r[20]: begin one_index = 20; end
						mant_r[19]: begin one_index = 19; end
						mant_r[18]: begin one_index = 18; end
						mant_r[17]: begin one_index = 17; end
						mant_r[16]: begin one_index = 16; end
						mant_r[15]: begin one_index = 15; end
						mant_r[14]: begin one_index = 14; end
						mant_r[13]: begin one_index = 13; end
						mant_r[12]: begin one_index = 12; end
						mant_r[11]: begin one_index = 11; end
						mant_r[10]: begin one_index = 10; end
						mant_r[9]: begin one_index = 9; end
						mant_r[8]: begin one_index = 8; end
						mant_r[7]: begin one_index = 7; end
						mant_r[6]: begin one_index = 6; end
						mant_r[5]: begin one_index = 5; end
						mant_r[4]: begin one_index = 4; end
						mant_r[3]: begin one_index = 3; end
						mant_r[2]: begin one_index = 2; end
						mant_r[1]: begin one_index = 1; end
						mant_r[0]: begin one_index = 0; end

					endcase
					$display("one_index = %b", one_index);
					mant_r = mant_r << (23 - one_index);
					exp_r  =  exp_r - (23 - one_index);
					NextState = FOUR;
				
				end
			end
		end
		FOUR: begin
			// 4. output
			$display("sign = %b, exp = %b, mant = %b\n", sign_r, exp_r, mant_r);
			sum	= {sign_r, exp_r, mant_r[22:0]};
			done	= 1'b1;
			NextState = ZERO;
		end
		final: begin
			NextState = ZERO;
		end
	endcase				
end	
endmodule