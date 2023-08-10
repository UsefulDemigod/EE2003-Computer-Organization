module control (
    input [31:0] idata,
    output [2:0] branch,
    output [2:0] regsrc,
    output  mem2reg,
    output  [5:0] ALUop,
    output alusrc,
    output regwrite,
    output [3:0] memwrite
);

// Opcode and the 3-bit functions
wire [6:0] opcode;
wire [2:0] funct3;
assign funct3 = idata[14:12];
assign opcode = idata[6:0];

// Branch code
assign branch = (opcode == 7'b1100011 && (funct3 == 3'b000 || funct3 == 3'b101 || funct3 == 3'b111))? 3'b010: // Branch if Zero
					      (opcode == 7'b1100011 && (funct3 == 3'b001 || funct3 == 3'b100 || funct3 == 3'b110))? 3'b001: // Branch if Non-zero
    					  (opcode == 7'b1101111 )? 3'b011 :                                                             // JAL
    					  (opcode == 7'b1100111 )? 3'b100 :                                                             // JALR
                3'b000;                                                                                       // No branch

//  Regwrite
assign regwrite = (opcode == 7'b0000011 || opcode == 7'b0110011 || opcode == 7'b0010011 || // Load , ALU-I , ALU
                   opcode == 7'b0110111 || opcode == 7'b0010111 || opcode == 7'b1101111 || // LUI , AUIPC , JAL
                   opcode == 7'b1100111 );                                                 // JALR
//  Memwrite
assign memwrite = (opcode == 7'b0100011 && funct3 == 3'b010) ? 4'b1111 :           // SW
                  (opcode == 7'b0100011 && funct3 == 3'b001) ? 4'b0011 :           // SH
                  (opcode == 7'b0100011 && funct3 == 3'b000) ? 4'b0001 : 4'b0000;  // SB , None

// Register source
assign regsrc = (opcode == 7'b0110111) ? 2'b00 :                        // Immediate Generated - For LUI
                (opcode == 7'b1101111 || opcode == 7'b1100111) ? 2'b10  // PC_Next = PC+4
                : 2'b01;                                                // JAL

// Memtoreg
assign mem2reg = (opcode == 7'b0000011);    // Load operations

//alusrc
// Choose Immediate value or value from register for second value for ALU
assign alusrc = (opcode == 7'b0010011 || opcode == 7'b0000011 || // ALUI , Load
                 opcode == 7'b1100111 || opcode == 7'b0010111 ); // JALR , AUIPC 


// ALUop
// To get output from ALU , We manually set Branching operations to match the Sub ,Add , Comp Opcode
assign ALUop = (opcode == 7'b0010111)? 6'b010000 :                      // For AUIPC 
                (opcode == 7'b1100011)?
                (funct3 == 3'b000 || funct3 == 3'b001 )? 6'b010001 :    // Branch - Subtract
                (funct3 == 3'b100 || funct3 == 3'b101 )? 6'b010101 :    // Branch - Signed Compare
                (funct3 == 3'b110 || funct3 == 3'b111 )? 6'b010111      // Branch - Unsigned Compare
                :{1'b0,idata[5],idata[14:12],idata[30]}                 // Normal ALU
                :{1'b0,idata[5],idata[14:12],idata[30]};                // Normal ALU for completion of statement

endmodule
