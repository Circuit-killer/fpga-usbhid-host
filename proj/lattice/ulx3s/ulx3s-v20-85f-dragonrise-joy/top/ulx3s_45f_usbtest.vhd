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

entity ulx3s_usbtest is
  generic
  (
    C_dummy_constant: integer := 0
  );
  port
  (
  clk_25mhz: in std_logic;  -- main clock input from 25MHz clock source

  -- UART0 (FTDI USB slave serial)
  ftdi_rxd: out   std_logic;
  ftdi_txd: in    std_logic;
  -- FTDI additional signaling
  ftdi_ndtr: inout  std_logic;
  ftdi_ndsr: inout  std_logic;
  ftdi_nrts: inout  std_logic;
  ftdi_txden: inout std_logic;

  -- UART1 (WiFi serial)
  wifi_rxd: out   std_logic;
  wifi_txd: in    std_logic;
  -- WiFi additional signaling
  wifi_en: inout  std_logic := 'Z'; -- '0' will disable wifi by default
  wifi_gpio0: inout std_logic;
  wifi_gpio2: inout std_logic;
  wifi_gpio15: inout std_logic;
  wifi_gpio16: inout std_logic;

  -- Onboard blinky
  led: out std_logic_vector(7 downto 0);
  btn: in std_logic_vector(6 downto 0);
  sw: in std_logic_vector(1 to 4);
  oled_csn, oled_clk, oled_mosi, oled_dc, oled_resn: out std_logic;

  -- GPIO (some are shared with wifi and adc)
  gp, gn: inout std_logic_vector(27 downto 0) := (others => 'Z');
  
  -- FPGA direct USB connector
  usb_fpga_dp: in std_logic; -- differential input
  usb_fpga_bd_dp, usb_fpga_bd_dn: inout std_logic; -- single ended bidirectional
  usb_fpga_pu_dp, usb_fpga_pu_dn: inout std_logic; -- pull up for slave, down for host mode

  -- SHUTDOWN: logic '1' here will shutdown power on PCB >= v1.7.5
  shutdown: out std_logic := '0';

  -- Digital Video (differential outputs)
  --gpdi_dp, gpdi_dn: out std_logic_vector(2 downto 0);
  --gpdi_clkp, gpdi_clkn: out std_logic;

  -- Flash ROM (SPI0)
  --flash_miso   : in      std_logic;
  --flash_mosi   : out     std_logic;
  --flash_clk    : out     std_logic;
  --flash_csn    : out     std_logic;

  -- SD card (SPI1)
  sd_dat3_csn, sd_cmd_di, sd_dat0_do, sd_dat1_irq, sd_dat2: inout std_logic := 'Z';
  sd_clk: inout std_logic := 'Z';
  sd_cdn, sd_wp: inout std_logic := 'Z'
  );
end;

architecture Behavioral of ulx3s_usbtest is
  signal clk_100MHz, clk_60MHz, clk_7M5Hz, clk_12MHz: std_logic;
  signal S_reset: std_logic;  
  signal S_hid_report: std_logic_vector(63 downto 0);
  signal S_report_decoded: T_report_decoded;
  signal S_step_ps3, S_step_cmd: std_logic_vector(7 downto 0);
begin
  clk_pll: entity work.clk_25M_100M_7M5_12M_60M
  port map
  (
      CLKI        =>  clk_25MHz,
      CLKOP       =>  clk_100MHz,
      CLKOS       =>  clk_7M5Hz,
      CLKOS2      =>  clk_12MHz,
      CLKOS3      =>  clk_60MHz
  );

  -- TX/RX passthru
  --ftdi_rxd <= wifi_txd;
  --wifi_rxd <= ftdi_txd;

  wifi_en <= '1';
  wifi_gpio0 <= btn(0);
  S_reset <= not btn(0);
  -- USB D+,D- pull down for host mode
  usb_fpga_pu_dp <= 'Z';
  usb_fpga_pu_dn <= 'Z';

  --u1: if true generate
  usbhid_host_inst: entity usbhid_host
  generic map
  (
    C_differential_mode => false
  )
  port map
  (
    clk => clk_7M5Hz,
    reset => S_reset,
    usb_data(1) => usb_fpga_bd_dp,
    usb_data(0) => usb_fpga_bd_dn,
    usb_ddata => usb_fpga_dp,
    hid_report => S_hid_report,
    dbg_step_ps3 => S_step_ps3,
    dbg_step_cmd => S_step_cmd,
    leds => open -- led/open debug
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
    C_lmouse => true,
    C_lmousex_scaler => 24, -- less -> faster mouse
    C_lmousey_scaler => 24, -- less -> faster mouse
    C_rmouse => true,
    C_rmousex_scaler => 24, -- less -> faster mouse
    C_rmousey_scaler => 24  -- less -> faster mouse
  )
  port map
  (
    clk => clk_7M5Hz,
    hid_report => S_hid_report,
    decoded => S_report_decoded
  );

  -- see the HID report on the OLED
  g_oled: if false generate
  oled_inst: entity work.oled
  generic map
  (
    C_data_len => S_hid_report'length
  )
  port map
  (
    clk => clk_25MHz,
    en => '1',
    data => S_hid_report(63 downto 16) & S_step_ps3(7 downto 0) & S_step_cmd(7 downto 0),
    spi_resn => oled_resn,
    spi_clk => oled_clk,
    spi_csn => oled_csn,
    spi_dc => oled_dc,
    spi_mosi => oled_mosi
  );
  end generate;

  -- led <= S_report_decoded.lmouseq_x & S_report_decoded.lmouseq_y
  --      & S_report_decoded.rmouseq_x & S_report_decoded.rmouseq_y;
  -- led <= S_report_decoded.lmouseq_x & S_report_decoded.lmouseq_y
  --      & "00" & S_report_decoded.btn_lstick & S_report_decoded.btn_back;
  -- led <= S_report_decoded.rmouseq_x & S_report_decoded.rmouseq_y
  --      & "00" & S_report_decoded.btn_rstick & S_report_decoded.btn_start;
  -- led <= S_lstick_left & S_lstick_right & S_lstick_up & S_lstick_down
  --      & S_rstick_left & S_rstick_right & S_rstick_up & S_rstick_down;
  led <= S_report_decoded.btn_a & S_report_decoded.btn_b & S_report_decoded.btn_x & S_report_decoded.btn_y 
         & S_report_decoded.btn_lbumper  & S_report_decoded.btn_rbumper 
         & S_report_decoded.btn_ltrigger & S_report_decoded.btn_rtrigger;
  -- led <= S_hat_up & S_hat_down & S_hat_left & S_hat_right & S_btn_y & S_btn_a & S_btn_x & S_btn_b;
  -- led <= "00" & S_btn_back & S_btn_start & S_btn_lstick & S_btn_rstick & S_btn_fps & S_btn_fps_toggle;
  -- led(5 downto 0) <= S_analog_trigger;

end Behavioral;
