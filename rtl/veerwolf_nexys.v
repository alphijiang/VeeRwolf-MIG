// SPDX-License-Identifier: Apache-2.0
// VeeRwolf for Digilent Nexys4 DDR / Nexys A7-100T with AMD MIG DDR2.
// The DDR2 PHY and pin data come from Digilent vivado-boards nexys4_ddr/C.1.

`default_nettype none
module veerwolf_nexys_a7
  #(parameter bootrom_file = "bootloader.vh",
    parameter cpu_type = "EH1")
   (input  wire        clk,
    input  wire        rstn,
    input  wire        i_jtag_tck,
    input  wire        i_jtag_tms,
    input  wire        i_jtag_tdi,
    output wire        o_jtag_tdo,
    output wire [12:0] ddram_a,
    output wire [2:0]  ddram_ba,
    output wire        ddram_ras_n,
    output wire        ddram_cas_n,
    output wire        ddram_we_n,
    output wire        ddram_cs_n,
    output wire [1:0]  ddram_dm,
    inout  wire [15:0] ddram_dq,
    inout  wire [1:0]  ddram_dqs_p,
    inout  wire [1:0]  ddram_dqs_n,
    output wire        ddram_clk_p,
    output wire        ddram_clk_n,
    output wire        ddram_cke,
    output wire        ddram_odt,
    output wire        o_flash_cs_n,
    output wire        o_flash_mosi,
    input  wire        i_flash_miso,
    input  wire        i_uart_rx,
    output wire        o_uart_tx,
    input  wire [15:0] i_sw,
    output reg  [15:0] o_led);

   wire [63:0] gpio_out;
   reg [15:0] led_int_r;
   (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [15:0] sw_r = 16'd0;
   (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [15:0] sw_2r = 16'd0;

   wire cpu_tx;
   wire flash_sclk;

   // ------------------------------------------------------------------
   // Board, MIG and core clock domains.
   // ------------------------------------------------------------------
   wire mig_sys_clk;
   wire mig_ui_clk;
   wire mig_ui_clk_sync_rst;
   wire mig_init_calib_complete;
   wire clk_core;
   wire rst_core;
   wire soc_resetn = ~rst_core;

   clk_gen_nexys_mig
     #(.CPU_TYPE(cpu_type))
   clk_gen
     (.i_clk      (clk),
      .i_rst      (~rstn),
      .i_hold_rst (mig_ui_clk_sync_rst),
      .o_clk_mig  (mig_sys_clk),
      .o_clk_core (clk_core),
      .o_rst_core (rst_core));

   // MIG AXI aresetn is released synchronously in the MIG UI domain.
   (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [2:0] mig_axi_resetn_sync = 3'b000;
   always @(posedge mig_ui_clk) begin
      if (mig_ui_clk_sync_rst)
        mig_axi_resetn_sync <= 3'b000;
      else
        mig_axi_resetn_sync <= {mig_axi_resetn_sync[1:0], 1'b1};
   end
   wire mig_axi_resetn = mig_axi_resetn_sync[2];

   // Synchronize calibration status before syscon samples it.
   (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] mig_init_done_sync = 2'b00;
   always @(posedge clk_core or negedge soc_resetn) begin
      if (!soc_resetn)
        mig_init_done_sync <= 2'b00;
      else
        mig_init_done_sync <= {mig_init_done_sync[0], mig_init_calib_complete};
   end

   // ------------------------------------------------------------------
   // VeeRwolf AXI source and AMD AXI Clock Converter.
   // ------------------------------------------------------------------
   AXI_BUS #(32, 64, 6, 1) cpu();

   assign cpu.aw_atop = 6'd0;
   assign cpu.aw_user = 1'b0;
   assign cpu.ar_user = 1'b0;
   assign cpu.w_user  = 1'b0;
   assign cpu.b_user  = 1'b0;
   assign cpu.r_user  = 1'b0;

   wire [5:0]  mig_awid;
   wire [31:0] mig_awaddr;
   wire [7:0]  mig_awlen;
   wire [2:0]  mig_awsize;
   wire [1:0]  mig_awburst;
   wire        mig_awlock;
   wire [3:0]  mig_awcache;
   wire [2:0]  mig_awprot;
   wire [3:0]  mig_awregion;
   wire [3:0]  mig_awqos;
   wire        mig_awvalid;
   wire        mig_awready;

   wire [63:0] mig_wdata;
   wire [7:0]  mig_wstrb;
   wire        mig_wlast;
   wire        mig_wvalid;
   wire        mig_wready;

   wire [5:0]  mig_bid;
   wire [1:0]  mig_bresp;
   wire        mig_bvalid;
   wire        mig_bready;

   wire [5:0]  mig_arid;
   wire [31:0] mig_araddr;
   wire [7:0]  mig_arlen;
   wire [2:0]  mig_arsize;
   wire [1:0]  mig_arburst;
   wire        mig_arlock;
   wire [3:0]  mig_arcache;
   wire [2:0]  mig_arprot;
   wire [3:0]  mig_arregion;
   wire [3:0]  mig_arqos;
   wire        mig_arvalid;
   wire        mig_arready;

   wire [5:0]  mig_rid;
   wire [63:0] mig_rdata;
   wire [1:0]  mig_rresp;
   wire        mig_rlast;
   wire        mig_rvalid;
   wire        mig_rready;

   nexys4_axi_clock_converter axi_cdc
     (.s_axi_aclk     (clk_core),
      .s_axi_aresetn  (soc_resetn),
      .s_axi_awid     (cpu.aw_id),
      .s_axi_awaddr   (cpu.aw_addr),
      .s_axi_awlen    (cpu.aw_len),
      .s_axi_awsize   (cpu.aw_size),
      .s_axi_awburst  (cpu.aw_burst),
      .s_axi_awlock   (cpu.aw_lock),
      .s_axi_awcache  (cpu.aw_cache),
      .s_axi_awprot   (cpu.aw_prot),
      .s_axi_awregion (cpu.aw_region),
      .s_axi_awqos    (cpu.aw_qos),
      .s_axi_awvalid  (cpu.aw_valid),
      .s_axi_awready  (cpu.aw_ready),
      .s_axi_wdata    (cpu.w_data),
      .s_axi_wstrb    (cpu.w_strb),
      .s_axi_wlast    (cpu.w_last),
      .s_axi_wvalid   (cpu.w_valid),
      .s_axi_wready   (cpu.w_ready),
      .s_axi_bid      (cpu.b_id),
      .s_axi_bresp    (cpu.b_resp),
      .s_axi_bvalid   (cpu.b_valid),
      .s_axi_bready   (cpu.b_ready),
      .s_axi_arid     (cpu.ar_id),
      .s_axi_araddr   (cpu.ar_addr),
      .s_axi_arlen    (cpu.ar_len),
      .s_axi_arsize   (cpu.ar_size),
      .s_axi_arburst  (cpu.ar_burst),
      .s_axi_arlock   (cpu.ar_lock),
      .s_axi_arcache  (cpu.ar_cache),
      .s_axi_arprot   (cpu.ar_prot),
      .s_axi_arregion (cpu.ar_region),
      .s_axi_arqos    (cpu.ar_qos),
      .s_axi_arvalid  (cpu.ar_valid),
      .s_axi_arready  (cpu.ar_ready),
      .s_axi_rid      (cpu.r_id),
      .s_axi_rdata    (cpu.r_data),
      .s_axi_rresp    (cpu.r_resp),
      .s_axi_rlast    (cpu.r_last),
      .s_axi_rvalid   (cpu.r_valid),
      .s_axi_rready   (cpu.r_ready),

      .m_axi_aclk     (mig_ui_clk),
      .m_axi_aresetn  (mig_axi_resetn),
      .m_axi_awid     (mig_awid),
      .m_axi_awaddr   (mig_awaddr),
      .m_axi_awlen    (mig_awlen),
      .m_axi_awsize   (mig_awsize),
      .m_axi_awburst  (mig_awburst),
      .m_axi_awlock   (mig_awlock),
      .m_axi_awcache  (mig_awcache),
      .m_axi_awprot   (mig_awprot),
      .m_axi_awregion (mig_awregion),
      .m_axi_awqos    (mig_awqos),
      .m_axi_awvalid  (mig_awvalid),
      .m_axi_awready  (mig_awready),
      .m_axi_wdata    (mig_wdata),
      .m_axi_wstrb    (mig_wstrb),
      .m_axi_wlast    (mig_wlast),
      .m_axi_wvalid   (mig_wvalid),
      .m_axi_wready   (mig_wready),
      .m_axi_bid      (mig_bid),
      .m_axi_bresp    (mig_bresp),
      .m_axi_bvalid   (mig_bvalid),
      .m_axi_bready   (mig_bready),
      .m_axi_arid     (mig_arid),
      .m_axi_araddr   (mig_araddr),
      .m_axi_arlen    (mig_arlen),
      .m_axi_arsize   (mig_arsize),
      .m_axi_arburst  (mig_arburst),
      .m_axi_arlock   (mig_arlock),
      .m_axi_arcache  (mig_arcache),
      .m_axi_arprot   (mig_arprot),
      .m_axi_arregion (mig_arregion),
      .m_axi_arqos    (mig_arqos),
      .m_axi_arvalid  (mig_arvalid),
      .m_axi_arready  (mig_arready),
      .m_axi_rid      (mig_rid),
      .m_axi_rdata    (mig_rdata),
      .m_axi_rresp    (mig_rresp),
      .m_axi_rlast    (mig_rlast),
      .m_axi_rvalid   (mig_rvalid),
      .m_axi_rready   (mig_rready));

   // ------------------------------------------------------------------
   // Digilent Nexys4 DDR C.1 MIG controller.
   // Only AXI ID width and narrow-burst support differ from the board file.
   // ------------------------------------------------------------------
   design_1_mig_7series_0_2 mig_ddr2
     (.ddr2_addr            (ddram_a),
      .ddr2_ba              (ddram_ba),
      .ddr2_ras_n           (ddram_ras_n),
      .ddr2_cas_n           (ddram_cas_n),
      .ddr2_we_n            (ddram_we_n),
      .ddr2_ck_p            (ddram_clk_p),
      .ddr2_ck_n            (ddram_clk_n),
      .ddr2_cke             (ddram_cke),
      .ddr2_cs_n            (ddram_cs_n),
      .ddr2_dm              (ddram_dm),
      .ddr2_odt             (ddram_odt),
      .ddr2_dq              (ddram_dq),
      .ddr2_dqs_p           (ddram_dqs_p),
      .ddr2_dqs_n           (ddram_dqs_n),

      .sys_clk_i            (mig_sys_clk),
      .sys_rst              (rstn),
      .ui_clk               (mig_ui_clk),
      .ui_clk_sync_rst      (mig_ui_clk_sync_rst),
      .ui_addn_clk_0        (),
      .ui_addn_clk_1        (),
      .ui_addn_clk_2        (),
      .ui_addn_clk_3        (),
      .ui_addn_clk_4        (),
      .mmcm_locked          (),
      .init_calib_complete  (mig_init_calib_complete),
      .aresetn              (mig_axi_resetn),

      .app_sr_req           (1'b0),
      .app_ref_req          (1'b0),
      .app_zq_req           (1'b0),
      .app_sr_active        (),
      .app_ref_ack          (),
      .app_zq_ack           (),

      .s_axi_awid           (mig_awid),
      .s_axi_awaddr         (mig_awaddr[26:0]),
      .s_axi_awlen          (mig_awlen),
      .s_axi_awsize         (mig_awsize),
      .s_axi_awburst        (mig_awburst),
      .s_axi_awlock         (mig_awlock),
      .s_axi_awcache        (mig_awcache),
      .s_axi_awprot         (mig_awprot),
      .s_axi_awqos          (mig_awqos),
      .s_axi_awvalid        (mig_awvalid),
      .s_axi_awready        (mig_awready),
      .s_axi_wdata          (mig_wdata),
      .s_axi_wstrb          (mig_wstrb),
      .s_axi_wlast          (mig_wlast),
      .s_axi_wvalid         (mig_wvalid),
      .s_axi_wready         (mig_wready),
      .s_axi_bid            (mig_bid),
      .s_axi_bresp          (mig_bresp),
      .s_axi_bvalid         (mig_bvalid),
      .s_axi_bready         (mig_bready),
      .s_axi_arid           (mig_arid),
      .s_axi_araddr         (mig_araddr[26:0]),
      .s_axi_arlen          (mig_arlen),
      .s_axi_arsize         (mig_arsize),
      .s_axi_arburst        (mig_arburst),
      .s_axi_arlock         (mig_arlock),
      .s_axi_arcache        (mig_arcache),
      .s_axi_arprot         (mig_arprot),
      .s_axi_arqos          (mig_arqos),
      .s_axi_arvalid        (mig_arvalid),
      .s_axi_arready        (mig_arready),
      .s_axi_rid            (mig_rid),
      .s_axi_rdata          (mig_rdata),
      .s_axi_rresp          (mig_rresp),
      .s_axi_rlast          (mig_rlast),
      .s_axi_rvalid         (mig_rvalid),
      .s_axi_rready         (mig_rready));

   // ------------------------------------------------------------------
   // External JTAG DMI and VeeRwolf SoC.
   // ------------------------------------------------------------------
   wire        dmi_reg_en;
   wire [6:0]  dmi_reg_addr;
   wire        dmi_reg_wr_en;
   wire [31:0] dmi_reg_wdata;
   wire [31:0] dmi_reg_rdata;
   wire        dmi_hard_reset;

   STARTUPE2 STARTUPE2
     (.CFGCLK    (),
      .CFGMCLK   (),
      .EOS       (),
      .PREQ      (),
      .CLK       (1'b0),
      .GSR       (1'b0),
      .GTS       (1'b0),
      .KEYCLEARB (1'b1),
      .PACK      (1'b0),
      .USRCCLKO  (flash_sclk),
      .USRCCLKTS (1'b0),
      .USRDONEO  (1'b1),
      .USRDONETS (1'b0));

   dmi_wrapper tap
     (.trst_n        (~rst_core),
      .tck           (i_jtag_tck),
      .tms           (i_jtag_tms),
      .tdi           (i_jtag_tdi),
      .tdo           (o_jtag_tdo),
      .tdoEnable     (),
      .core_rst_n    (~rst_core),
      .core_clk      (clk_core),
      .jtag_id       (31'd0),
      .rd_data       (dmi_reg_rdata),
      .reg_wr_data   (dmi_reg_wdata),
      .reg_wr_addr   (dmi_reg_addr),
      .reg_en        (dmi_reg_en),
      .reg_wr_en     (dmi_reg_wr_en),
      .dmi_hard_reset(dmi_hard_reset));

   veerwolf_core
     #(.bootrom_file (bootrom_file),
       .clk_freq_hz  ((cpu_type == "EL2") ? 32'd25_000_000 :
                      (cpu_type == "EH2") ? 32'd25_000_000 : 32'd50_000_000))
   veerwolf
     (.clk  (clk_core),
      .rstn (~rst_core),
      .dmi_reg_rdata  (dmi_reg_rdata),
      .dmi_reg_wdata  (dmi_reg_wdata),
      .dmi_reg_addr   (dmi_reg_addr ),
      .dmi_reg_en     (dmi_reg_en   ),
      .dmi_reg_wr_en  (dmi_reg_wr_en),
      .dmi_hard_reset (dmi_hard_reset),
      .o_flash_sclk   (flash_sclk),
      .o_flash_cs_n   (o_flash_cs_n),
      .o_flash_mosi   (o_flash_mosi),
      .i_flash_miso   (i_flash_miso),
      .i_uart_rx      (i_uart_rx),
      .o_uart_tx      (cpu_tx),
      .o_ram_awid     (cpu.aw_id),
      .o_ram_awaddr   (cpu.aw_addr),
      .o_ram_awlen    (cpu.aw_len),
      .o_ram_awsize   (cpu.aw_size),
      .o_ram_awburst  (cpu.aw_burst),
      .o_ram_awlock   (cpu.aw_lock),
      .o_ram_awcache  (cpu.aw_cache),
      .o_ram_awprot   (cpu.aw_prot),
      .o_ram_awregion (cpu.aw_region),
      .o_ram_awqos    (cpu.aw_qos),
      .o_ram_awvalid  (cpu.aw_valid),
      .i_ram_awready  (cpu.aw_ready),
      .o_ram_arid     (cpu.ar_id),
      .o_ram_araddr   (cpu.ar_addr),
      .o_ram_arlen    (cpu.ar_len),
      .o_ram_arsize   (cpu.ar_size),
      .o_ram_arburst  (cpu.ar_burst),
      .o_ram_arlock   (cpu.ar_lock),
      .o_ram_arcache  (cpu.ar_cache),
      .o_ram_arprot   (cpu.ar_prot),
      .o_ram_arregion (cpu.ar_region),
      .o_ram_arqos    (cpu.ar_qos),
      .o_ram_arvalid  (cpu.ar_valid),
      .i_ram_arready  (cpu.ar_ready),
      .o_ram_wdata    (cpu.w_data),
      .o_ram_wstrb    (cpu.w_strb),
      .o_ram_wlast    (cpu.w_last),
      .o_ram_wvalid   (cpu.w_valid),
      .i_ram_wready   (cpu.w_ready),
      .i_ram_bid      (cpu.b_id),
      .i_ram_bresp    (cpu.b_resp),
      .i_ram_bvalid   (cpu.b_valid),
      .o_ram_bready   (cpu.b_ready),
      .i_ram_rid      (cpu.r_id),
      .i_ram_rdata    (cpu.r_data),
      .i_ram_rresp    (cpu.r_resp),
      .i_ram_rlast    (cpu.r_last),
      .i_ram_rvalid   (cpu.r_valid),
      .o_ram_rready   (cpu.r_ready),
      .i_ram_init_done   (mig_init_done_sync[1]),
      .i_ram_init_error  (1'b0),
      .i_gpio           ({32'd0,sw_2r,16'd0}),
      .o_gpio           (gpio_out));

   always @(posedge clk_core) begin
      if (rst_core) begin
         sw_r      <= 16'd0;
         sw_2r     <= 16'd0;
         led_int_r <= 16'd0;
         o_led     <= 16'd0;
      end else begin
         sw_r      <= i_sw;
         sw_2r     <= sw_r;
         led_int_r <= gpio_out[15:0];
         o_led     <= led_int_r;
      end
   end

   assign o_uart_tx = cpu_tx;

endmodule
`default_nettype wire
