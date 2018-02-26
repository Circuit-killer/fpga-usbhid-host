library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;

entity usbhid_report_decoder is
generic
(
  C_reg_input: boolean := false; -- take input in register (release timing)
  -- mouse speed also depends on clk
  C_mousex_scaler: integer := 24; -- less -> faster mouse
  C_mousey_scaler: integer := 24  -- less -> faster mouse
);
port
(
  clk: in std_logic; -- 7.5 MHz clock for USB1.0, 60 MHz for USB1.1
  hid_report: in std_logic_vector(63 downto 0);
  -- decoded outputs:
  lstick_x, lstick_y, rstick_x, rstick_y: out std_logic_vector(7 downto 0); -- up/left=0 idle=128 down/right=255
  analog_trigger: out std_logic_vector(5 downto 0);
  mouseq_x, mouseq_y: out std_logic_vector(1 downto 0); -- quadrature encoder output
  hat_up, hat_down, hat_left, hat_right: out std_logic;
  lstick_up, lstick_down, lstick_left, lstick_right: out std_logic;
  rstick_up, rstick_down, rstick_left, rstick_right: out std_logic;
  btn_a, btn_b, btn_x, btn_y: out std_logic;
  btn_left_bumper, btn_right_bumper: out std_logic;
  btn_left_trigger, btn_right_trigger: out std_logic;
  btn_back, btn_start: out std_logic;
  btn_lstick, btn_rstick: out std_logic;
  btn_fps, btn_fps_toggle: out std_logic
);
end;

architecture rtl of usbhid_report_decoder is
  signal R_hid_report: std_logic_vector(63 downto 0);
  alias S_lstick_x: std_logic_vector(7 downto 0) is R_hid_report(15 downto 8);
  alias S_lstick_y: std_logic_vector(7 downto 0) is R_hid_report(23 downto 16);
  alias S_rstick_x: std_logic_vector(7 downto 0) is R_hid_report(31 downto 24);
  alias S_rstick_y: std_logic_vector(7 downto 0) is R_hid_report(39 downto 32);
  alias S_analog_trigger: std_logic_vector(5 downto 0) is R_hid_report(45 downto 40);
  alias S_btn_x: std_logic is R_hid_report(46);
  alias S_btn_a: std_logic is R_hid_report(47);
  alias S_btn_b: std_logic is R_hid_report(48);
  alias S_btn_y: std_logic is R_hid_report(49);
  alias S_btn_left_bumper: std_logic is R_hid_report(50);
  alias S_btn_right_bumper: std_logic is R_hid_report(51);
  alias S_btn_left_trigger: std_logic is R_hid_report(52);
  alias S_btn_right_trigger: std_logic is R_hid_report(53);
  alias S_btn_back: std_logic is R_hid_report(54);
  alias S_btn_start: std_logic is R_hid_report(55);
  alias S_btn_lstick: std_logic is R_hid_report(56);
  alias S_btn_rstick: std_logic is R_hid_report(57);
  alias S_btn_fps: std_logic is R_hid_report(58);
  alias S_btn_fps_toggle: std_logic is R_hid_report(59);
  alias S_hat: std_logic_vector(3 downto 0) is R_hid_report(63 downto 60);
  signal S_hat_udlr: std_logic_vector(3 downto 0); -- decoded
  alias S_hat_up: std_logic is S_hat_udlr(3);
  alias S_hat_down: std_logic is S_hat_udlr(2);
  alias S_hat_left: std_logic is S_hat_udlr(1);
  alias S_hat_right: std_logic is S_hat_udlr(0);
  -- decoded stick to digital
  signal S_lstick_up, S_lstick_down, S_lstick_left, S_lstick_right: std_logic;
  signal S_rstick_up, S_rstick_down, S_rstick_left, S_rstick_right: std_logic;
  signal R_mousecx: std_logic_vector(C_mousex_scaler-1 downto 0);
  signal R_mousecy: std_logic_vector(C_mousey_scaler-1 downto 0);
begin

  yes_reg_input: if C_reg_input generate
  process(clk) is
  begin
    if rising_edge(clk) then
      R_hid_report <= hid_report; -- register to release timing closure
    end if;
  end process;
  end generate;

  no_reg_input: if not C_reg_input generate
    R_hid_report <= hid_report; -- directly take input
  end generate;

  -- simple buttons
  btn_x <= S_btn_x;
  btn_a <= S_btn_a;
  btn_b <= S_btn_b;
  btn_y <= S_btn_y;
  btn_left_bumper <= S_btn_left_bumper;
  btn_right_bumper <= S_btn_right_bumper;
  btn_left_trigger <= S_btn_left_trigger;
  btn_right_trigger <= S_btn_right_trigger;
  btn_back <= S_btn_back;
  btn_start <= S_btn_start;
  btn_lstick <= S_btn_lstick;
  btn_rstick <= S_btn_rstick;
  btn_fps <= S_btn_fps;
  btn_fps_toggle <= S_btn_fps_toggle;

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

  -- hat as buttons
  hat_up <= S_hat_up;
  hat_down <= S_hat_down;
  hat_left <= S_hat_left;
  hat_right <= S_hat_right;

  -- analog stick to digital decoders
  lstick_left  <= '1' when S_lstick_x(7 downto 6) = "00" else '0';
  lstick_right <= '1' when S_lstick_x(7 downto 6) = "11" else '0';
  lstick_up    <= '1' when S_lstick_y(7 downto 6) = "00" else '0';
  lstick_down  <= '1' when S_lstick_y(7 downto 6) = "11" else '0';
  rstick_left  <= '1' when S_rstick_x(7 downto 6) = "00" else '0';
  rstick_right <= '1' when S_rstick_x(7 downto 6) = "11" else '0';
  rstick_up    <= '1' when S_rstick_y(7 downto 6) = "00" else '0';
  rstick_down  <= '1' when S_rstick_y(7 downto 6) = "11" else '0';

  analog_trigger <= S_analog_trigger;
  
  -- mouse counters
  process(clk)
  begin
      if rising_edge(clk) then
        R_mousecx <= R_mousecx+S_rstick_x-128;
        R_mousecy <= R_mousecy+S_rstick_y-128;
      end if;
  end process;

  -- mouse quadrature encoders
  mouseq_x  <= "01" when R_mousecx(R_mousecx'high downto R_mousecx'high-1) = "00" else
               "11" when R_mousecx(R_mousecx'high downto R_mousecx'high-1) = "01" else
               "10" when R_mousecx(R_mousecx'high downto R_mousecx'high-1) = "10" else
               "00"; -- when "11"
  mouseq_y  <= "01" when R_mousecy(R_mousecy'high downto R_mousecy'high-1) = "00" else
               "11" when R_mousecy(R_mousecy'high downto R_mousecy'high-1) = "01" else
               "10" when R_mousecy(R_mousecy'high downto R_mousecy'high-1) = "10" else
               "00"; -- when "11"
end rtl;
