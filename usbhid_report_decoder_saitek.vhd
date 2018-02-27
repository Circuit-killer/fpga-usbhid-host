library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;

use work.report_decoded_pack.all;

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
  decoded: out T_report_decoded
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
  decoded.btn_x <= S_btn_x;
  decoded.btn_a <= S_btn_a;
  decoded.btn_b <= S_btn_b;
  decoded.btn_y <= S_btn_y;
  decoded.btn_left_bumper <= S_btn_left_bumper;
  decoded.btn_right_bumper <= S_btn_right_bumper;
  decoded.btn_left_trigger <= S_btn_left_trigger;
  decoded.btn_right_trigger <= S_btn_right_trigger;
  decoded.btn_back <= S_btn_back;
  decoded.btn_start <= S_btn_start;
  decoded.btn_lstick <= S_btn_lstick;
  decoded.btn_rstick <= S_btn_rstick;
  decoded.btn_fps <= S_btn_fps;
  decoded.btn_fps_toggle <= S_btn_fps_toggle;

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
  decoded.hat_up <= S_hat_up;
  decoded.hat_down <= S_hat_down;
  decoded.hat_left <= S_hat_left;
  decoded.hat_right <= S_hat_right;

  -- analog stick to digital decoders
  decoded.lstick_left  <= '1' when S_lstick_x(7 downto 6) = "00" else '0';
  decoded.lstick_right <= '1' when S_lstick_x(7 downto 6) = "11" else '0';
  decoded.lstick_up    <= '1' when S_lstick_y(7 downto 6) = "00" else '0';
  decoded.lstick_down  <= '1' when S_lstick_y(7 downto 6) = "11" else '0';
  decoded.rstick_left  <= '1' when S_rstick_x(7 downto 6) = "00" else '0';
  decoded.rstick_right <= '1' when S_rstick_x(7 downto 6) = "11" else '0';
  decoded.rstick_up    <= '1' when S_rstick_y(7 downto 6) = "00" else '0';
  decoded.rstick_down  <= '1' when S_rstick_y(7 downto 6) = "11" else '0';

  decoded.analog_trigger <= S_analog_trigger;
  
  -- mouse counters
  process(clk)
  begin
      if rising_edge(clk) then
        R_mousecx <= R_mousecx+S_rstick_x-128;
        R_mousecy <= R_mousecy+S_rstick_y-128;
      end if;
  end process;

  -- mouse quadrature encoders
  decoded.mouseq_x  <= "01" when R_mousecx(R_mousecx'high downto R_mousecx'high-1) = "00" else
                       "11" when R_mousecx(R_mousecx'high downto R_mousecx'high-1) = "01" else
                       "10" when R_mousecx(R_mousecx'high downto R_mousecx'high-1) = "10" else
                       "00"; -- when "11"
  decoded.mouseq_y  <= "01" when R_mousecy(R_mousecy'high downto R_mousecy'high-1) = "00" else
                       "11" when R_mousecy(R_mousecy'high downto R_mousecy'high-1) = "01" else
                       "10" when R_mousecy(R_mousecy'high downto R_mousecy'high-1) = "10" else
                       "00"; -- when "11"
end rtl;
