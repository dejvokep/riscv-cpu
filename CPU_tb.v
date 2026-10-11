module testbench();
	reg         clk, reset;
	wire [31:0] data_to_mem, address_to_mem;
	wire        write_enable;

	top simulated_system(clk, reset, data_to_mem, address_to_mem, write_enable);

    // run the test
	initial	begin
		$dumpfile("test");
		$dumpvars;
		reset<=1; # 2; reset<=0;
		#1000;
		$writememh("memfile_data_after_simulation.hex", simulated_system.dmem.RAM,0,63);
		$finish;
	end

	// clock
	always begin
		clk<=1; # 1; clk<=0; # 1;
	end
endmodule