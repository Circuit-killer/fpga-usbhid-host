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
  -- 1111011101011110 <- this is correct response
  function usb_packet_gen(nrzstream: in std_logic_vector)
  return std_logic_vector is
    variable bit_reorder: std_logic_vector(nrzstream'range);
    variable crc: std_logic_vector(15 downto 0);
    constant g: std_logic_vector(crc'range) := "1000000000000101"; -- CRC generator polynomial x^16+x^15+x^2+x^1
    variable result: std_logic_vector(nrzstream'high+crc'length downto 0);
    variable nextb, crcmsb: std_logic;
  begin
    -- reorder input data into nrzstream ready for transmission
    for i in 0 to nrzstream'high/8 loop
      bit_reorder(8*(i+1)-1 downto 8*i) := reverse_any_vector(nrzstream(8*(i+1)-1 downto 8*i));
    end loop;
    bit_reorder := nrzstream; -- for now just copy
    -- process each bit, accumulating the crc
    crc := x"FFFF"; -- start with all bits 1
    for i in bit_reorder'high downto 0 loop
      -- nextb := bit_reorder(nrzstream'high - i);
      nextb := bit_reorder(i);
      crcmsb := crc(crc'high); -- remember MSB before shifting
      crc := crc(crc'high-1 downto 0) & '0'; -- shift 1 bit left, LSB=0, delete MSB
      if nextb /= crcmsb then
        crc := crc xor g; -- xor with generator polynomial
      end if;
    end loop;
    crc := crc xor x"FFFF"; -- final invert all bits
    result := bit_reorder & crc;
    return result;
  end; -- function usb_packet_gen
end package body;
