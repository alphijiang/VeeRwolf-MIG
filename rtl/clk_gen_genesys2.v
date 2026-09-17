// SPDX-License-Identifier: Apache-2.0
// Copyright 2019 Western Digital Corporation or its affiliates.
// V53 Genesys2 core clock/reset generator.
//
// The input is the MIG 4:1 ui_clk (~225 MHz for the Digilent 1111 ps DDR3
// configuration).  A dedicated PLL generates the historical VeeRwolf core
// frequencies while remaining independent of R19 assertion.  Reset assertion
// is asynchronous; release is synchronized to the generated core clock.

module clk_gen_genesys2
  (input      i_clk,
   input      i_rst,
   input      i_hold_rst,
   output     o_clk_core,
   output     o_rst_core);

   parameter CPU_TYPE = "";

   wire clkfb;
   wire locked;
   (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] hold_rst_sync = 2'b11;
   (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [2:0] reset_sync = 3'b111;

   // MIG ui_clk is approximately 225 MHz with the official Genesys2
   // 1111 ps DDR3 clock period and 4:1 PHY ratio.
   //
   // PLL VCO = 225 MHz / 3 * 16 = 1200 MHz
   // EH2: 1200 / 48 = 25 MHz
   // EL2: 1200 / 48 = 25 MHz
   // EH1: 1200 / 24 = 50 MHz
   PLLE2_BASE
     #(.BANDWIDTH("OPTIMIZED"),
       .CLKFBOUT_MULT(16),
       .CLKIN1_PERIOD(4.444),
       .CLKOUT0_DIVIDE((CPU_TYPE == "EL2") ? 48 :
                       (CPU_TYPE == "EH2") ? 48 : 24),
       .DIVCLK_DIVIDE(3),
       .STARTUP_WAIT("FALSE"))
   PLLE2_BASE_inst
     (.CLKOUT0(o_clk_core),
      .CLKOUT1(),
      .CLKOUT2(),
      .CLKOUT3(),
      .CLKOUT4(),
      .CLKOUT5(),
      .CLKFBOUT(clkfb),
      .LOCKED(locked),
      .CLKIN1(i_clk),
      .PWRDWN(1'b0),
      // Keep the PLL out of the external reset tree.  R19 and MIG UI reset
      // assert the core-domain reset below; deassertion is clocked.
      .RST(1'b0),
      .CLKFBIN(clkfb));

   // i_hold_rst originates in the MIG ui_clk domain.  Synchronize it before
   // using it in core-domain reset logic.  R19 remains the only asynchronous
   // assertion source; the first synchronizer D pin is constrained as an
   // intentional CDC in veerwolf_genesys2_impl.xdc.
   always @(posedge o_clk_core or posedge i_rst) begin
      if (i_rst)
        hold_rst_sync <= 2'b11;
      else
        hold_rst_sync <= {hold_rst_sync[0], i_hold_rst};
   end

   // Reset assertion from R19 is asynchronous.  MIG reset hold and local PLL
   // LOCKED are now consumed only after entering the clk_core domain.
   always @(posedge o_clk_core or posedge i_rst) begin
      if (i_rst)
        reset_sync <= 3'b111;
      else if (hold_rst_sync[1] || !locked)
        reset_sync <= 3'b111;
      else
        reset_sync <= {reset_sync[1:0], 1'b0};
   end

   assign o_rst_core = reset_sync[2];

endmodule
