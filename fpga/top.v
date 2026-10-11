module top( input	clk, reset, sw0,
		    output	sseg_a, sseg_b, sseg_c, sseg_d, sseg_e, sseg_f, sseg_g);

	wire [31:0] pc, instruction, address_to_mem, data_from_mem, data_to_mem;
	wire write_enable;

	inst_mem  imem(pc[7:2], instruction);
	data_mem  dmem(clk, write_enable, sw0, address_to_mem, data_to_mem, data_from_mem, sseg_a, sseg_b, sseg_c, sseg_d, sseg_e, sseg_f, sseg_g);
	processor CPU(clk, reset, pc, instruction, write_enable, address_to_mem, data_to_mem, data_from_mem);
endmodule

//-------------------------------------------------------------------
module data_mem(	input	clk, we, sw0,
		 			input 	[31:0] address, wd,
		 			output	[31:0] rd,
					output	sseg_a, sseg_b, sseg_c, sseg_d, sseg_e, sseg_f, sseg_g);

	reg[31:0] RAM[63:0];

	assign rd = address == 0 ? {31'b0, sw0} : RAM[address[31:2]]; // word aligned
	assign sseg_a = RAM[1][0], sseg_b = RAM[1][1], sseg_c = RAM[1][2], sseg_d = RAM[1][3], sseg_e = RAM[1][4], sseg_f = RAM[1][5], sseg_g = RAM[1][6];

	always @(posedge clk)
		if (we)
			RAM[address[31:2]]<=wd;
endmodule

//-------------------------------------------------------------------
module inst_mem(	input  [5:0]  address,
		 			output [31:0] rd);

	reg[31:0] RAM[63:0];
	initial begin
		$readmemh("memfile_inst.hex",RAM,0,63);
	end
	assign rd = RAM[address]; // word aligned
endmodule