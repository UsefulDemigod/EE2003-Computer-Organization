module immgen(
  input [31:0] idata,
  output [31:0] imm
);

// Usual Stuff
wire [6:0] opcode;
wire [2:0] funct3;

assign funct3 = idata[14:12];
assign opcode = idata[6:0];

// Convert all different immediate inputs to 32-bit signed / unsigned ones based on the opcode

assign imm = (opcode == 7'b0100011) ?                                           // Store operations
                {{20{idata[31]}},idata[31:25],idata[11:7]} :
						 (opcode == 7'b0110111 || opcode == 7'b0010111) ?                   // LUI , AUIPC
                {idata[31:12],{12{1'b0}}} :
						 (opcode == 7'b1101111) ?                                           // JAL
                {{12{idata[31]}},idata[19:12],idata[20],idata[30:21], 1'b0}:
             (opcode == 7'b1100011 ) ?                                          // Branch Signed
                {{20{idata[31]}},idata[7],idata[30:25],idata[11:8],1'b0} :
                  {{20{idata[31]}},idata[31:20]};                               // Load Signed , ALU , ALUI ,JALR

endmodule
