-- (c)EMARD
-- License=BSD

-- module to bypass user input and usbserial to esp32 wifi

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library ecp5u;
use ecp5u.components.all;

-- USB packet generator functions
use work.usb_req_gen_func_pack.all;
-- package for decoded structure
use work.report_decoded_pack.all;

entity fleafpga_ohm_usbtest is
  generic
  (
    C_dummy_constant: integer := 0
  );
  port
  (
	-- System clock and reset
	sys_clock		: in		std_logic;	-- 25MHz clock input from external xtal oscillator.
	sys_reset		: in		std_logic;	-- master reset input from reset header.

	-- On-board status LED
	led			: buffer	std_logic;
 
	-- Digital video out
	--lvds_red		: out		std_logic_vector(1 downto 0);
	--lvds_green		: out		std_logic_vector(1 downto 0);
	--lvds_blue		: out		std_logic_vector(1 downto 0);
	--lvds_ck			: out		std_logic_vector(1 downto 0);
	
	-- USB Slave (FT230x) debug interface 
	slave_tx_o 		: out		std_logic;
	slave_rx_i 		: in		std_logic;
	slave_cts_i		: in		std_logic;	-- Receives signal from #RTS pin on FT230x, where applicable.

	-- SDRAM interface (For use with 16Mx16bit or 32Mx16bit SDR DRAM, depending on version)
	dram_clk		: out		std_logic;	-- clock to SDRAM
	dram_cke		: out		std_logic;	-- clock to SDRAM
	dram_n_cs		: out		std_logic;
	dram_n_ras		: out		std_logic;	-- SDRAM RAS
	dram_n_cas		: out		std_logic;	-- SDRAM CAS
	dram_n_we		: out		std_logic;	-- SDRAM write-enable
	dram_ba			: out		std_logic_vector(1 downto 0);	-- SDRAM bank-address
	dram_addr		: out		std_logic_vector(12 downto 0);	-- SDRAM address bus
	dram_dqm		: out		std_logic_vector(1 downto 0);
	dram_data		: inout		std_logic_vector(15 downto 0);	-- data bus to/from SDRAM

	-- GPIO Header pins declaration (RasPi compatible GPIO format)
	-- gpio0 = GPIO_IDSD
	-- gpio1 = GPIO_IDSC
	gpio			: inout		std_logic_vector(27 downto 0);

	-- Sigma Delta ADC ('Enhanced' Ohm-specific GPIO functionality)
	-- NOTE: Must comment out GPIO_5, GPIO_7, GPIO_10 AND GPIO_24 as instructed in the pin constraints file (.LPF) in order to use
	--ADC0_input	: in		std_logic;
	--ADC0_error	: buffer	std_logic;
	--ADC1_input	: in		std_logic;
	--ADC1_error	: buffer	std_logic;
	--ADC2_input	: in		std_logic;
	--ADC2_error	: buffer	std_logic;
	--ADC3_input	: in		std_logic;
	--ADC3_error	: buffer	std_logic;

	-- SD/MMC Interface (Support either SPI or nibble-mode)
	mmc_dat1		: in		std_logic;
	mmc_dat2		: in		std_logic;
	mmc_n_cs		: out		std_logic;
	mmc_clk			: out		std_logic;
	mmc_mosi		: out		std_logic; 
	mmc_miso		: in		std_logic;

	-- PS/2 Mode enable, keyboard and Mouse interfaces
	usb1_ps2_enable		: out		std_logic := '0';
	usb1_dp			: inout		std_logic;
	usb1_dn			: inout		std_logic;

	usb2_dp			: inout		std_logic;
	usb2_dn			: inout		std_logic
  );
end;

architecture Behavioral of fleafpga_ohm_usbtest is
  signal clk_100MHz, clk_60MHz, clk_7M5Hz, clk_12MHz: std_logic;
  signal S_reset: std_logic;  
  signal S_hid_report: std_logic_vector(63 downto 0);
  signal S_report_decoded: T_report_decoded;
begin
  clk_pll: entity work.clk_25M_100M_7M5_12M_60M
  port map
  (
      CLKI        =>  sys_clock, -- 25 MHz
      CLKOP       =>  clk_100MHz,
      CLKOS       =>  clk_7M5Hz,
      CLKOS2      =>  clk_12MHz,
      CLKOS3      =>  clk_60MHz
  );

  -- TX/RX passthru
  --ftdi_rxd <= wifi_txd;
  --wifi_rxd <= ftdi_txd;

  --wifi_en <= '1';
  --wifi_gpio0 <= btn(0);
  --S_reset <= not btn(0);

  --u1: if true generate
  usbhid_host_inst: entity usbhid_host
  port map
  (
    clk => clk_7M5Hz,
    reset => S_reset,
    usb_data(1) => usb1_dp,
    usb_data(0) => usb1_dn,
    hid_report => S_hid_report,
    leds => open -- led -- led/open debug
  );
  --end generate;

  --u2: if false generate
  --ps3_inst: entity usb_ps3
  --port map
  --(
  --  clk60MHz => clk_60MHz,
  --  plage => (others => '0'),
  --  usb_data(1) => usb_fpga_dp,
  --  usb_data(0) => usb_fpga_dn,
  --  leds => led -- led/open debug
  --);
  --end generate;
  
  usbhid_report_decoder_inst: entity usbhid_report_decoder
  generic map
  (
    C_mousex_scaler => 24, -- less -> faster mouse
    C_mousey_scaler => 24  -- less -> faster mouse
  )
  port map
  (
    clk => clk_7M5Hz,
    hid_report => S_hid_report,
    decoded => S_report_decoded
  );
  
  led <= S_report_decoded.btn_fps;

  -- led <= S_report_decoded.mouseq_x & S_report_decoded.mouseq_y
  --      & S_report_decoded.btn_lstick & S_report_decoded.btn_rstick & S_report_decoded.btn_back & S_report_decoded.btn_start;
  -- led <= S_lstick_left & S_lstick_right & S_lstick_up & S_lstick_down
  --      & S_rstick_left & S_rstick_right & S_rstick_up & S_rstick_down;
  -- led <= S_hat_up & S_hat_down & S_hat_left & S_hat_right & S_btn_y & S_btn_a & S_btn_x & S_btn_b;
  -- led <= S_btn_a & S_btn_b & S_btn_x & S_btn_y & S_btn_left_bumper & S_btn_right_bumper & S_btn_left_trigger & S_btn_right_trigger;
  -- led <= "00" & S_btn_back & S_btn_start & S_btn_lstick & S_btn_rstick & S_btn_fps & S_btn_fps_toggle;
  -- led(5 downto 0) <= S_analog_trigger;

end Behavioral;
