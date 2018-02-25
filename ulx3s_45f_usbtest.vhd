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

entity ulx3s_usbtest is
  generic
  (
    C_dummy_constant: integer := 0
  );
  port
  (
  clk_25MHz: in std_logic;  -- main clock input from 25MHz clock source

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
  usb_fpga_dp, usb_fpga_dn: inout std_logic;

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
  signal R_blinky: std_logic_vector(26 downto 0);

  signal S_reset: std_logic;
  
  signal S_hid_report: std_logic_vector(63 downto 0);
  signal S_lstick_x: std_logic_vector(7 downto 0);
  signal S_lstick_y: std_logic_vector(7 downto 0);
  signal S_rstick_x: std_logic_vector(7 downto 0);
  signal S_rstick_y: std_logic_vector(7 downto 0);
  signal S_analog_trigger: std_logic_vector(5 downto 0);
  signal S_btn_a: std_logic;
  signal S_btn_b: std_logic;
  signal S_btn_x: std_logic;
  signal S_btn_y: std_logic;
  signal S_btn_left_bumper: std_logic;
  signal S_btn_right_bumper: std_logic;
  signal S_btn_left_trigger: std_logic;
  signal S_btn_right_trigger: std_logic;
  signal S_btn_back: std_logic;
  signal S_btn_start: std_logic;
  signal S_btn_lstick: std_logic;
  signal S_btn_rstick: std_logic;
  signal S_btn_fps: std_logic;
  signal S_btn_fps_toggle: std_logic;
  signal S_hat_up: std_logic;
  signal S_hat_down: std_logic;
  signal S_hat_left: std_logic;
  signal S_hat_right: std_logic;
  -- decoded stick to digital
  signal S_lstick_up, S_lstick_down, S_lstick_left, S_lstick_right: std_logic;
  signal S_rstick_up, S_rstick_down, S_rstick_left, S_rstick_right: std_logic;
  signal S_mouseq_x, S_mouseq_y: std_logic_vector(1 downto 0);
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

  -- clock alive blinky
  blink: if false generate
  process(clk_7M5Hz)
  begin
      if rising_edge(clk_7M5Hz) then
        R_blinky <= R_blinky+1;
      end if;
  end process;
  led(7 downto 0) <= R_blinky(R_blinky'high downto R_blinky'high-7);
  end generate;

  usbhid_host_inst: entity usbhid_host
  port map
  (
    clk => clk_7M5Hz,
    reset => S_reset,
    usb_data(1) => usb_fpga_dp,
    usb_data(0) => usb_fpga_dn,
    hid_report => S_hid_report,
    leds => open -- led/open debug
  );
  
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
    lstick_x => S_lstick_x,
    lstick_y => S_lstick_y,
    rstick_x => S_rstick_x,
    rstick_y => S_rstick_y,
    analog_trigger => S_analog_trigger,
    mouseq_x => S_mouseq_x,
    mouseq_y => S_mouseq_y,
    lstick_up => S_lstick_up,
    lstick_down => S_lstick_down,
    lstick_left => S_lstick_left,
    lstick_right => S_lstick_right,
    rstick_up => S_rstick_up,
    rstick_down => S_rstick_down,
    rstick_left => S_rstick_left,
    rstick_right => S_rstick_right,
    hat_up => S_hat_up,
    hat_down => S_hat_down,
    hat_left => S_hat_left,
    hat_right => S_hat_right,
    btn_a => S_btn_a,
    btn_b => S_btn_b,
    btn_x => S_btn_x,
    btn_y => S_btn_y,
    btn_left_bumper => S_btn_left_bumper,
    btn_right_bumper => S_btn_right_bumper,
    btn_left_trigger => S_btn_left_trigger,
    btn_right_trigger => S_btn_right_trigger,
    btn_back => S_btn_back,
    btn_start => S_btn_start,
    btn_lstick => S_btn_lstick,
    btn_rstick => S_btn_rstick,
    btn_fps => S_btn_fps, btn_fps_toggle => S_btn_fps_toggle
  );

  led <= S_mouseq_x & S_mouseq_y
       & S_btn_lstick & S_btn_rstick & S_btn_back & S_btn_start;
  -- led <= S_lstick_left & S_lstick_right & S_lstick_up & S_lstick_down
  --      & S_rstick_left & S_rstick_right & S_rstick_up & S_rstick_down;
  -- led <= S_hat_up & S_hat_down & S_hat_left & S_hat_right & S_btn_y & S_btn_a & S_btn_x & S_btn_b;
  -- led <= S_btn_a & S_btn_b & S_btn_x & S_btn_y & S_btn_left_bumper & S_btn_right_bumper & S_btn_left_trigger & S_btn_right_trigger;
  -- led <= "00" & S_btn_back & S_btn_start & S_btn_lstick & S_btn_rstick & S_btn_fps & S_btn_fps_toggle;
  -- led(5 downto 0) <= S_analog_trigger;

end Behavioral;
