`default_nettype none
module processor(   input         clk, reset,
                    output [31:0] PC,
                    input  [31:0] instruction,
                    output        WE,
                    output [31:0] address_to_mem,
                    output [31:0] data_to_mem,
                    input  [31:0] data_from_mem);
    wire[31:0] pcNext, immOperand, rs1, rs2, wd3, wd3x, aluInB, aluResult, pc4, pcImm, pcBranch;
    wire[2:0] insType, aluOperation;
    wire regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr, branchJalx, zero, branch;

    assign pc4 = PC + 4;
    assign pcImm = PC + immOperand;

    assign branchJalx = branchJal | branchJalr;
    assign branch = (branchBeq & zero) | (branchBlt & aluResult[0]) | branchJalx;

    assign address_to_mem = aluResult;
    assign data_to_mem = rs2;
    assign WE = memWrite;

    mux2_32bit JalrPcMux(branchJalr, pcImm, aluResult, pcBranch);
    mux2_32bit NextPcMux(branch, pc4, pcBranch, pcNext); // choose between PC + 4 and PC + imm if branching
    reg_32bit PcReg(clk, reset, pcNext, PC); // sync the PC

    mux2_32bit Wd3xMux(branchJalx, aluResult, pc4, wd3x);  // choose between aluResult and PC + 4
    mux2_32bit Wd3Mux(memToReg, wd3x, data_from_mem, wd3); // choose between wd3x and Memory[address_to_mem]

    control_unit ControlUnit(instruction, insType, aluOperation, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr);
    reg_array RegArray(clk, instruction[19:15], instruction[24:20], instruction[11:7], regWrite, wd3, rs1, rs2);
    imm_decode ImmDecode(insType, instruction[31:7], immOperand);

    mux2_32bit AluImmMux(aluImm, rs2, immOperand, aluInB); // choose between [rs2] and imm for alu's inB
    alu AluUnit(aluOperation, rs1, aluInB, aluResult, zero);
endmodule

//-------------------------------------------------------------------
module reg_32bit(input clk, reset, input[31:0] in, output reg[31:0] out);
    always @(posedge clk)
        out <= reset ? 0 : in;
endmodule

//-------------------------------------------------------------------
module mux2_32bit(input select, input[31:0] in0, input[31:0] in1, output[31:0] out);
    assign out = select == 0 ? in0 : in1;
endmodule

//-------------------------------------------------------------------
module imm_decode(input[2:0] type, input[31:7] ins, output reg[31:0] imm);
    always @(*)
        case (type)
            0: imm = 0;                                                 // R
            1: imm = {{20{ins[31]}}, ins[31:20]};                                        // I
            2: imm = {{20{ins[31]}}, ins[31:25], ins[11:7]};                           // S
            3: imm = {{20{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};          // B
            4: imm = ins[31:12] << 12;                                        // U
            default: imm = {{12{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};  // J
        endcase
endmodule

//-------------------------------------------------------------------
module reg_array(input clk, input[4:0] a1, input[4:0] a2, input[4:0] a3, input we, input[31:0] wd3, output[31:0] rd1, output[31:0] rd2);
    reg[31:0] arr[31:0];
    
    assign rd1 = a1 == 0 ? 0 : arr[a1];
    assign rd2 = a2 == 0 ? 0 : arr[a2];

    always @(posedge clk)
        if (we)
            arr[a3] <= wd3;
endmodule

//-------------------------------------------------------------------
// 0 +, 1 -, 2 &, 3 >>, 4 <, 5 vecadd, 6 vecavg
module alu(input[2:0] op, input[31:0] inA, inB, output reg[31:0] out, output zero);
    assign zero = out == 0;

    wire[7:0] vecSumO1, vecSumO2, vecSumO3, vecSumO4;
    vec_sum vecSum1(inA[31:24], inB[31:24], vecSumO1);
    vec_sum vecSum2(inA[23:16], inB[23:16], vecSumO2);
    vec_sum vecSum3(inA[15:8], inB[15:8], vecSumO3);
    vec_sum vecSum4(inA[7:0], inB[7:0], vecSumO4);

    wire[7:0] vecAvgO1, vecAvgO2, vecAvgO3, vecAvgO4;
    vec_avg vecAvg1(inA[31:24], inB[31:24], vecAvgO1);
    vec_avg vecAvg2(inA[23:16], inB[23:16], vecAvgO2);
    vec_avg vecAvg3(inA[15:8], inB[15:8], vecAvgO3);
    vec_avg vecAvg4(inA[7:0], inB[7:0], vecAvgO4);

    always @(*)
        case (op)
            0: out = inA + inB;
            1: out = inA - inB;
            2: out = inA & inB;
            3: out = inA >> inB[4:0];
            4: out = $signed(inA) < $signed(inB) ? 1 : 0;
            5: out = {vecSumO1, vecSumO2, vecSumO3, vecSumO4};
            default: out = {vecAvgO1, vecAvgO2, vecAvgO3, vecAvgO4};
        endcase
endmodule

//-------------------------------------------------------------------
module vec_sum(input[7:0] inA, inB, output[7:0] out);
    assign out = inA + inB;
endmodule

//-------------------------------------------------------------------
module vec_avg(input[7:0] inA, inB, output[7:0] out);
    assign out = ($signed({inA[7], inA}) + $signed({inB[7], inB})) >>> 1;
endmodule

//-------------------------------------------------------------------
module control_unit(    input [31:0]    ins,
                        output reg[2:0] insType,
                        output reg[2:0] aluOp,
                        output reg      regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr);
    always @(*)
        casez (ins)
            32'b0000000_?????_?????_000_?????_0110011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b000_000_1_0_0_0_0_0_0_0; // add, R
            32'b???????_?????_?????_000_?????_0010011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b001_000_1_1_0_0_0_0_0_0; // addi, I
            32'b0000000_?????_?????_111_?????_0110011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b000_010_1_0_0_0_0_0_0_0; // and, R
            32'b0100000_?????_?????_000_?????_0110011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b000_001_1_0_0_0_0_0_0_0; // sub, R
            32'b0000000_?????_?????_101_?????_0110011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b000_011_1_0_0_0_0_0_0_0; // srl, R
            32'b???????_?????_?????_000_?????_1100011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b011_001_0_0_1_0_0_0_0_0; // beq, B
            32'b???????_?????_?????_100_?????_1100011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b011_100_0_0_0_1_0_0_0_0; // blt, B
            32'b???????_?????_?????_010_?????_0000011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b001_000_1_1_0_0_1_0_0_0; // lw, I
            32'b???????_?????_?????_010_?????_0100011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b010_000_0_1_0_0_0_1_0_0; // sw, S
            32'b???????_?????_?????_???_?????_1101111: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b101_000_1_0_0_0_0_0_1_0; // jal, J
            32'b???????_?????_?????_000_?????_1100111: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b001_000_1_1_0_0_0_0_0_1; // jalr, I
            32'b0000000_?????_?????_000_?????_0001011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b000_101_1_0_0_0_0_0_0_0; // add_v, R
            32'b0000000_?????_?????_001_?????_0001011: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 'b000_110_1_0_0_0_0_0_0_0; // avg_v, R
            default: {insType, aluOp, regWrite, aluImm, branchBeq, branchBlt, memToReg, memWrite, branchJal, branchJalr} = 0;
        endcase
endmodule
`default_nettype wire