-- (c) EMARD
-- License=BSD

-- warning: this doesn't work yet for darfon keyboard

library ieee;
use ieee.std_logic_1164.all;

use work.usb_req_gen_func_pack.ALL;

package hid_enum_pack is

-- USB enumeration sequence sniffed with wireshark
-- Saitek Cyborg Rumble Joystick
-- USB low-speed HID device

-- enumerate packet types
constant C_usbpacket_set: integer := 0;
constant C_usbpacket_read: integer := 1;

-- orig source
--constant ACK  :std_logic_vector(7 downto 0):="01001011";
--constant NACK :std_logic_vector(7 downto 0):="01011010";
--constant STALL:std_logic_vector(7 downto 0):="01110001";
--constant DATA1:std_logic_vector(7 downto 0):="11010010";
--constant DATA0:std_logic_vector(7 downto 0):="11000011";
--constant SETUP:std_logic_vector(7 downto 0):="10110100";
-- use e.g. SETUP in usb_data_gen(), reverse_any_vector(SETUP)

constant C_DATA0: std_logic_vector(7 downto 0) := "11000011"; -- DATA0 (warning in orig source is reversed bit order)

constant C_ADDR0_ENDP0: std_logic_vector(11+5-1 downto 0) := usb_token_gen("00000000000");
constant C_ADDR0_ENDP1: std_logic_vector(11+5-1 downto 0) := usb_token_gen("00010000000");
constant C_ADDR0_ENDP2: std_logic_vector(11+5-1 downto 0) := usb_token_gen("00100000000");
constant C_ADDR1_ENDP0: std_logic_vector(11+5-1 downto 0) := usb_token_gen("00000000001");
constant C_ADDR1_ENDP1: std_logic_vector(11+5-1 downto 0) := usb_token_gen("00010000001");


-- to generate this packages:
-- modprobe usbmon
-- chown user:user /dev/usbmon*
-- wireshark
-- plug joystick and move it or replug few times in/out
-- to find out which usbmon device receives its traffic, then select it to capture
-- plug joystick in
-- find 8-byte data from sniffed "URB setup" source host
-- e.g. 80 06 00 01 00 00 12 00 and copy it here as x"80_06_00_01_00_00_12_00":
-- and at the end of this file, modify state machine to replay those packets to the joystick

constant C_GET_DESCRIPTOR_DEVICE_40h  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"80_06_00_01_00_00_40_00");
constant C_URB_CONTROL_OUT_3_4h       : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"23_03_04_00_01_00_00_00");
constant C_URB_CONTROL_IN_4h          : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"A3_00_00_00_01_00_04_00");
constant C_URB_CONTROL_OUT_1_14h      : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"23_01_14_00_01_00_00_00");
constant C_GET_DESCRIPTOR_DEVICE_12h  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"80_06_00_01_00_00_12_00");
constant C_GET_DESCRIPTOR_CONFIG_09h  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"80_06_00_02_00_00_09_00");
constant C_GET_DESCRIPTOR_CONFIG_3Bh  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"80_06_00_02_00_00_3B_00");
constant C_GET_DESCRIPTOR_STRING_0_FFh: std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"80_06_00_03_00_00_FF_00");
constant C_GET_DESCRIPTOR_STRING_1_FFh: std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"80_06_01_03_09_04_FF_00");
constant C_GET_DESCRIPTOR_STRING_2_FFh: std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"80_06_02_03_09_04_FF_00");
constant C_SET_CONFIGURATION_1        : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"00_09_01_00_00_00_00_00");
constant C_SET_IDLE_0                 : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"21_0A_00_00_00_00_00_00");
constant C_GET_DESCRIPTOR_REPORT_41h  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"81_06_00_22_00_00_41_00");
constant C_SET_REPORT_200h            : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"21_09_00_02_00_00_01_00");
constant C_GET_DESCRIPTOR_REPORT_8Bh  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"81_06_00_22_00_00_8B_00");
-- final token that will read HID reports
constant C_PLUG_TOKEN: std_logic_vector(11+5-1 downto 0) := C_ADDR0_ENDP2;
constant bInterval: std_logic_vector(7 downto 0) := x"01"; -- HID report interval, lower value means faster


type T_usb_message is
record
    usbpacket:  integer range 0 to 1;          -- usb transmission mode set,read
    token:      std_logic_vector(15 downto 0); -- usb token 16-bit (5-bit crc included)
    data:       std_logic_vector(87 downto 0); -- usb data 88-bit (16-bit crc included)
end record;
type T_usb_enum_sequence is array (0 to 10) of T_usb_message;
constant C_usb_enum_sequence: T_usb_enum_sequence :=
  (
    ( -- 0
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_DEVICE_40h
    ),
    ( -- 1
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_DEVICE_12h
    ),
    ( -- 2
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_CONFIG_09h
    ),
    ( -- 3
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_CONFIG_3bh
    ),
    ( -- 4
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_STRING_0_FFh
    ),
    ( -- 5
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_STRING_1_FFh
    ),
    ( -- 6
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_STRING_2_FFh
    ),
    ( -- 7
      usbpacket =>  C_usbpacket_set,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_SET_CONFIGURATION_1
    ),
    ( -- 8
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_REPORT_41h
    ),
    ( -- 9
      usbpacket =>  C_usbpacket_set,
      token     =>  C_ADDR0_ENDP0,
      --data      =>  C_SET_REPORT_200h -- problem, stops after this
      data      =>  C_SET_CONFIGURATION_1 -- this one passes
    ),
    ( -- 10
      usbpacket =>  C_usbpacket_read,
      token     =>  C_ADDR0_ENDP0,
      data      =>  C_GET_DESCRIPTOR_REPORT_8Bh
    )
  );
end;