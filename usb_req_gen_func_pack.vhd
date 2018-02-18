-------------------------------------------------------
-- USB constant requests functions package
-------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;

package usb_req_gen_func_pack is
  function reverse_any_vecetor(a: std_logic_vector) return std_logic_vector;
  function usb_packet_gen(nrzstream: in std_logic_vector) return std_logic_vector;
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
  -- test it with perl script:
  -- ./crc16.pl 00000000100000000100000011000000 <- input nrz stream
  -- 1111011101011110 <- this is correct CRC
  -- compare same with this function (bits of input bytes are reverse ordered)
  -- usb_packet_gen("00000000000000010000001000000011") = "1111011101011110"
  function usb_packet_gen(input_data: in std_logic_vector)
  return std_logic_vector is
    variable nrzstream: std_logic_vector(input_data'range);
    variable crc: std_logic_vector(15 downto 0);
    constant generator_polynomial: std_logic_vector(crc'range) := "1000000000000101"; -- (x^16)+x^15+x^2+x^1
    variable result: std_logic_vector(input_data'high+crc'length downto 0);
    variable nextb, crc_msb: std_logic;
  begin
    -- reverse bit order of every byte in input data
    -- to create nrzstream ready for transmission
    for i in 0 to input_data'high/8 loop
      nrzstream(8*(i+1)-1 downto 8*i) := reverse_any_vector(input_data(8*(i+1)-1 downto 8*i));
    end loop;
    -- process each bit, accumulating the crc
    crc := x"FFFF"; -- start with all bits 1
    for i in nrzstream'high downto 0 loop
      -- nextb := nrzstream(nrzstream'high - i);
      nextb := nrzstream(i);
      crc_msb := crc(crc'high); -- remember CRC MSB before shifting
      crc := crc(crc'high-1 downto 0) & '0'; -- shift 1 bit left, LSB=0, delete MSB
      if nextb /= crc_msb then
        crc := crc xor generator_polynomial;
      end if;
    end loop;
    crc := crc xor x"FFFF"; -- finally invert all CRC bits
    result := nrzstream & crc;
    return result;
  end; -- function usb_packet_gen
end package body;
