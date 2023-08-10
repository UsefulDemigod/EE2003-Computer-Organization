module PC(
    input [31:0] PC,
    input [31:0] imm,
    input [2:0] branch,
    input condition_out,
	  input [31:0] alu_out,
	  output [31:0] PC_plus4,
    output [31:0] PC_next
    );

wire [31:0] PC_branch;

assign PC_branch = PC + imm;
assign PC_plus4 = PC + 32'd4;

assign PC_next = (branch == 3'b001 && (~condition_out) ) ? PC_branch :                  // IF ( BNE, BLT, BLTU )
                 (branch == 3'b001 && condition_out ) ? PC_plus4 :                          // Else
					       (branch == 3'b010 && condition_out ) ? PC_branch :                     // IF ( BEQ, BGE, BGEU )
                 (branch == 3'b010 && (~condition_out) ) ? PC_plus4 :                       // Else
					       (branch == 3'b011) ?  PC_branch :                                      // JAL
					       (branch == 3'b100) ? (alu_out & 32'hFFFFFFFE) :PC_plus4;               // JALR

endmodule
