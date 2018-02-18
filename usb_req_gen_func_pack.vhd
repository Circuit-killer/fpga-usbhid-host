-------------------------------------------------------
-- USB constant requests functions package
-------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;

package usb_req_gen_func_pack is
  function reverse_any_vecetor(a: std_logic_vector) return std_logic_vector;
  -- function another_function (DATA, TAPS :std_logic_vector) return std_logic_vector;
end;

package body usb_req_gen_func_pack is
  function reverse_any_vector (a: in std_logic_vector)
  return std_logic_vector is
    variable result: std_logic_vector(a'RANGE);
    alias aa: std_logic_vector(a'REVERSE_RANGE) is a;
  begin
    for i in aa'RANGE loop
      result(i) := aa(i);
    end loop;
    return result;
  end; -- function reverse_any_vector
  
  -- function to ease making USB 11-byte packets
  -- reverses bit order of 9 input bytes (passed as 72-bit vector)
  -- and appends 16-bit CRC
  -- user can write packet as 72-bit string like
  -- usb_request_packet: std_logic_vector(71 downto 0) := x"001122334455667788"
  -- this function will return 88-bit vector ready for transmission.
  -- 00 will be sent first, 88 last and then crc. 
  function usb_packet_gen(in_data: in std_logic_vector(71 downto 0))
  return std_logic_vector is
    variable bit_reorder: std_logic_vector(in_data'range);
    variable crc: std_logic_vector(15 downto 0);
    variable result: std_logic_vector(in_data'high+crc'length downto 0);
  begin
    crc := x"0000";
    for i in 0 to in_data'length/8-1 loop
      bit_reorder(8*(i+1)-1 downto 8*i) := in_data(8*(i+1)-1 downto 8*i);
    end loop;
    crc := x"AA55";
    result := bit_reorder & crc;
    return result;
  end; -- function usb_packet_gen
end package body;
