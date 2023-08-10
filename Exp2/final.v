
module fpadd (
    clk, reset, start,
    a, b,
    sum, 
    done
);

    input wire 		clk, reset, start;
    input wire [31:0] 	a, b;
    output [31:0] 	sum;
    output	 	done;

localparam INITIAL = 3'd0,
	   ONE	= 3'd1,	
	   TWO = 3'd2,
	   THREE = 3'd3,
	   FOUR = 3'd4,
	   DONE = 3'd5;
	   // excess case handled
	   
// State regs declaration 
reg [2:0] CurrentState;

// Registers to parse the 32-bit data
	wire sign_a, sign_b;		// 1 bit
	reg [7:0] exp_a, exp_b;		// 8 bits
	reg signed [24:0] mant_a, mant_b;	
	// 23 bits + 1 bit for the one of 1.xx + 1 for sign extension
	// signed reg is used for the arithmetic shift operation later used. 
	reg [7:0] ediff;
	reg sign_r;
	reg [7:0] exp_r;
	reg [25:0] mant_r;
	reg b23, b24;
	reg [4:0] one_index;

	reg signed [24:0] mant_a_q, mant_b_q;
	reg [25:0] mant_r_q;
	reg [7:0] exp_a_q, exp_b_q, exp_r_q;
	reg sign_r_q;
	reg [31:0] sum_q, sum_d;
	reg done_q, done_d;

	assign sign_a = a[31];
	assign sign_b = b[31];
	assign sum = sum_q;
	assign done = done_q;

// Synchronous State Transition
always @(posedge clk) begin
	if (reset) begin
		CurrentState	 <= INITIAL;
		mant_a_q 	     <= 0;
		mant_b_q 	     <= 0;
		sum_q        	 <= 0;
		exp_a_q 	     <= 0;
		exp_b_q	         <= 0;
		exp_r_q	         <= 0; 
		mant_r_q     	 <= 0;
		sign_r_q	     <= 0;
		done_q		     <= 0;
		
	end else begin
		mant_a_q     <= mant_a;
		mant_b_q 	 <= mant_b;
		sum_q        <= sum_d;
		exp_a_q 	 <= exp_a;
		exp_b_q	     <= exp_b;
		exp_r_q	     <= exp_r;
		mant_r_q	 <= mant_r; 
		sign_r_q	 <= sign_r;
		done_q		 <= done_d;
	end
end


// Conditional State Transition
always @(*) begin 
	CurrentState = INITIAL;
	done_d = 0;
	mant_a = mant_a_q;
	mant_b = mant_b_q;
	sum_d = sum_q;
	exp_a = exp_a_q;
	exp_b = exp_b_q;
	exp_r = exp_r_q;
	mant_r = mant_r_q;
	sign_r = sign_r_q;
	// default
	
	case (CurrentState)
		INITIAL: begin
			// 1. Start parsing input data
			// $display ("a_q = %b, b_q = %b\n", a, b);
			exp_a 	= 	a[30:23];
			exp_b 	= 	b[30:23];
			mant_a  = 	{2'b00, a[22:0]};   
			mant_b  = 	{2'b00, b[22:0]};
			sign_r  = 	0;
			mant_r  = 	0;
			// just the mantissa read for now, will update later
			
			if (start) 
				CurrentState = ONE;
			else 
				CurrentState = INITIAL;
				
		end
		
		ONE: begin
			// 2. Handle special cases
			if ((exp_a_q == 0) && (mant_a_q == 0)) begin
				sum_d 	= b;  // a = 0
				done_d  = 1'b1;
				CurrentState  = DONE;
				//$display("exited in special cases");
			end
			else if ((exp_b_q == 0) && (mant_b_q == 0)) begin	
				sum_d 	= a;  // b = 0
				done_d  = 1'b1;
				CurrentState  = DONE;
			end
			else if (exp_a_q == 8'hFF) begin
				sum_d 	= a;	// NaN or Inf
				done_d	= 1'b1;
				CurrentState  = DONE;
			end
			else if (exp_b_q == 8'hFF) begin
				sum_d 	= b;
				done_d	= 1'b1;
				CurrentState  = DONE;
			end
			else begin
				// 3. actual non-exceptional computation
				mant_a 	= 	{2'b01, a[22:0]};   // add 1 to make 1.xx
				mant_b 	= 	{2'b01, b[22:0]};   // a total 25-bit value
				CurrentState = TWO;
			end
		
		end
		
		TWO: begin
			
			
			// adjust mantissa sign, one bit used for sign extension
			if (sign_a) begin
				mant_a = -mant_a_q;
			end
			if (sign_b) begin
				mant_b = -mant_b_q;
			end
			
			// 3.2 compare exponents
			if (exp_a_q > exp_b_q) begin
			ediff  = exp_a_q - exp_b_q;
			exp_r  = exp_a_q;
			mant_b = mant_b_q >>> ediff; // arithmetic shift to retain MSB
			// 3.3 Compute Addition
			mant_r = {mant_a_q[24] ,mant_a_q} + {mant_b[24] ,mant_b};
			CurrentState = THREE;
			end
			else if (exp_a_q < exp_b_q) begin
			ediff 	= exp_b_q - exp_a_q;
			exp_r 	= exp_b_q;
			mant_a = mant_a_q >>> ediff;
			// 3.3 Compute Addition
			mant_r = {mant_a[24] ,mant_a} + {mant_b_q[24] ,mant_b_q};
			CurrentState = THREE;
			end
			else begin // they are equal
				exp_r = exp_a_q;
				// 3.3 Compute Addition
				mant_r = {mant_a[24] ,mant_a} + {mant_b[24] ,mant_b};
				CurrentState = THREE;
			end
		end

		THREE: begin
			
			// 3.4 Sign of the result
			if (mant_r_q[25]) begin
				// MSB indicates sign
				// negative
				sign_r = 1;
				mant_r = -mant_r_q;
			end
			else begin
				// postitive
				sign_r = 0;
			end
			CurrentState = FOUR;
		end

		FOUR: begin
			// 3.5 Normalize
			// mant_r is now unsigned
			b23 = mant_r_q[23];
			b24 = mant_r_q[24];
			if (!mant_r_q) begin
				// 3.5.1 numbers cancelled out
				exp_r = 0;
				CurrentState = DONE;
			end
			else if ((!b24) && (b23)) begin
				// 3.5.2 already normalized 
				// no need to normalize
				CurrentState = DONE;
			end
			else if (b24) begin
				// 3.5.3 Overflow - renormalize
				mant_r = {1'b0, mant_r_q[25:1]};
				exp_r  = exp_r_q + 1'b1;
				CurrentState = DONE;
			end
			else begin 
				// 3.5.4 Search for leading one
				if(b23) begin
					// normalized
					CurrentState = DONE;
				end
				else begin 
					// keep looping until normalized
					case (1)
						mant_r_q[22]: begin one_index = 22; end
						mant_r_q[21]: begin one_index = 21; end
						mant_r_q[20]: begin one_index = 20; end
						mant_r_q[19]: begin one_index = 19; end
						mant_r_q[18]: begin one_index = 18; end
						mant_r_q[17]: begin one_index = 17; end
						mant_r_q[16]: begin one_index = 16; end
						mant_r_q[15]: begin one_index = 15; end
						mant_r_q[14]: begin one_index = 14; end
						mant_r_q[13]: begin one_index = 13; end
						mant_r_q[12]: begin one_index = 12; end
						mant_r_q[11]: begin one_index = 11; end
						mant_r_q[10]: begin one_index = 10; end
						mant_r_q[9]: begin one_index = 9; end
						mant_r_q[8]: begin one_index = 8; end
						mant_r_q[7]: begin one_index = 7; end
						mant_r_q[6]: begin one_index = 6; end
						mant_r_q[5]: begin one_index = 5; end
						mant_r_q[4]: begin one_index = 4; end
						mant_r_q[3]: begin one_index = 3; end
						mant_r_q[2]: begin one_index = 2; end
						mant_r_q[1]: begin one_index = 1; end
						mant_r_q[0]: begin one_index = 0; end
						default:           one_index = 0;

					endcase
					mant_r = mant_r_q << (23 - one_index);
					exp_r  =  exp_r_q - (23 - one_index);
					CurrentState = DONE;
				
				end
			end
		end
		DONE: begin
			// 4. Generate output
			sum_d	= {sign_r_q, exp_r_q, mant_r_q[22:0]};
			done_d	= 1'b1;
			
			if (start == 0) CurrentState = INITIAL;
           		else CurrentState = DONE;
		    end
				
		default: 
			CurrentState = INITIAL;
	endcase				
end	
endmodule

