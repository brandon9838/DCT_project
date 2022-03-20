`timescale 1ns/10ps
`define CYCLE 2.0
`define CYCLE_half 1.0
`define INFILE "DCT_data.txt"
`define OUTFILE "out_golden.pattern" 

module DCT_test;
parameter pattern_num = 128;
parameter latency=80;
wire [21:0] dataout_dct,dataout_idct;
wire [5:0] state_dct,state_idct;
wire [11:0] dct_out_used,dct_out_notused;
wire [7:0] idct_out_used,idct_out_notused;
reg [21:0] datain_dct,datain_idct;
reg  clk,rst_dct,rst_idct,mode_dct,mode_idct;
integer i, num, error;

reg  stop;
reg [7:0] data_base1 [0:200];
reg [11:0] result_dct [0:400];
reg [7:0] result_idct [0:400];


IG myDCT (
	clk,
	rst_dct,
	mode_dct,
	datain_dct,
	dataout_dct,
	dct_out_used,
	idct_out_notused,
	state_dct
);
IG myIDCT (
	clk,
	rst_idct,
	mode_idct,
	datain_idct,
	dataout_idct,
	dct_out_notused,
	idct_out_used,
	state_idct
);

initial begin
	$readmemb(`INFILE  , data_base1);
	//$readmemb(`OUTFILE , data_base2);
	clk = 1'b1;
	rst_dct =1'b1;
	rst_idct =1'b1;
	mode_dct=1'b0;
	mode_idct=1'b1;
	stop=0;
	error=0;
	i=0;
	#0.5 rst_dct=1'b0;
	#`CYCLE rst_dct=1'b1;
end

always begin #(`CYCLE_half) clk = ~clk;
end


initial begin
	datain_dct[21:0] = {1'b0,data_base1[0],13'b0000000000000};
	datain_idct=22'b0000000000000000000000;
	#(`CYCLE*2+0.5)
	for(num = 1; num < pattern_num; num = num + 1) begin
		@(negedge clk) begin
			datain_dct[21:0] = {1'b0,data_base1[num],13'b0000000000000};
		end
	end
	rst_idct=1'b0;
	#(`CYCLE_half+0.5) rst_idct=1'b1;		
	
	for(num = latency; num < latency+pattern_num; num = num + 1) begin
		@(negedge clk) begin
			datain_idct[21:0] = {result_dct[num],10'b0000000000};
		end
	end
end


always@(posedge clk) begin
	i <= i + 1;
	if (i >= 400)
		stop <= 1;
end

always@(posedge clk ) begin
	result_dct[i]=dct_out_used;
	result_idct[i]=idct_out_used;
end

initial begin
	@(posedge stop) begin
		for(num=0;num<pattern_num;num=num+1)begin
			if(data_base1[num]!=result_idct[num+pattern_num+latency])begin
				error=error+1;
				$display("Ans:     ",data_base1[num],          "\n");
				$display("Result:  ",result_idct[num+pattern_num+latency], "\n");
				$display("error:   ",error                   , "\n");
			end
			else begin
				$display("Ans:     ",data_base1[num],          "\n");
				$display("Result:  ",result_idct[num+pattern_num+latency], "\n");
			end
		end
		if(error==0)begin
			$display("==========================================\n");
			$display("======  Congratulation! ==================\n");
			$display("==========================================\n");
		end
		else begin
			$display("FAIL\n");
		end
		$writememb("DCT.txt",result_dct);
		$finish;
	end
end

/*================Dumping Waveform files====================*/
initial begin
	$fsdbDumpfile("powa.fsdb");
	$fsdbDumpvars; 
end

endmodule