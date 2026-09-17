// SPDX-License-Identifier: Apache-2.0
// Nexys4 DDR clock/reset generation for the MIG target.

module clk_gen_nexys_mig
  #(parameter CPU_TYPE = "")
   (input  wire i_clk,
    input  wire i_rst,
    input  wire i_hold_rst,
    output wire o_clk_mig,
    output wire o_clk_core,
    output wire o_rst_core);

   wire clkfb;
   wire locked;
   wire clk_mig_unbuf;
   wire clk_core_unbuf;
   (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] hold_rst_sync = 2'b11;
   (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [2:0] reset_sync = 3'b111;

   // 100 MHz input, 1000 MHz VCO.
   // CLKOUT0: 200 MHz MIG system/reference clock.
   // CLKOUT1: EL2 25 MHz, EH2 40 MHz, EH1 50 MHz.
   PLLE2_BASE
     #(.BANDWIDTH("OPTIMIZED"),
       .CLKFBOUT_MULT(10),
       .CLKIN1_PERIOD(10.0),
       .CLKOUT0_DIVIDE(5),
       .CLKOUT1_DIVIDE((CPU_TYPE == "EL2") ? 40 :
                       (CPU_TYPE == "EH2") ? 25 : 20),
       .DIVCLK_DIVIDE(1),
       .STARTUP_WAIT("FALSE"))
   pll
     (.CLKOUT0(clk_mig_unbuf),
      .CLKOUT1(clk_core_unbuf),
      .CLKOUT2(),
      .CLKOUT3(),
      .CLKOUT4(),
      .CLKOUT5(),
      .CLKFBOUT(clkfb),
      .LOCKED(locked),
      .CLKIN1(i_clk),
      .PWRDWN(1'b0),
      .RST(i_rst),
      .CLKFBIN(clkfb));

   BUFG mig_clk_buf
     (.I(clk_mig_unbuf),
      .O(o_clk_mig));

   BUFG core_clk_buf
     (.I(clk_core_unbuf),
      .O(o_clk_core));

   // MIG UI reset is asynchronous to the independently generated core clock.
   always @(posedge o_clk_core or posedge i_rst) begin
      if (i_rst)
        hold_rst_sync <= 2'b11;
      else
        hold_rst_sync <= {hold_rst_sync[0], i_hold_rst};
   end

   always @(posedge o_clk_core or posedge i_rst) begin
      if (i_rst)
        reset_sync <= 3'b111;
      else if (!locked || hold_rst_sync[1])
        reset_sync <= 3'b111;
      else
        reset_sync <= {reset_sync[1:0], 1'b0};
   end

   assign o_rst_core = reset_sync[2];

endmodule
