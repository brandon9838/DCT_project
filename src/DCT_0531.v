module IG(
	clk,
	rst,
	mode_w,
	datain,
	dataout,
	DCT_out,
	IDCT_out,
	state
);

input clk,rst,mode_w;
input [21:0] datain;
output [21:0] dataout;
output [11:0] DCT_out;
output [7:0] IDCT_out;
output [5:0] state;

wire [5:0] state_trans;     //state counter
wire [21:0] dataout_trans;  //transpose_out
wire [22:0] add_dru,sub_dru,MUXC_dru,MUXD_dru; //dru_out
wire [21:0] acfout,bdegout;  //acf,bdeg_out
wire [21:0] idruout,dataout_temp; //idru_out
reg mode;

assign state=state_trans;
assign dataout=dataout_temp;
assign DCT_out=dataout_temp[20:9]+dataout_temp[8];
assign IDCT_out=dataout_temp[13:6]+dataout_temp[5];


dru mydru(
	datain,
	dataout_trans,
	rst,
	clk,
	state_trans[2:0],
	add_dru,
	sub_dru,
	MUXC_dru,
	MUXD_dru
);
acf myacf(
	MUXC_dru,
	add_dru,
	clk,
	rst,
	mode, //0->dct 1->idct
	state_trans[2:0],
	acfout
);
bdeg mybdeg(
	MUXD_dru,
	sub_dru,
	clk,
	rst,
	mode, //0->dct 1->idct
	state_trans[2:0],
	bdegout
);
idru myidru(
	acfout,
	bdegout,
	rst,
	clk,
	mode, //0->dct 1->idct
	state_trans[2:0],
	idruout,
	dataout_temp
);
transpose mytrans(
	clk,
	rst,
	state_trans,
	idruout,
	dataout_trans
);
state_counter mystate_counter(
	clk,
	rst,
	state_trans
);

always@(posedge clk or negedge rst)begin
	if (!rst)begin
		mode<=0;
	end
	else begin
		mode<=mode_w;
	end
end

endmodule




module state_counter(
	clk,
	rst,
	state
);
input clk,rst;
output [5:0] state;
reg [5:0] state;
wire [5:0] state_w;
assign state_w=state+6'b000001;
always@(posedge clk or negedge rst)begin
	if(!rst)begin
		state<=6'b000000;
	end
	else begin
		state<=state_w;
	end
end
endmodule




module transpose(
	clk,
	rst,
	state,
	datain,
	dataout
);
input clk,rst;
input [5:0] state;
input [21:0] datain;
output [21:0]dataout;
//output [5:0] state;


reg [21:0] dataout;
//reg [5:0] state_w,state_r;
reg mode_in_w,mode_in_r,mode_out_w,mode_out_r;
wire [2:0] index_x_in,index_y_in,index_x_out,index_y_out;
wire [5:0] innum,outnum;
reg [21:0] register_w [7:0][7:0];
reg [21:0] register_r [7:0][7:0];

integer i,j;

//assign state=state_r;
assign innum=state-6'b001011;
assign outnum=state-6'b000011;
assign index_x_in=mode_in_r?innum[5:3]:innum[2:0];
assign index_y_in=mode_in_r?innum[2:0]:innum[5:3];
assign index_x_out=mode_out_r?outnum[5:3]:outnum[2:0];
assign index_y_out=mode_out_r?outnum[2:0]:outnum[5:3];

always@(*)begin
	//state_w=state_r+6'b000001;
	mode_in_w=(state==6'b001011)?!mode_in_r:mode_in_r;
	mode_out_w=(state==6'b000011)?!mode_out_r:mode_out_r;
	for(i=0;i<8;i=i+1)begin
		for(j=0;j<8;j=j+1)begin
			register_w[i][j]=register_r[i][j];
		end
	end
	register_w[index_x_in][index_y_in]=datain;
end
always@ (posedge clk or negedge rst)begin
	if(!rst)begin
		for(i=0;i<8;i=i+1)begin
			for(j=0;j<8;j=j+1)begin
				register_r[i][j]<=22'b0000000000000000000000;
			end
		end
		mode_in_r<=1'b1;
		mode_out_r<=1'b1;
		//state_r<=6'b000000;
		dataout<=22'b0000000000000000000000;
	end
	else begin
		for(i=0;i<8;i=i+1)begin
			for(j=0;j<8;j=j+1)begin
				register_r[i][j]<=register_w[i][j];
			end
		end
		mode_in_r<=mode_in_w;
		mode_out_r<=mode_out_w;
		//state_r<=state_w;
		dataout<=register_r[index_x_out][index_y_out];
	end
end
endmodule

module idru(
	MUXA,
	MUXB,
	rst,
	clk,
	mode, //0->dct 1->idct
	state,
	out_2_trans,
	out_2_port
);
//port
input [21:0] MUXA,MUXB;
input clk,rst,mode;
input [2:0] state;
output [21:0] out_2_trans,out_2_port;
//wire  reg
reg [21:0] out_2_trans,out_2_port;
reg [21:0] temp_w [7:0];
reg [21:0] temp_r [7:0];
wire [21:0] add,sub;
wire [2:0] state_fit;
//assign
assign state_fit=state-3'b011;
assign add=MUXA+MUXB;
assign sub=MUXA-MUXB;
 
//parameter
parameter n0=3'b000;
parameter n1=3'b001;
parameter n2=3'b010;
parameter n3=3'b011;
parameter n4=3'b100;
parameter n5=3'b101;
parameter n6=3'b110;
parameter n7=3'b111;

always@(*)begin
	if(mode)begin
		out_2_trans=(state_fit==3'b000)?temp_w[0]:
						 (state_fit==3'b001)?temp_w[1]:
						 (state_fit==3'b010)?temp_w[2]:
						 (state_fit==3'b011)?temp_w[3]:
						 (state_fit==3'b100)?temp_r[4]:
						 (state_fit==3'b101)?temp_r[5]:
						 (state_fit==3'b110)?temp_r[6]:
						 temp_r[7];
		out_2_port=(state_fit==3'b100)?temp_w[3]:
						(state_fit==3'b101)?temp_w[2]:
						(state_fit==3'b110)?temp_w[1]:
						(state_fit==3'b111)?temp_w[0]:
						(state_fit==3'b000)?temp_r[7]:
						(state_fit==3'b001)?temp_r[6]:
						(state_fit==3'b010)?temp_r[5]:
						temp_r[4];
	end
	else begin
		out_2_trans=(state_fit==3'b000)?temp_w[0]:
						 (state_fit==3'b001)?temp_r[1]:
						 (state_fit==3'b010)?temp_r[2]:
						 (state_fit==3'b011)?temp_r[3]:
						 (state_fit==3'b100)?temp_r[4]:
						 (state_fit==3'b101)?temp_r[5]:
						 (state_fit==3'b110)?temp_r[6]:
						 temp_r[7];
		out_2_port=(state_fit==3'b100)?temp_w[0]:
						(state_fit==3'b101)?temp_r[1]:
						(state_fit==3'b110)?temp_r[2]:
						(state_fit==3'b111)?temp_r[3]:
						(state_fit==3'b000)?temp_r[4]:
						(state_fit==3'b001)?temp_r[5]:
						(state_fit==3'b010)?temp_r[6]:
						temp_r[7];
	end
end
always@(*)begin
	temp_w[0]=temp_r[0];
	temp_w[1]=temp_r[1];
	temp_w[2]=temp_r[2];
	temp_w[3]=temp_r[3];
	temp_w[4]=temp_r[4];
	temp_w[5]=temp_r[5];
	temp_w[6]=temp_r[6];
	temp_w[7]=temp_r[7];
	if(mode)begin
		case(state_fit)
			n0:begin
				temp_w[0]=add;
				temp_w[7]=sub;
			end
			n1:begin
				temp_w[1]=add;
				temp_w[6]=sub;
			end
			n2:begin
				temp_w[2]=add;
				temp_w[5]=sub;
			end
			n3:begin
				temp_w[3]=add;
				temp_w[4]=sub;
			end
			n4:begin
				temp_w[3]=add;
				temp_w[4]=sub;
			end
			n5:begin
				temp_w[2]=add;
				temp_w[5]=sub;
			end
			n6:begin
				temp_w[1]=add;
				temp_w[6]=sub;
			end
			n7:begin
				temp_w[0]=add;
				temp_w[7]=sub;
			end
		endcase
	end
	else begin
		case(state_fit)
			n0:begin
				temp_w[0]=MUXA;
				temp_w[1]=MUXB;
			end
			n1:begin
				temp_w[2]=MUXA;
				temp_w[3]=MUXB;
			end
			n2:begin
				temp_w[4]=MUXA;
				temp_w[5]=MUXB;
			end
			n3:begin
				temp_w[6]=MUXA;
				temp_w[7]=MUXB;
			end
			n4:begin
				temp_w[0]=MUXA;
				temp_w[1]=MUXB;
			end
			n5:begin
				temp_w[2]=MUXA;
				temp_w[3]=MUXB;
			end
			n6:begin
				temp_w[4]=MUXA;
				temp_w[5]=MUXB;
			end
			n7:begin
				temp_w[6]=MUXA;
				temp_w[7]=MUXB;
			end
		endcase
	end
end
always@(posedge clk or negedge rst)begin
	if(!rst)begin
		temp_r[0]<=22'b0000000000000000000000;
		temp_r[1]<=22'b0000000000000000000000;
		temp_r[2]<=22'b0000000000000000000000;
		temp_r[3]<=22'b0000000000000000000000;
		temp_r[4]<=22'b0000000000000000000000;
		temp_r[5]<=22'b0000000000000000000000;
		temp_r[6]<=22'b0000000000000000000000;
		temp_r[7]<=22'b0000000000000000000000;
	end
	else begin
		temp_r[0]<=temp_w[0];
		temp_r[1]<=temp_w[1];
		temp_r[2]<=temp_w[2];
		temp_r[3]<=temp_w[3];
		temp_r[4]<=temp_w[4];
		temp_r[5]<=temp_w[5];
		temp_r[6]<=temp_w[6];
		temp_r[7]<=temp_w[7];
	end
end
endmodule

module dru(
	datain,
	datain_trans,
	rst,
	clk,
	state,
	add,
	sub,
	MUXC,
	MUXD
	//state
);
//port
input [21:0] datain,datain_trans;
input clk,rst;
input [2:0] state;
output [22:0] add,sub;
output [22:0] MUXC,MUXD;
//output [1:0] state;
//wire reg
reg [21:0] datain_r,datain_trans_r;
reg [22:0] add_w,sub_w,add_r,sub_r;
reg [22:0] MUXC_w,MUXD_w,MUXC_r,MUXD_r;
reg [21:0] lifo_w [3:0];
reg [21:0] lifo_r [3:0];
//reg [1:0]state_r,state_w;
wire [2:0] state_fit;
wire [21:0] MUXA,MUXB;
wire [22:0] lifo_out_sign_ext, MUXB_ext;

//assign
assign state_fit=state-1;
assign MUXA=state_fit[2]?datain_trans_r:datain_r;
assign MUXB=state_fit[2]?datain_r:datain_trans_r;
assign lifo_out_sign_ext={lifo_r[3][21],lifo_r[3]};
assign MUXB_ext={MUXB[21],MUXB};
assign add=add_r;
assign sub=sub_r;
assign MUXC=MUXC_r;
assign MUXD=MUXD_r;
//assign state=state_r;

always@(*)begin
	//state_w=state_r+2'b01;
	case(state_fit[1:0])
		2'b00: begin
			lifo_w[0]=MUXA;
			lifo_w[1]=lifo_r[0];
			lifo_w[2]=lifo_r[1];
			lifo_w[3]=lifo_r[2];
		end
		2'b01: begin
			lifo_w[0]=lifo_r[0];
			lifo_w[1]=MUXA;
			lifo_w[2]=lifo_r[1];
			lifo_w[3]=lifo_r[2];
		end
		2'b10: begin
			lifo_w[0]=lifo_r[0];
			lifo_w[1]=lifo_r[1];
			lifo_w[2]=MUXA;
			lifo_w[3]=lifo_r[2];
		end
		2'b11: begin
			lifo_w[0]=lifo_r[0];
			lifo_w[1]=lifo_r[1];
			lifo_w[2]=lifo_r[2];
			lifo_w[3]=MUXA;
		end
	endcase
	MUXC_w=state_fit[0]? {{lifo_r[3][21]},lifo_r[3]}:{{MUXB[21]},MUXB};
	MUXD_w=state_fit[0]? {{MUXB[21]},MUXB}:{{lifo_r[3][21]},lifo_r[3]};
	add_w=lifo_out_sign_ext+MUXB_ext;
	sub_w=lifo_out_sign_ext-MUXB_ext;
end
always@(posedge clk or negedge rst)begin
	if(!rst)begin
		//state_r<=1'b0;
		lifo_r[0]<=22'b0000000000000000000000;
		lifo_r[1]<=22'b0000000000000000000000;
		lifo_r[2]<=22'b0000000000000000000000;
		lifo_r[3]<=22'b0000000000000000000000;
		add_r<=23'b00000000000000000000000;
		sub_r<=23'b00000000000000000000000;
		MUXC_r<=23'b00000000000000000000000;
		MUXD_r<=23'b00000000000000000000000;
		datain_r<=22'b0000000000000000000000;
		datain_trans_r<=22'b0000000000000000000000;
	end
	else begin
		//state_r<=state_w;
		lifo_r[0]<=lifo_w[0];
		lifo_r[1]<=lifo_w[1];
		lifo_r[2]<=lifo_w[2];
		lifo_r[3]<=lifo_w[3];
		add_r<=add_w;
		sub_r<=sub_w;
		MUXC_r<=MUXC_w;
		MUXD_r<=MUXD_w;
		datain_r<=datain;
		datain_trans_r<=datain_trans;
	end
end
endmodule

module acf(
	MUXC_in,
	add_in,
	clk,
	rst,
	mode, //0->dct 1->idct
	state,
	dataout
	//state
);
input [22:0] MUXC_in,add_in;
input clk,rst,mode;
input [2:0] state;
//output [2:0] state;
output [21:0] dataout;
wire [23:0] a,c,f;

acf_mult mymult(
	.rst(rst),
	.clk(clk),
	.mode(mode),
	.add_in(add_in),
	.MUXC_in(MUXC_in),
	.multa(a),
	.multc(c),
	.multf(f)
);

acf_acc myacc(
	.axdata(a),
	.cxdata(c),
	.fxdata(f),
	.clk(clk),
	.rst(rst),
	.mode(mode), //0->dct 1->idct
	.state(state),
	.dataout(dataout)
);
endmodule


module acf_acc(
	axdata,
	cxdata,
	fxdata,
	clk,
	rst,
	mode, //0->dct 1->idct
	state,
	dataout
);
//port
input [23:0] axdata,cxdata,fxdata;
input clk,rst,mode;
input[2:0] state;
output [21:0] dataout;
//reg
wire [2:0] state_fit;
reg [21:0] datastore_w [3:0];
reg [21:0] datastore_r [3:0];
//reg [2:0] state_w,state_r;
reg [23:0] acc0_w,acc0_r,acc1_w,acc1_r, acc2_w,acc2_r, acc3_w,acc3_r;
reg [23:0] acc0_out_temp,acc1_out_temp,acc2_out_temp,acc3_out_temp;

assign state_fit=state-3'b011;
assign dataout=datastore_r[state_fit[1:0]];


always@(*)begin
	//state_w=state_r+3'b001;
	datastore_w[0]=datastore_r[0];
	datastore_w[1]=datastore_r[1];
	datastore_w[2]=datastore_r[2];
	datastore_w[3]=datastore_r[3];
	acc0_out_temp=mode?(acc0_r+axdata):(acc0_r+axdata);
	acc1_out_temp=mode?(acc1_r+axdata):(acc1_r+cxdata);
	acc2_out_temp=mode?(acc2_r+axdata):(acc2_r+axdata);
	acc3_out_temp=mode?(acc3_r+axdata):(acc3_r+fxdata);
	if (mode) begin
		case(state_fit)
			3'b000:begin
				acc0_w=acc0_r+axdata;
				acc1_w=acc1_r-axdata;
				acc2_w=acc2_r-axdata;
				acc3_w=acc3_r+axdata;
			end
			3'b001:begin
				acc0_w=acc0_r+cxdata;
				acc1_w=acc1_r+fxdata;
				acc2_w=acc2_r-fxdata;
				acc3_w=acc3_r-cxdata;
			end
			3'b010:begin
				acc0_w=acc0_r+fxdata;
				acc1_w=acc1_r-cxdata;
				acc2_w=acc2_r+cxdata;
				acc3_w=acc3_r-fxdata;
			end
			3'b011:begin
				acc0_w=24'h00;
				acc1_w=24'h00;
				acc2_w=24'h00;
				acc3_w=24'h00;
				datastore_w[0]=(acc0_out_temp>>>2)+acc0_out_temp[1];
				datastore_w[1]=(acc1_out_temp>>>2)+acc1_out_temp[1];
				datastore_w[2]=(acc2_out_temp>>>2)+acc2_out_temp[1];
				datastore_w[3]=(acc3_out_temp>>>2)+acc3_out_temp[1];
			end
			3'b100:begin
				acc0_w=acc0_r+axdata;
				acc1_w=acc1_r-axdata;
				acc2_w=acc2_r-axdata;
				acc3_w=acc3_r+axdata;
			end
			3'b101:begin
				acc0_w=acc0_r+cxdata;
				acc1_w=acc1_r+fxdata;
				acc2_w=acc2_r-fxdata;
				acc3_w=acc3_r-cxdata;
			end
			3'b110:begin
				acc0_w=acc0_r+fxdata;
				acc1_w=acc1_r-cxdata;
				acc2_w=acc2_r+cxdata;
				acc3_w=acc3_r-fxdata;
			end
			3'b111:begin
				acc0_w=24'h00;
				acc1_w=24'h00;
				acc2_w=24'h00;
				acc3_w=24'h00;
				datastore_w[0]=(acc0_out_temp>>>2)+acc0_out_temp[1];
				datastore_w[1]=(acc1_out_temp>>>2)+acc1_out_temp[1];
				datastore_w[2]=(acc2_out_temp>>>2)+acc2_out_temp[1];
				datastore_w[3]=(acc3_out_temp>>>2)+acc3_out_temp[1];
			end
		endcase
	end
	else begin
		case(state_fit)
			3'b000:begin
				acc0_w=acc0_r+axdata;
				acc1_w=acc1_r-cxdata;
				acc2_w=acc2_r+axdata;
				acc3_w=acc3_r-fxdata;
			end
			3'b001:begin
				acc0_w=acc0_r+axdata;
				acc1_w=acc1_r-fxdata;
				acc2_w=acc2_r-axdata;
				acc3_w=acc3_r+cxdata;
			end
			3'b010:begin
				acc0_w=acc0_r+axdata;
				acc1_w=acc1_r+fxdata;
				acc2_w=acc2_r-axdata;
				acc3_w=acc3_r-cxdata;
			end
			3'b011:begin
				acc0_w=24'h00;
				acc1_w=24'h00;
				acc2_w=24'h00;
				acc3_w=24'h00;
				datastore_w[0]=(acc0_out_temp>>>2)+acc0_out_temp[1];
				datastore_w[1]=(acc1_out_temp>>>2)+acc1_out_temp[1];
				datastore_w[2]=(acc2_out_temp>>>2)+acc2_out_temp[1];
				datastore_w[3]=(acc3_out_temp>>>2)+acc3_out_temp[1];
			end
			3'b100:begin
				acc0_w=acc0_r+axdata;
				acc1_w=acc1_r-cxdata;
				acc2_w=acc2_r+axdata;
				acc3_w=acc3_r-fxdata;
			end
			3'b101:begin
				acc0_w=acc0_r+axdata;
				acc1_w=acc1_r-fxdata;
				acc2_w=acc2_r-axdata;
				acc3_w=acc3_r+cxdata;
			end
			3'b110:begin
				acc0_w=acc0_r+axdata;
				acc1_w=acc1_r+fxdata;
				acc2_w=acc2_r-axdata;
				acc3_w=acc3_r-cxdata;
			end
			3'b111:begin
				acc0_w=24'h00;
				acc1_w=24'h00;
				acc2_w=24'h00;
				acc3_w=24'h00;
				datastore_w[0]=(acc0_out_temp>>>2)+acc0_out_temp[1];
				datastore_w[1]=(acc1_out_temp>>>2)+acc1_out_temp[1];
				datastore_w[2]=(acc2_out_temp>>>2)+acc2_out_temp[1];
				datastore_w[3]=(acc3_out_temp>>>2)+acc3_out_temp[1];
			end
		endcase
	end
end
always@(posedge clk or negedge rst)begin
	if(!rst)begin
		//state_r<=3'b000;
		datastore_r[0]<=22'h00;
		datastore_r[1]<=22'h00;
		datastore_r[2]<=22'h00;
		datastore_r[3]<=22'h00;
		acc0_r<=24'h00;
		acc1_r<=24'h00;
		acc2_r<=24'h00;
		acc3_r<=24'h00;
	end
	else begin
		acc0_r<=acc0_w;
		acc1_r<=acc1_w;
		acc2_r<=acc2_w;
		acc3_r<=acc3_w;
		datastore_r[0]<=datastore_w[0];
		datastore_r[1]<=datastore_w[1];
		datastore_r[2]<=datastore_w[2];
		datastore_r[3]<=datastore_w[3];
	end
end
endmodule


module acf_mult(
	rst,
	clk,
	mode,
	add_in,
	MUXC_in,
	multa,
	multc,
	multf
);
input rst,clk,mode;
input [22:0] add_in,MUXC_in;
output [23:0] multa,multc,multf;
//
wire [22:0] datain;
wire [23:0] temp1,temp2,temp3,temp4,temp5,temp7,temp8,temp9,temp10,temp14;
wire [23:0] multa_w,multc_w,multf_w;
reg [23:0] multa,multc,multf;

//
assign datain=mode?MUXC_in:add_in;
assign temp1={{2{datain[22]}},datain[22:1]};
assign temp2={{3{datain[22]}},datain[22:2]};
assign temp3={{4{datain[22]}},datain[22:3]};
assign temp4={{5{datain[22]}},datain[22:4]};
assign temp5={{6{datain[22]}},datain[22:5]};
assign temp7={{8{datain[22]}},datain[22:7]};
assign temp8={{9{datain[22]}},datain[22:8]};
assign temp9={{10{datain[22]}},datain[22:9]};
assign temp10={{11{datain[22]}},datain[22:10]};
assign temp14={{15{datain[22]}},datain[22:14]};
assign multa_w=temp2+temp4+temp5+temp7+temp9;
assign multc_w=temp1-temp5-temp7+temp10;
assign multf_w=temp3+temp4+temp8-temp14;

always@(posedge clk or negedge rst)begin
	if(!rst)begin
		multa<=24'h00;
		multc<=24'h00;
		multf<=24'h00;
	end
	else begin
		multa<=multa_w;
		multc<=multc_w;
		multf<=multf_w;
	end
end

endmodule

module bdeg(
	MUXD_in,
	sub_in,
	clk,
	rst,
	mode, //0->dct 1->idct
	state,
	dataout
	//state
);
input [22:0] MUXD_in,sub_in;
input clk,rst,mode;
input [2:0] state;
//output [2:0] state;
output [21:0] dataout;

wire [23:0] b,d,e,g;

bdeg_mult mymult(
	.MUXD_in(MUXD_in),
	.sub_in(sub_in),
	.clk(clk),
	.rst(rst),
	.mode(mode),
	.multb(b),
	.multd(d),
	.multe(e),
	.multg(g)
);

bdeg_acc myacc(
	.bxdata(b),
	.dxdata(d),
	.exdata(e),
	.gxdata(g),
	.clk(clk),
	.rst(rst),
	.mode(mode), //0->dct 1->idct
	.state(state),
	.dataout(dataout)
);
endmodule


module bdeg_acc(
	bxdata,
	dxdata,
	exdata,
	gxdata,
	clk,
	rst,
	mode, //0->dct 1->idct
	state,
	dataout
);
//port
input [23:0] bxdata,dxdata,exdata,gxdata;
input clk,rst,mode;
output [21:0] dataout;
input [2:0] state;
//reg
wire [2:0] state_fit;
reg [21:0] datastore_w [3:0];
reg [21:0] datastore_r [3:0];
//reg [2:0] state_w,state_r;
reg [23:0] acc0_w,acc0_r,acc1_w,acc1_r, acc2_w,acc2_r, acc3_w,acc3_r;
reg [23:0] acc0_out_temp,acc1_out_temp,acc2_out_temp,acc3_out_temp;

assign state_fit=state-3'b011;
assign dataout=datastore_r[state_fit[1:0]];

always@(*)begin
	//state_w=state_r+3'b001;
	datastore_w[0]=datastore_r[0];
	datastore_w[1]=datastore_r[1];
	datastore_w[2]=datastore_r[2];
	datastore_w[3]=datastore_r[3];
	acc0_out_temp=mode?(acc0_r+gxdata):(acc0_r+bxdata);
	acc1_out_temp=mode?(acc1_r-exdata):(acc1_r+dxdata);
	acc2_out_temp=mode?(acc2_r+dxdata):(acc2_r+exdata);
	acc3_out_temp=mode?(acc3_r-bxdata):(acc3_r+gxdata);
	if (mode) begin
		case(state_fit)
			3'b000:begin
				acc0_w=acc0_r+dxdata;
				acc1_w=acc1_r-gxdata;
				acc2_w=acc2_r-bxdata;
				acc3_w=acc3_r-exdata;
			end
			3'b001:begin
				acc0_w=acc0_r+exdata;
				acc1_w=acc1_r-bxdata;
				acc2_w=acc2_r+gxdata;
				acc3_w=acc3_r+dxdata;
			end
			3'b010:begin
				acc0_w=acc0_r+bxdata;
				acc1_w=acc1_r+dxdata;
				acc2_w=acc2_r+exdata;
				acc3_w=acc3_r+gxdata;
			end
			3'b011:begin
				acc0_w=24'h00;
				acc1_w=24'h00;
				acc2_w=24'h00;
				acc3_w=24'h00;
				datastore_w[0]=(acc0_out_temp>>>2)+acc0_out_temp[1];
				datastore_w[1]=(acc1_out_temp>>>2)+acc1_out_temp[1];
				datastore_w[2]=(acc2_out_temp>>>2)+acc2_out_temp[1];
				datastore_w[3]=(acc3_out_temp>>>2)+acc3_out_temp[1];
			end
			3'b100:begin
				acc0_w=acc0_r+dxdata;
				acc1_w=acc1_r-gxdata;
				acc2_w=acc2_r-bxdata;
				acc3_w=acc3_r-exdata;
			end
			3'b101:begin
				acc0_w=acc0_r+exdata;
				acc1_w=acc1_r-bxdata;
				acc2_w=acc2_r+gxdata;
				acc3_w=acc3_r+dxdata;
			end
			3'b110:begin
				acc0_w=acc0_r+bxdata;
				acc1_w=acc1_r+dxdata;
				acc2_w=acc2_r+exdata;
				acc3_w=acc3_r+gxdata;
			end
			3'b111:begin
				acc0_w=24'h00;
				acc1_w=24'h00;
				acc2_w=24'h00;
				acc3_w=24'h00;
				datastore_w[0]=(acc0_out_temp>>>2)+acc0_out_temp[1];
				datastore_w[1]=(acc1_out_temp>>>2)+acc1_out_temp[1];
				datastore_w[2]=(acc2_out_temp>>>2)+acc2_out_temp[1];
				datastore_w[3]=(acc3_out_temp>>>2)+acc3_out_temp[1];
			end
		endcase
	end
	else begin
		case(state_fit)
			3'b000:begin
				acc0_w=acc0_r+gxdata;
				acc1_w=acc1_r-exdata;
				acc2_w=acc2_r+dxdata;
				acc3_w=acc3_r-bxdata;
			end
			3'b001:begin
				acc0_w=acc0_r+exdata;
				acc1_w=acc1_r-bxdata;
				acc2_w=acc2_r+gxdata;
				acc3_w=acc3_r+dxdata;
			end
			3'b010:begin
				acc0_w=acc0_r+dxdata;
				acc1_w=acc1_r-gxdata;
				acc2_w=acc2_r-bxdata;
				acc3_w=acc3_r-exdata;
			end
			3'b011:begin
				acc0_w=24'h00;
				acc1_w=24'h00;
				acc2_w=24'h00;
				acc3_w=24'h00;
				datastore_w[0]=(acc0_out_temp>>>2)+acc0_out_temp[1];
				datastore_w[1]=(acc1_out_temp>>>2)+acc1_out_temp[1];
				datastore_w[2]=(acc2_out_temp>>>2)+acc2_out_temp[1];
				datastore_w[3]=(acc3_out_temp>>>2)+acc3_out_temp[1];
			end
			3'b100:begin
				acc0_w=acc0_r+gxdata;
				acc1_w=acc1_r-exdata;
				acc2_w=acc2_r+dxdata;
				acc3_w=acc3_r-bxdata;
			end
			3'b101:begin
				acc0_w=acc0_r+exdata;
				acc1_w=acc1_r-bxdata;
				acc2_w=acc2_r+gxdata;
				acc3_w=acc3_r+dxdata;
			end
			3'b110:begin
				acc0_w=acc0_r+dxdata;
				acc1_w=acc1_r-gxdata;
				acc2_w=acc2_r-bxdata;
				acc3_w=acc3_r-exdata;
			end
			3'b111:begin
				acc0_w=24'h00;
				acc1_w=24'h00;
				acc2_w=24'h00;
				acc3_w=24'h00;
				datastore_w[0]=(acc0_out_temp>>>2)+acc0_out_temp[1];
				datastore_w[1]=(acc1_out_temp>>>2)+acc1_out_temp[1];
				datastore_w[2]=(acc2_out_temp>>>2)+acc2_out_temp[1];
				datastore_w[3]=(acc3_out_temp>>>2)+acc3_out_temp[1];
			end
		endcase
	end
end
always@(posedge clk or negedge rst)begin
	if(!rst)begin
		//state_r<=3'b000;
		datastore_r[0]<=22'h00;
		datastore_r[1]<=22'h00;
		datastore_r[2]<=22'h00;
		datastore_r[3]<=22'h00;
		acc0_r<=24'h00;
		acc1_r<=24'h00;
		acc2_r<=24'h00;
		acc3_r<=24'h00;
	end
	else begin
		acc0_r<=acc0_w;
		acc1_r<=acc1_w;
		acc2_r<=acc2_w;
		acc3_r<=acc3_w;
		datastore_r[0]<=datastore_w[0];
		datastore_r[1]<=datastore_w[1];
		datastore_r[2]<=datastore_w[2];
		datastore_r[3]<=datastore_w[3];
	end
end
endmodule


module bdeg_mult(
	MUXD_in,
	sub_in,
	clk,
	rst,
	mode,
	multb,
	multd,
	multe,
	multg
);
input clk,rst,mode;
input [22:0] MUXD_in,sub_in;
output [23:0] multb,multd,multe,multg;
//
wire [22:0] datain;
wire [23:0] temp1,temp2,temp3,temp4,temp5,temp7,temp8,temp9,temp11,temp12,temp13;
wire [23:0] multb_w,multd_w,multe_w,multg_w;
reg [23:0] multb,multd,multe,multg;

//
assign datain=mode?MUXD_in:sub_in;
assign temp1={{2{datain[22]}},datain[22:1]};
assign temp2={{3{datain[22]}},datain[22:2]};
assign temp3={{4{datain[22]}},datain[22:3]};
assign temp4={{5{datain[22]}},datain[22:4]};
assign temp5={{6{datain[22]}},datain[22:5]};
assign temp7={{8{datain[22]}},datain[22:7]};
assign temp8={{9{datain[22]}},datain[22:8]};
assign temp9={{10{datain[22]}},datain[22:9]};
assign temp11={{12{datain[22]}},datain[22:11]};
assign temp12={{13{datain[22]}},datain[22:12]};
assign temp13={{14{datain[22]}},datain[22:13]};
assign multb_w=temp1-temp7-temp9+temp13;
assign multd_w=temp2+temp3+temp5+temp7+temp9-temp12;
assign multe_w=temp2+temp5-temp8+temp11;
assign multg_w=temp4+temp5+temp8-temp13;

always@(posedge clk or negedge rst)begin
	if(!rst)begin
		multb<=24'h00;
		multd<=24'h00;
		multe<=24'h00;
		multg<=24'h00;
	end
	else begin
		multb<=multb_w;
		multd<=multd_w;
		multe<=multe_w;
		multg<=multg_w;
	end
end
endmodule
