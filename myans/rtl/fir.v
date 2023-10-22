`include "FIR_Logic.v"
`timescale 1ns / 100ps
module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11,
    parameter IDLE        =  0,
    parameter WAIT        =  0,
    parameter TRAN          =  1,
    parameter Received_Address = 1 ,
    parameter WORK        =  2
)
(
    // write chennel / addr write chennel
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    // R / AR
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    

    // ss : stream slave  /  sm : stream master
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 

    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
//begin
    // parameters //
    //第七版 interger reg
    reg     [2:0]   FIR_STATE ; // IDEL / PP / WORK
    reg next_state_FIR ;
    reg ap_start , ap_idle , ap_done;
    reg [1:0] addr_reg_R;
    reg [3:0] tap_count , data_count ;
    reg AWW_STATE ;
    reg next_state_AWW ;
    reg ARR_STATE ;
    reg next_state_ARR ;
    reg [1:0] addr_reg_W;
    reg [31:0] data_length ;
    reg [1:0] WoR_tap ; // 10 : Write | 01 : Read | 00 : IDLE
    reg [3:0] data_received_count;
    // parameters //
    reg [3:0] data_WE_reg;
    assign data_WE=data_WE_reg ;


    // initial ap signals //
    initial begin
        ap_done = 0;
        ap_start = 0;
    end
    // initial ap signals //

    // ap_idle //
    initial begin
        ap_idle = 1 ;
    end
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            ap_idle <= 1'b1 ;
        end else begin
            if (ap_start) begin
                ap_idle <= 1'b0 ;
            end else if (ap_idle | ap_done & rready & rvalid & arvalid) begin
                ap_idle <= 1'b1 ;
            end else begin
                ap_idle <= ap_idle ;
            end
        end
    end
    // ap_idle //

    // RAM pointer //
    // relocalization TFU
    // reg [3:0] tap_count , data_count ;
    reg data_EN_reg;
    assign data_EN=data_EN_reg ;
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n)begin
            tap_count <= 0 ;
            data_count <= 0 ;
        end else begin
            if (tap_EN) begin
                if (tap_count==4'b1010) begin
                    tap_count <= 4'b0000;
                end else begin
                    tap_count <= tap_count + 1'b1 ;
                end
            end
            if (data_EN) begin
                if (tap_count == 4'd10) begin
                    data_count <= data_count ; 
                    data_EN_reg <= 1'b1 ;         // Latch ? 
                end else if (data_count == 4'b1010) begin
                    data_count <= 4'b0000;
                    data_EN_reg <= 1'b0 ; 
                end else begin
                    data_count <= data_count + 1'b1 ;
                    data_EN_reg <= 1'b0 ; 
                end
            end
        end
    end
    reg [(pDATA_WIDTH-1):0] tap_A_reg;
    assign tap_A=tap_A_reg ;
    reg [(pDATA_WIDTH-1):0] data_A_reg;
    assign data_A=data_A_reg ;
    always @(*) begin
        tap_A_reg = tap_count << 2 ;
        data_A_reg = data_count << 2 ;
    end
    // RAM pointer //
    
/*第一版
    // FIR_FSM //
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            FIR_STATE <= IDLE ;
        end else begin
            FIR_STATE <= next_state_FIR ;
        end
    end

    always @(*) begin
        case (FIR_STATE)
            IDLE: begin
                next_state_FIR = (ap_start)? (WORK):(IDLE);
            end 
            WORK : begin
                next_state_FIR = (ap_done & rready & rvalid &arvalid)? (IDLE):(WORK);
            end
            default: begin 
                next_state_FIR = IDLE ;
                // $display("default nextstate");
            end
        endcase
    end
    // FIR_FSM //
*/

    // FIR_FSM //
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (ap_idle) 
        begin
            FIR_STATE = IDLE;
            //(ap_idle | ap_done & rready & rvalid & arvalid) = 1'b1;
        end
        else 
        begin
            FIR_STATE = WORK;            
        end
        if (ap_start) 
        begin
            FIR_STATE = WORK;    
        end
        if (ap_done & rready & rvalid & arvalid) 
        begin
            @(posedge axis_clk);
                FIR_STATE = IDLE;            
        end        
    end

    // axi lite AW / W FSM //
    // reg AWW_STATE ;
    // integer next_state_AWW ;
    reg awready_reg;
    assign awready=awready_reg ;
    reg wready_reg;
    assign wready=wready_reg ;
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            AWW_STATE <= WAIT ;
        end else begin
            AWW_STATE <= next_state_AWW ;
        end
    end

    always @(*) begin
        if (ap_idle | ap_done & rready & rvalid & arvalid) begin
            case (AWW_STATE)
                WAIT : begin
                    next_state_AWW = (awvalid) ? (Received_Address) : (WAIT);
                    awready_reg = 1'b1 ;
                    wready_reg  = 1'b0 ;
                end
                Received_Address : begin
                    next_state_AWW = (wvalid) ? (WAIT) : (Received_Address);
                    awready_reg = 1'b0 ;
                    wready_reg  = 1'b1 ;
                end  
                default: begin
                    next_state_AWW = WAIT ;
                    awready_reg = 1'b1 ;
                    wready_reg  = 1'b0 ;
                end
            endcase
        end else begin
            next_state_AWW = WAIT ;
        end
    end
    // axi lite AW / W FSM //

    // axi lite AR / R FSM //
    // reg ARR_STATE ;
    // integer next_state_ARR ;
    // address decoder (W)//
    // address decoder (R)//
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            ARR_STATE <= WAIT ;
            addr_reg_R <= 2'd3; // fail
            addr_reg_W <= 2'd3; // fail
        end else begin
            ARR_STATE <= next_state_ARR ;
            if (arvalid & arready) begin
                if (awaddr == 12'h00) begin
                    addr_reg_R <= 2'd0 ;
                end
                else if (awaddr > 12'h0F && awaddr < 12'h15) begin
                    addr_reg_R <= 2'd1;
                end 
                else if (awaddr > 12'h1F && awaddr < 12'h100) begin
                    addr_reg_R <= 2'd2;
                end else begin
                    addr_reg_R <= 2'd3;
                end
            end
            if (awvalid & awready) begin
                if (awaddr == 12'h00) begin // ap_start
                    addr_reg_W <= 2'd0 ;
                end
                else if (awaddr > 12'h0F && awaddr < 12'h15) begin
                    addr_reg_W <= 2'd1;
                end 
                else if (awaddr > 12'h1F && awaddr < 12'h100) begin
                    addr_reg_W <= 2'd2;
                end else begin
                    addr_reg_W <= 2'd3;
                end
            end
        end
    end
    reg arready_reg;
    assign arready=arready_reg ;
    reg rvalid_reg;
    assign rvalid=rvalid_reg ;  
    reg [(pDATA_WIDTH-1):0] rdata_reg;
    assign rdata=rdata_reg ; 
    always @(*) begin
        case (ARR_STATE)
            WAIT :  begin
                next_state_ARR = (arvalid) ? (TRAN) : (WAIT) ;
                arready_reg = 1'b1;
                rvalid_reg = 1'b0;
            end
            TRAN :  begin
                next_state_ARR = (rready) ? (WAIT) : (TRAN) ;
                arready_reg = 1'b0;
                rvalid_reg = 1'b1;
                case (addr_reg_R)
                    2'd0 : rdata_reg = {{29{1'b0}},ap_idle,ap_done,ap_start};
                    2'd1 : rdata_reg = data_length ;
                    2'd2 : rdata_reg = tap_Do ;
                    2'd3 : rdata_reg = {{29{1'b0}},ap_idle,ap_done,ap_start}; // dont care
                    default: rdata_reg = {{29{1'b0}},ap_idle,ap_done,ap_start};
                endcase
            end
            default: begin
                next_state_ARR = WAIT ;
                arready_reg = 1'b1;
                rvalid_reg = 1'b0;
            end
        endcase
    end
    // axi lite AR / R FSM //
    // address decoder (W)//
    // address decoder (R)//
    // reg [1:0] addr_reg_W;
    // reg [1:0] addr_reg_R; // move to the top of this code .

    

    // store data (W)//
    // data_length //
    // reg [31:0] data_length ;
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if(~axis_rst_n) begin
            data_length <= 32'd0 ;
        end
    end
    // tap ram 
    reg [(pDATA_WIDTH-1):0] tap_Di_reg;
    assign tap_Di=tap_Di_reg ; 
    always @(*) begin
        // AXI-W
        if (ap_idle | ap_done & rready & rvalid & arvalid) begin
            if (wready && wvalid) begin
                case (addr_reg_W)
                    2'd0 : begin // 0x00 //ap_start
                        if(wdata[0]==1'd1) begin
                            ap_start = 1 ;
                            $display("----- FIR kernel starts -----");
                        end else begin
                            ap_start = 0 ;
                        end
                    end
                    2'd1 : begin // 0x10-14
                        data_length = wdata ;
                    end
                    2'd2 : begin // 0x20-FF
                        tap_Di_reg = wdata ;
                        // WoR_tap = 1'b1 ; // Write mode
                    end
                    // 2'd3 : begin // dont care

                    // end
                    // default: 
                endcase
            end 
        end else begin // FIR_STATE == WORK
            ap_start = (ap_start&ss_tvalid&ss_tready)? (0):(ap_start) ;
        end
    end
    // store data (W)//

    // always @(posedge axis_clk or negedge axis_rst_n) begin
    //     if (~axis_rst_n) begin

    //     end else begin
    //         if (wready && wvalid) begin
    //             case (addr_reg_W)
    //                 2'd0 : begin // 0x00
    //                     if(wdata[0]==1'd1) begin
    //                         ap_start <= 1 ;
    //                     end else begin
    //                         ap_start <= 0 ;
    //                     end
    //                 end
    //                 2'd1 : begin // 0x10-14
    //                     data_length <= wdata ;
    //                 end
    //                 2'd2 : begin // 0x20-FF
    //                     tap_Di <= wdata ;
    //                     tap_WE <= 4'b1111;
    //                     tap_EN <= 1'b1;
    //                     if (tap_count==4'b1010) begin
    //                         tap_count <= 4'b0000;
    //                     end else begin
    //                         tap_count <= tap_count + 1'b1 ;
    //                     end
    //                 end
    //                 // 2'd3 : begin // dont care

    //                 // end
    //                 // default: 
    //             endcase
    //         end    
    //     end
    // end
    // store data //
    reg [3:0]tap_WE_reg;
    assign tap_WE=tap_WE_reg ;
    reg tap_EN_reg;
    assign tap_EN=tap_EN_reg ;

/*
    //8
    //reg [(pDATA_WIDTH-1):0] data_Do_reg;
    //assign data_Do=data_Do_reg ;
    reg [3:0] data_WE_reg;
    assign data_WE=data_WE_reg ;
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            // 在复位时将状态设置为Idle
            data_received_count <= 0;
        end else begin
            // 在数据传输时更新计数器
            if (ss_tvalid & ss_tready) begin
                data_received_count <= data_received_count + 1;
            end

            // 检查是否已接收了前11笔数据
            if (data_received_count < 4'b1010) begin
                // 继续数据传输，不改变状态
                FIR_STATE = WORK;
            end else begin
                FIR_STATE = WORK;
            end
        end
    end
//8
*/

    // tap_controller //
    // reg [1:0] WoR_tap ; // 10 : Write | 01 : Read | 00 : IDLE
    always @(*) begin
        if (WoR_tap[1]) begin  // Write
            tap_EN_reg = 1'b1;
            tap_WE_reg = 4'b1111 ;
        end 
        else if (WoR_tap[0]) begin      // Read
            tap_EN_reg = 1'b1;
            tap_WE_reg = 4'd0;
        end else begin
            tap_EN_reg = 1'b0;
            tap_WE_reg = 4'd0;
        end
    end
    // tap_controller //

    // WoR_tap mode controller //
    always @(*) begin
        if (ap_idle | ap_done & rready & rvalid & arvalid) begin
            if (addr_reg_W == 2'd2 & addr_reg_R == 2'd2) begin
                WoR_tap = (wvalid & wready) ? (2'b10) : ((rvalid & rready) ? (2'b01) : (2'b00));
            end else if (addr_reg_W == 2'd2) begin
                WoR_tap = (wvalid & wready) ? (2'b10) : (2'b00) ;
            end 
            else if (addr_reg_R == 2'd2) begin
                WoR_tap = (rvalid & rready) ? (2'b01) : (2'b00) ;
            end
            else begin
                WoR_tap = 2'b00;
            end
        end else if (FIR_STATE==WORK) begin 
            WoR_tap = 2'b01 ;
        end else begin // dont care
            WoR_tap = 2'b00;
        end
    end
    // WoR_tap mode controller //

    // AXI-Stream //
    reg ss_tready_reg;
    assign ss_tready=ss_tready_reg ;
    //reg [3:0] data_WE_reg;
    //assign data_WE=data_WE_reg ;
    reg [(pDATA_WIDTH-1):0] data_Di_reg;
    assign data_Di=data_Di_reg ;
    reg Resetn_fir ;
    wire Done_fir ;






    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            data_WE_reg <= 4'd0;
            data_EN_reg <= 1'b0 ;
            ss_tready_reg <= 1'b0 ;
            Resetn_fir <= 1'b0 ; 
            //data_Di_reg <= 32'b0 ;
        end else begin
            // ss_tready
            if (ap_start) begin
                data_WE_reg <= 4'b1111 ;
                data_EN_reg <= 1'b1 ;
                data_count <= 4'd10;
                ss_tready_reg <= 1'b1 ;
                data_Di_reg <= ss_tdata ;
                Resetn_fir <= 1'b0 ; 
            end else if ((FIR_STATE==WORK)) begin // steady receive data
                ss_tready_reg <= (tap_count==4'd09)?(1'b1):(1'b0) ;
                data_EN_reg <= 1'b1 ;
                Resetn_fir <= 1'b1 ; 
                if (ss_tready & ss_tvalid) begin
                    data_Di_reg <= ss_tdata ;
                end
                if (tap_count == 4'd10)begin
                    data_WE_reg <= (4'b1111);
                end else begin
                    data_WE_reg <= 4'd0;
                end
            end else if (ap_done) begin
                data_EN_reg <= 1'b0 ;
                ss_tready_reg <= 1'b0 ;
                Resetn_fir <= 1'b0 ; 
            end else begin
                ss_tready_reg <= 1'b0 ;
                Resetn_fir <= 1'b0 ; 
                data_EN_reg <= 1'b0 ;
            end
        end
    end
    // FIR kernel
//    wire [31:0] Y ;
//    reg [31:0] Y_reg ;
    //reg [(pDATA_WIDTH-1):0] sm_tdata_temp;
    //assign sm_tdata = sm_tdata_temp; 
    FIR_Logic FIR_kernel(   .X(data_Do),
                            .tap(tap_Do),
                            .CLK(axis_clk),
                            .Y(sm_tdata),
                            .Resetn(Resetn_fir),
                            .Done(Done_fir)); 
    reg sm_tvalid_reg;
    assign sm_tvalid=sm_tvalid_reg ;
    reg sm_tlast_reg;
    assign sm_tlast=sm_tlast_reg ;
    // axi stream sm 
    reg [1:0] Last ;
    initial begin
        Last = 2'b00 ;
    end
    always @(posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            //sm_tdata <= 32'd0 ;
            sm_tlast_reg <= 1'd0 ;
            sm_tvalid_reg <= 1'd0 ;
        end else begin
            if (ss_tlast & FIR_STATE==WORK) begin
                Last <= 2'b01 ;
            end
            if (Done_fir) begin     // sm_tvalid set
                if (Last==2'b01) begin // last Y 
                    Last <= 2'b10 ;
                    //5
                    //sm_tdata_temp <= sm_tdata ;
                    sm_tvalid_reg <= 1'd1 ;
                    sm_tlast_reg <= 1'd0 ;
                end else if (Last==2'b10) begin
                    Last <= 2'b00 ;
                    //5
                    //sm_tdata_temp <= sm_tdata ;
                    sm_tvalid_reg <= 1'd1 ;
                    sm_tlast_reg <= 1'd1 ;
                end else begin   
                    //5   
                    //sm_tdata_temp <= sm_tdata ;
                    sm_tvalid_reg <= 1'd1 ;
                end
            end else if (sm_tready&sm_tvalid) begin    // sm_tvalid reset
                sm_tvalid_reg <= 1'b0 ;
                sm_tlast_reg <= 1'd0 ;
                
            end 
            // else if () begin            // transfer failed

            // end
            else begin 
                sm_tvalid_reg <= 1'b0 ;
                sm_tlast_reg <= 1'd0 ;
            end

            if (sm_tlast & sm_tready & sm_tvalid) begin
                ap_done <= 1 ; 
            end else if (addr_reg_R==2'b0 &rready & rvalid &arvalid)begin
                ap_done <= 0 ;
            end else begin
                ap_done <= ap_done;
            end
        end
    end
endmodule

