//`include "fir-dev/bram/bram11.v"
//`include "fir-dev/rtl/fir.v"
// `include "fir-ans/fir/out_gold.dat"
// `include "fir-ans/fir/samples_triangular_wave.dat"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2023 10:38:55 AM
// Design Name: 
// Module Name: fir_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fir_tb
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11,
    parameter Data_Num    = 600
)();
    wire                        awready;
    wire                        wready;
    reg                         awvalid;
    reg   [(pADDR_WIDTH-1): 0]  awaddr;
    reg                         wvalid;
    reg signed [(pDATA_WIDTH-1) : 0] wdata;
    wire                        arready;
    reg                         rready;
    reg                         arvalid;
    reg         [(pADDR_WIDTH-1): 0] araddr;
    wire                        rvalid;
    wire signed [(pDATA_WIDTH-1): 0] rdata;
    reg                         ss_tvalid;
    reg signed [(pDATA_WIDTH-1) : 0] ss_tdata;
    reg                         ss_tlast;
    wire                        ss_tready;
    reg                         sm_tready;
    wire                        sm_tvalid;
    wire signed [(pDATA_WIDTH-1) : 0] sm_tdata;
    wire                        sm_tlast;
    reg                         axis_clk;
    reg                         axis_rst_n;

// ram for tap
    //
    wire [3:0]               tap_WE;
    wire                     tap_EN;
    //
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    //
    wire [(pDATA_WIDTH-1):0] tap_Do;

// ram for data RAM
    //
    wire [3:0]               data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    //
    wire [(pDATA_WIDTH-1):0] data_Do;

//  parameters
    reg error_coef;    



    fir fir_DUT(
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),

        // ram for tap
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),

        // ram for data
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),

        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)

        );
    
    // RAM for tap
    bram11 tap_RAM (
        .CLK(axis_clk),
        .WE(tap_WE),
        .EN(tap_EN),
        .Di(tap_Di),
        .A(tap_A),
        .Do(tap_Do)
    );

    // RAM for data: choose bram11 or bram12
    bram11 data_RAM(
        .CLK(axis_clk),
        .WE(data_WE),
        .EN(data_EN),
        .Di(data_Di),
        .A(data_A),
        .Do(data_Do)
    );


    reg signed [(pDATA_WIDTH-1):0] Din_list[0:(Data_Num-1)];
    reg signed [(pDATA_WIDTH-1):0] golden_list[0:(Data_Num-1)];

    initial begin
        $dumpfile("fir.vcd");
        $dumpvars();
    end


    initial begin
        axis_clk = 0;
        forever begin
            #5 axis_clk = (~axis_clk);
        end
    end


    initial begin
        axis_rst_n = 0;
        @(posedge axis_clk); @(posedge axis_clk); 
        axis_rst_n = 1;
    end

/*//1
    reg data_WE_reg;
    assign data_WE=data_WE_reg;
    reg data_EN_reg;
    assign data_EN=data_EN_reg;
    reg data_Di_reg;
    assign data_Di=data_Di_reg;
    reg data_A_reg;
    assign data_A=data_A_reg;
    // 配置BRAM 的参数
    integer aa;
    initial begin
    // 配置 data_BRAM（以示例为准）
    data_WE_reg <= 4'b0; // 设置写使能为0
    data_EN_reg <= 1'b1; // 设置使能为1
    for (aa=0 ; aa<11 ; aa=aa+1)
    begin
        data_A_reg <= aa;  // 设置BRAM 地址
    end
    for (integer i = 0; i < 11; i = i + 1) begin
        write_to_BRAM(0, i);
    end
    end

//1*/
/*//2
    reg data_WE_reg;
    assign data_WE=data_WE_reg;
    reg data_EN_reg;
    assign data_EN=data_EN_reg;
    reg data_Di_reg;
    assign data_Di=data_Di_reg;
    reg data_A_reg;
    assign data_A=data_A_reg;
    initial begin
    data_WE_reg = 4'b0; // 设置写使能为0
    data_EN_reg = 1'b1; // 设置使能为1

    // 初始化数据
        for (integer i = 0; i < Data_Num; i = i + 1) begin
            data_A_reg = i; // 设置BRAM地址
            data_Di_reg = 0; // 设置初始数据值
            @(posedge axis_clk); // 等待一个时钟周期
            data_WE_reg = 4'b1; // 启用写操作
            @(posedge axis_clk); // 等待一个时钟周期
            data_WE_reg = 4'b0; // 禁用写操作
        end
    end
//2*/
/*//3
    // 在初始化的时候禁用写入和读取操作
    integer empty_cycles = 0;
    reg data_WE_reg;
    assign data_WE=data_WE_reg;
    reg data_EN_reg;
    assign data_EN=data_EN_reg;

    initial begin
        data_WE_reg = 4'b0; // 禁用写入操作
        data_EN_reg = 1'b0; // 禁用读取操作
        // ...
        // 在此处进行其他初始化操作
        // ...

        // 在初始化阶段，或任何你需要的时候，启动空转
        while (empty_cycles < 11) begin
            @(posedge axis_clk); // 等待一个时钟周期
            empty_cycles = empty_cycles + 1;
        end

        // 此时 BRAM 将会连续空转 11 次
    end
3*/

    reg [31:0]  data_length;
    integer Din, golden, input_data, golden_data, m;
    initial begin
        data_length = 0;
        Din = $fopen("./samples_triangular_wave.dat","r");
        golden = $fopen("./out_gold.dat","r");
        for(m=0;m<Data_Num;m=m+1) begin
            input_data = $fscanf(Din,"%d", Din_list[m]);
            $display("%d.",Din_list[m]);
            golden_data = $fscanf(golden,"%d", golden_list[m]);
            data_length = data_length + 1;
        end
    end

    integer i;
    initial begin
        $display("------------Start simulation-----------");
        ss_tvalid = 0;
        $display("----Start the data input(AXI-Stream)----");
        for(i=0;i<(data_length-1);i=i+1) begin
            ss_tlast = 0; ss(Din_list[i]);
        end
        config_read_check(12'h00, 32'h00, 32'h0000_000f); // check idle = 0 (0x00 [bit 0~3]=4'b0000)
        ss_tlast = 1; ss(Din_list[(Data_Num-1)]);
        @(posedge axis_clk) begin
            ss_tlast =0; ss_tvalid=0;
        end
        $display("------End the data input(AXI-Stream)------");
    end

    integer k;
    reg error;
    reg status_error;
    initial begin
        error = 0; status_error = 0;
        sm_tready = 1;
        wait (sm_tvalid);
        for(k=0;k < data_length;k=k+1) begin
            sm(golden_list[k],k);
        end
        config_read_check(12'h00, 32'h02, 32'h0000_0002); // check ap_done = 1 (0x00 [bit 1])
        config_read_check(12'h00, 32'h04, 32'h0000_0004); // check ap_idle = 1 (0x00 [bit 2])
        if (error == 0 & error_coef == 0) begin
            $display("---------------------------------------------");
            $display("-----------Congratulations! Pass-------------");
        end
        else begin
            $display("--------Simulation Failed---------");
        end
        $finish;
    end

    // Prevent hang
    integer timeout = (1000000);
    initial begin
        while(timeout > 0) begin
            @(posedge axis_clk);
            timeout = timeout - 1;
        end
        $display($time, "Simualtion Hang ....");
        $finish;
    end


    reg signed [31:0] coef[0:10]; // fill in coef 
    initial begin
        coef[0]  =  32'd0;
        coef[1]  = -32'd10;
        coef[2]  = -32'd9;
        coef[3]  =  32'd23;
        coef[4]  =  32'd56;
        coef[5]  =  32'd63;
        coef[6]  =  32'd56;
        coef[7]  =  32'd23;
        coef[8]  = -32'd9;
        coef[9]  = -32'd10;
        coef[10] =  32'd0;
    end

    // reg error_coef;
    initial begin
        error_coef = 0;
        $display("----Start the coefficient input(AXI-lite)----");
        config_write(12'h10, data_length);
        for(k=0; k< Tape_Num; k=k+1) begin
            config_write(12'h20+4*k, coef[k]);
        end
        awvalid <= 0; wvalid <= 0;
        // read-back and check
        $display(" Check Coefficient ...");
        for(k=0; k < Tape_Num; k=k+1) begin
            config_read_check(12'h20+4*k, coef[k], 32'hffffffff);
        end
        arvalid <= 0;
        $display(" Tape programming done ...");
        $display(" Start FIR");
        @(posedge axis_clk) config_write(12'h00, 32'h0000_0001);    // ap_start = 1
        @(posedge axis_clk) config_write(12'h00, 32'h0000_0000);
        $display("----End the coefficient input(AXI-lite)----");
        //@(posedge wready)config_write(12'h00, 32'h0000_0000); 
    end

    task config_write;
        input [11:0]    addr;
        input [31:0]    data;
        begin
            awvalid <= 0; wvalid <= 0;
            @(posedge axis_clk);
            awvalid <= 1; awaddr <= addr;
            wvalid  <= 1; wdata <= data;
            @(posedge axis_clk);
            while (!wready) @(posedge axis_clk);
        end
    endtask

    task config_read_check;
        input [11:0]        addr;
        input signed [31:0] exp_data;
        input [31:0]        mask;
        begin
            arvalid <= 0;
            @(posedge axis_clk);
            arvalid <= 1; araddr <= addr;
            rready <= 1;
            @(posedge axis_clk);
            while (!rvalid) @(posedge axis_clk);
            if( (rdata & mask) != (exp_data & mask)) begin
                $display("ERROR: exp = %d, rdata = %d", exp_data, rdata);
                error_coef <= 1;
            end else begin
                $display("OK: exp = %d, rdata = %d", exp_data, rdata);
            end
        end
    endtask



    task ss;
        input  signed [31:0] in1;
        begin
            ss_tvalid <= 1;
            ss_tdata  <= in1;
            @(posedge axis_clk);
            while (!ss_tready) begin
                @(posedge axis_clk);
            end
        end
    endtask

    task sm;
        input  signed [31:0] in2; // golden data
        input         [31:0] pcnt; // pattern count
        begin
            sm_tready <= 1;
            @(posedge axis_clk) 
            wait(sm_tvalid);
            while(!sm_tvalid) @(posedge axis_clk);
            if (sm_tdata != in2) begin
                $display("[ERROR] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in2, sm_tdata);
                error <= 1;
            end
            else begin
                $display("[PASS] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in2, sm_tdata);
            end
            @(posedge axis_clk);
        end
    endtask

/*//1
    task write_to_BRAM;
        input [pDATA_WIDTH-1:0] data;
        input [11:0] addr;
        begin
            // 在写之前等待BRAM 准备好
            while (!tap_WE) @(posedge axis_clk);
            // 将数据写入BRAM
            data_Di_reg <= 0;
            data_A_reg <= addr;
            data_WE_reg <= 4'b1;
            @(posedge axis_clk);
            data_WE_reg <= 4'b0;
        end
    endtask
//1*/

endmodule