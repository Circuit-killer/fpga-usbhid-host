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

  -----8<----- cut here -----8<-----  
  -- testing generation of USB messages
  constant usb_message: std_logic_vector(71 downto 0) := x"031122334455667788";
  constant crc16_test_message: std_logic_vector(31 downto 0) := "00000000000000010000001000000011";

  -- those bytes are already reversed in transmission order
  constant ACK  :std_logic_vector(7 downto 0):="01001011";
  constant NACK :std_logic_vector(7 downto 0):="01011010";
  constant STALL:std_logic_vector(7 downto 0):="01110001";
  constant DATA1:std_logic_vector(7 downto 0):="11010010";
  constant DATA0:std_logic_vector(7 downto 0):="11000011";
  constant SETUP:std_logic_vector(7 downto 0):="10110100";
  
  -- reversing them back to become readable
  constant C_ACK  :std_logic_vector(7 downto 0):=reverse_any_vector("01001011");
  constant C_NACK :std_logic_vector(7 downto 0):=reverse_any_vector("01011010");
  constant C_STALL:std_logic_vector(7 downto 0):=reverse_any_vector("01110001");
  constant C_DATA1:std_logic_vector(7 downto 0):=reverse_any_vector("11010010");
  constant C_DATA0:std_logic_vector(7 downto 0):=reverse_any_vector("11000011");
  constant C_SETUP:std_logic_vector(7 downto 0):=reverse_any_vector("10110100");

  -- those probably contain 5-bit CRC
  constant ADDR0_ENDP0:std_logic_vector(11+5-1 downto 0):="00000000000" & "01000";
  constant ADDR1_ENDP0:std_logic_vector(11+5-1 downto 0):="10000000000" & "10111";
  constant ADDR1_ENDP1:std_logic_vector(11+5-1 downto 0):="10000001000" & "11010";

  -- all bits reversed and CRC
  constant GET_DESCRIPTOR_DEVICE_40h : std_logic_vector(11*8-1 downto 0) := DATA0 & "00000001" & "01100000" & "00000000"&"10000000" & "00000000"&"00000000" & "00000010"&"00000000" & "1011101100101001";
  constant SET_ADDRESS_1             : std_logic_vector(11*8-1 downto 0) := DATA0 & "00000000" & "10100000" & "10000000"&"00000000" & "00000000"&"00000000" & "00000000"&"00000000" & "1101011110100100";
  constant GET_DESCRIPTOR_REPORT_B7h : std_logic_vector(11*8-1 downto 0) := DATA0 & "10000001" & "01100000" & "00000000"&"01000100" & "00000000"&"00000000" & "11101101"&"00000000" & "1111100111110101";

  -- readable form without CRC
  constant C_GET_DESCRIPTOR_DEVICE_40h : std_logic_vector(9*8-1 downto 0) := reverse_any_vector(DATA0) & x"8006000100004000";
  constant C_SET_ADDRESS_1             : std_logic_vector(9*8-1 downto 0) := reverse_any_vector(DATA0) & x"0005010000000000";
  constant C_GET_DESCRIPTOR_REPORT_B7h : std_logic_vector(9*8-1 downto 0) := reverse_any_vector(DATA0) & x"810600220000B700";
  constant C_ADDR1_ENDP1 : std_logic_vector(10 downto 0) := "00010000001";
  -----8<----- cut here -----8<-----  
  signal S_reset: std_logic;
  
  signal S_hid_report: std_logic_vector(63 downto 0);
  alias S_left_stick_x: std_logic_vector(7 downto 0) is S_hid_report(15 downto 8);
  alias S_left_stick_y: std_logic_vector(7 downto 0) is S_hid_report(23 downto 16);
  alias S_right_stick_x: std_logic_vector(7 downto 0) is S_hid_report(31 downto 24);
  alias S_right_stick_y: std_logic_vector(7 downto 0) is S_hid_report(39 downto 32);
  alias S_analog_trigger: std_logic_vector(5 downto 0) is S_hid_report(45 downto 40);
  alias S_btn_x: std_logic is S_hid_report(46);
  alias S_btn_a: std_logic is S_hid_report(47);
  alias S_btn_b: std_logic is S_hid_report(48);
  alias S_btn_y: std_logic is S_hid_report(49);
  alias S_btn_left_bumper: std_logic is S_hid_report(50);
  alias S_btn_right_bumper: std_logic is S_hid_report(51);
  alias S_btn_left_trigger: std_logic is S_hid_report(52);
  alias S_btn_right_trigger: std_logic is S_hid_report(53);
  alias S_btn_back: std_logic is S_hid_report(54);
  alias S_btn_start: std_logic is S_hid_report(55);
  alias S_btn_left_pad: std_logic is S_hid_report(56);
  alias S_btn_right_pad: std_logic is S_hid_report(57);
  alias S_btn_fps: std_logic is S_hid_report(58);
  alias S_btn_fps_toggle: std_logic is S_hid_report(59);
  alias S_hat: std_logic_vector(3 downto 0) is S_hid_report(63 downto 60);
  signal S_hat_udlr: std_logic_vector(3 downto 0); -- decoded
  alias S_hat_up: std_logic is S_hat_udlr(3);
  alias S_hat_down: std_logic is S_hat_udlr(2);
  alias S_hat_left: std_logic is S_hat_udlr(1);
  alias S_hat_right: std_logic is S_hat_udlr(0);

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

  usb_saitek_inst: entity usbhid_host
  port map
  (
    clk7_5MHz => clk_7M5Hz,
    reset => S_reset,
    usb_data(1) => usb_fpga_dp,
    usb_data(0) => usb_fpga_dn,
    hid_report => S_hid_report,
    leds => led -- debug
  );

  -- hat decoder  
  S_hat_udlr <= "1000" when S_hat = "0000" else -- up
                "1001" when S_hat = "0001" else -- up+right
                "0001" when S_hat = "0010" else -- right
                "0101" when S_hat = "0011" else -- down+right
                "0100" when S_hat = "0100" else -- down
                "0110" when S_hat = "0101" else -- down+left
                "0010" when S_hat = "0110" else -- left
                "1010" when S_hat = "0111" else -- up+left
                "0000";          -- "1111" when not pressed

  -- led <= S_hat_up & S_hat_down & S_hat_left & S_hat_right & S_btn_y & S_btn_a & S_btn_x & S_btn_b;
  -- led <= S_btn_a & S_btn_b & S_btn_x & S_btn_y & S_btn_left_bumper & S_btn_right_bumper & S_btn_left_trigger & S_btn_right_trigger;
  -- led <= "00" & S_btn_back & S_btn_start & S_btn_left_pad & S_btn_right_pad & S_btn_fps & S_btn_fps_toggle;
  -- led(5 downto 0) <= S_analog_trigger;

  -- small test suite for usb packet generator
  -- led <= reverse_any_vector(x"07");
  -- led <= DATA0;
  -- led <= GET_DESCRIPTOR_DEVICE_40h(87 downto 87-7);
  -- led <= CN_GET_DESCRIPTOR_DEVICE_40h(87 downto 87-7);
  -- led <= GET_DESCRIPTOR_DEVICE_40h(7 downto 0);
  -- led <= CN_GET_DESCRIPTOR_DEVICE_40h(15 downto 8);
  -- led <= usb_data_gen(crc16_test_message) (7 downto 0);
  -- led <= usb_data_gen(crc16_test_message) (15 downto 8);

  --led <= x"01" when ADDR1_ENDP1 = usb_token_gen(C_ADDR1_ENDP1)
  --led <= x"01" when GET_DESCRIPTOR_REPORT_B7h = usb_data_gen(C_GET_DESCRIPTOR_REPORT_B7h)
  --led <= x"01" when SET_ADDRESS_1 = usb_data_gen(C_SET_ADDRESS_1)
  --led <= x"01" when GET_DESCRIPTOR_DEVICE_40h = usb_data_gen(C_GET_DESCRIPTOR_DEVICE_40h)
  --  else x"55"; -- this is shown if test failed

end Behavioral;
