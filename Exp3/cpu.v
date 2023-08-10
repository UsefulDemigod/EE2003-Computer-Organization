module cpu (
    input clk,
    input reset,
    output [31:0] iaddr,
    input [31:0] idata,
    output [31:0] daddr,
    input [31:0] drdata,
    output [31:0] dwdata,
    output [3:0] dwe
);

//Control Unit - Wires
wire [2:0] branch;
wire [2:0] regsrc;
wire mem2reg;
wire [5:0] ALUop;
wire alusrc;
wire regwrite;
wire [3:0] memwrite;

// Regfile - Wires
wire [31:0] regwdata;
wire [31:0] data_reg;
wire [31:0] datawire1;
wire [31:0] datawire2;

// IMM - Wires
wire [31:0] imm;

// ALU - Wires
wire [31:0] alu_out;
wire condition_out;
wire [6:0] opcode;
assign opcode = idata[6:0];

// PC - Wires
reg [31:0] PC;
wire [31:0] PC_next;
wire [31:0] PC_plus4;

// ldata - Wires
wire [31:0] ldata;

//// Modules

// Control
control CONTROL(
  .idata(idata),
  .branch(branch),
  .regsrc(regsrc),
  .mem2reg(mem2reg),
  .ALUop(ALUop),
  .alusrc(alusrc),
  .regwrite(regwrite),
  .memwrite(memwrite)
	);

// Register
regfile REGFILE(
  	.rs1(idata[19:15]),
  	.rs2(idata[24:20]),
  	.rd(idata[11:7]),
  	.we(regwrite),
    .wdata(regwdata),
  	.rv1(datawire1),
  	.rv2(datawire2),
    .clk(clk)
  	);

// Offset calculation
  immgen IMMGEN(
  .idata(idata),
  .imm(imm)
  );

// Arithmetic Logic Unit
alu32 ALU32(
  .op(ALUop),
	.rv1((opcode == 7'b0010111) ? iaddr : datawire1), // AUIPC , Other
	.rv2( alusrc ? imm : datawire2),                  // Load Immediate / From Register 2
  .rvout(alu_out),
  .condition_out(condition_out)
	);


// Program Counter Module
PC ProgCount(
		.PC(PC),
		.imm(imm),
		.branch(branch),
		.condition_out(condition_out),
		.alu_out(alu_out),
		.PC_plus4(PC_plus4),
		.PC_next(PC_next)
		);

///  Operations

// Store Operations

// Handle Alignment Exceptions if any 
assign dwe =  (memwrite == 4'b1111 && daddr[1:0]== 2'b00) ? 4'b1111:
      				(memwrite == 4'b0011 && daddr[1:0]== 2'b00) ? 4'b0011:
      				(memwrite == 4'b0011 && daddr[1:0]== 2'b10) ? 4'b1100:
      				(memwrite == 4'b0001 && daddr[1:0]== 2'b00) ? 4'b0001:
      				(memwrite == 4'b0001 && daddr[1:0]== 2'b01) ? 4'b0010:
      				(memwrite == 4'b0001 && daddr[1:0]== 2'b10) ? 4'b0100:
      				(memwrite == 4'b0001 && daddr[1:0]== 2'b11) ? 4'b1000:
               4'b0000;

// rs2 Value
assign dwdata = (idata[14:12] === 3'b000) ? {4{datawire2[7:0]}} :
                (idata[14:12] === 3'b001) ? {2{datawire2[15:0]}}:
                datawire2;

// Daddr = ( rs1 + imm % 4096 ) , First statement corresponds to load while second to store.
assign daddr = (datawire1+imm);


// Load Operations

// LW,LH,LB
assign ldata =  ((idata[14:12] === 3'b001 || idata[14:12] === 3'b101) && mem2reg) ?  // LH , LHU
                ( 32'h0000fff & (drdata >> (daddr[1:0] * 8))) :
                ((idata[14:12] === 3'b000 || idata[14:12] === 3'b100) && mem2reg) ?  // LB , LBU
                ( 32'h000000ff & (drdata >> (daddr[1:0] * 8))) :
                drdata;                                                              // LW

// What to load to Data Memory ?
// If load operation -> ldata , else alu_out
assign data_reg = mem2reg ? ldata  : alu_out;

// Store value to register based on Register Source
assign regwdata = (reset) ? 0 : (regsrc == 2'b00) ? imm :     // Immediate data for LUI
						      (regsrc == 2'b10) ? PC_plus4 : data_reg ;   // JAL , Normal Operations

// Assign iaddr to Program Counter
assign iaddr = PC;

// Reset and Change Program Counter at Clk edges
always @(posedge reset or posedge clk) begin
		if (reset) begin
			PC <= 32'h00000000;
		end else begin
			PC <= PC_next;
    end
	end

endmodule
