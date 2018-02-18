library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.usb_req_gen_func_pack.all;

entity USB_saitek is
    Port ( CLK7_5MHz : in  STD_LOGIC;
	 -- 60MHz=50*6/5 MHz -- 60/5=12 MHz
	--7.5MHz=50*6/40MHz --7.5/5=1.5MHz
           USB_DATA : inout  STD_LOGIC_VECTOR (1 downto 0);
			  PLAGE:in std_logic_vector(2 downto 0):=(others=>'0');
			  joystick_left:out std_logic;
			  joystick_right:out std_logic;
			  joystick_up:out std_logic;
			  joystick_down:out std_logic;
			  joystick_button1:out std_logic;
			  joystick_button2:out std_logic;
			  joystick_button3:out std_logic;
			  joystick_button4:out std_logic;
           LEDS : out  STD_LOGIC_VECTOR (7 downto 0));
end USB_saitek;

architecture Behavioral of USB_saitek is

constant UN:std_logic_vector(1 downto 0):="01"; --lowspeed
constant ZERO:std_logic_vector(1 downto 0):="10"; --lowspeed
constant EOP:std_logic_vector(1 downto 0):="00";
constant IDLE:std_logic_vector(1 downto 0):=UN;
constant bInterval:std_logic_vector(7 downto 0):=x"0A";

function bit2data(b:std_logic) return std_logic_vector is
begin
	if b='0' then
		return ZERO;
	else
		return UN;
	end if;
end function;

function data2bit(d:std_logic_vector(1 downto 0)) return std_logic is
begin
	if d=ZERO then
		return '0';
	else
		return '1';
	end if;
end function;
	

constant SYNCHRO:std_logic_vector(7 downto 0):="01010100";

constant ACK  :std_logic_vector(7 downto 0):="01001011";
constant NACK :std_logic_vector(7 downto 0):="01011010";
constant STALL:std_logic_vector(7 downto 0):="01110001";
constant DATA1:std_logic_vector(7 downto 0):="11010010";
constant DATA0:std_logic_vector(7 downto 0):="11000011";
constant SETUP:std_logic_vector(7 downto 0):="10110100";

constant ADDR0_ENDP0:std_logic_vector(11+5-1 downto 0):="00000000000" & "01000";
constant ADDR1_ENDP0:std_logic_vector(11+5-1 downto 0):="10000000000" & "10111";
constant ADDR1_ENDP1:std_logic_vector(11+5-1 downto 0):="10000001000" & "11010";

constant GET_DESCRIPTOR_DEVICE_40h   :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000001" & "01100000" & "00000000"&"10000000" & "00000000"&"00000000" & "00000010"&"00000000" & "1011101100101001";
constant SET_ADDRESS_1		     :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000000" & "10100000" & "10000000"&"00000000" & "00000000"&"00000000" & "00000000"&"00000000" & "1101011110100100";
constant GET_DESCRIPTOR_DEVICE_12h   :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000001" & "01100000" & "00000000"&"10000000" & "00000000"&"00000000" & "01001000"&"00000000" & "0000011100101111";
constant GET_DESCRIPTOR_CONFIG_FFh   :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000001" & "01100000" & "00000000"&"01000000" & "00000000"&"00000000" & "11111111"&"00000000" & "1001011100100101";
constant GET_DESCRIPTOR_STRING_0_FFh :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000001" & "01100000" & "00000000"&"11000000" & "00000000"&"00000000" & "11111111"&"00000000" & "0010101100100110";
constant GET_DESCRIPTOR_STRING_2_FFh :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000001" & "01100000" & "01000000"&"11000000" & "10010000"&"00100000" & "11111111"&"00000000" & "1110100111011011";
constant GET_DESCRIPTOR_CONFIG_09h   :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000001" & "01100000" & "00000000"&"01000000" & "00000000"&"00000000" & "10010000"&"00000000" & "0111010100100000";
constant GET_DESCRIPTOR_CONFIG_29h   :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000001" & "01100000" & "00000000"&"01000000" & "00000000"&"00000000" & "10010100"&"00000000" & "1110110100100011";
constant SET_CONFIGURATION_1	     :std_logic_vector(11*8-1 downto 0):=DATA0 & "00000000" & "10010000" & "10000000"&"00000000" & "00000000"&"00000000" & "00000000"&"00000000" & "1110010010100100";
constant GET_INTERFACE_0	     :std_logic_vector(11*8-1 downto 0):=DATA0 & "10000100" & "01010000" & "00000000"&"00000000" & "00000000"&"00000000" & "00000000"&"00000000" & "0110101100000100";
constant GET_DESCRIPTOR_REPORT_B7h   :std_logic_vector(11*8-1 downto 0):=DATA0 & "10000001" & "01100000" & "00000000"&"01000100" & "00000000"&"00000000" & "11101101"&"00000000" & "1111100111110101";

-- saitek cyborg joystick constants using packet generator function
constant C_DATA0: std_logic_vector(7 downto 0) := reverse_any_vector(DATA0); -- DATA0 is reversed bit order
-- modprobe usbmon
-- chown user:user /dev/usbmon*
-- wireshark
-- plug joystick and move it or replug few times in/out
-- to find out which usbmon device receives its traffic, then select it to capture
-- plug joystick in
-- find 8-byte data from sniffed "URB setup" source host
-- e.g. 80 06 00 01 00 00 12 00 and copy it here as x"8006000100001200":
-- and at the end of this file, configure state machine to replay all packets to the joystick
constant C_GET_DESCRIPTOR_DEVICE_40h  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"8006000100004000");
constant C_GET_DESCRIPTOR_DEVICE_12h  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"8006000100001200");
constant C_GET_DESCRIPTOR_CONFIG_09h  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"8006000200000900");
constant C_GET_DESCRIPTOR_CONFIG_29h  : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"8006000200002900");
constant C_GET_DESCRIPTOR_STRING_0_FFh: std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"800600030000FF00");
constant C_GET_DESCRIPTOR_STRING_1_FFh: std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"800601030904FF00");
constant C_GET_DESCRIPTOR_STRING_2_FFh: std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"800602030904FF00");
constant C_SET_CONFIGURATION_1        : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"0009010000000000");
constant C_SET_IDLE_0                 : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"210a000000000000");
constant C_GET_DESCRIPTOR_REPORT_277h : std_logic_vector(11*8-1 downto 0) := usb_data_gen(C_DATA0 & x"8106002200007702");
constant C_ADDR0_ENDP0                : std_logic_vector(11+5-1 downto 0) := usb_token_gen("00000000000");
constant C_ADDR0_ENDP1                : std_logic_vector(11+5-1 downto 0) := usb_token_gen("00010000000");
constant C_ADDR1_ENDP0                : std_logic_vector(11+5-1 downto 0) := usb_token_gen("00000000001");
constant C_ADDR1_ENDP1                : std_logic_vector(11+5-1 downto 0) := usb_token_gen("00010000001");
--

constant OUT_OUT:std_logic_vector(7 downto 0):="10000111";
constant OUT_DATA1:std_logic_vector(3*8-1 downto 0):=DATA1 & "0000000000000000";




--constant GET_DESCRIPTOR_CONFIG_SETUP:std_logic_vector(3*8-1 downto 0):="10110100" & "10000000"&"000" & "10111";
--constant GET_DESCRIPTOR_CONFIG_SETUP_DATA0:std_logic_vector(11*8-1 downto 0):="11000011" & "00000001"&"01100000" & "00000000"&"01000000" & "00000000"&"00000000" & "10010000"&"00000000" & "0111010100100000";
--constant GET_DESCRIPTOR_CONFIG_SETUP_DATA0:std_logic_vector(11*8-1 downto 0):="11000011" & "00000001"&"01100000" & "00000000"&"01000000" & "00000000"&"00000000" & "10010100"&"00000000" & "1110110100100011";

constant SOF:std_logic_vector(7 downto 0):="10100101"; -- non NRZI

constant IN_IN:std_logic_vector(7 downto 0):="10010110";

constant period_RESET:integer:=1486684; --100-200ms >1486684< + 96147; --

constant period_IDLE:integer:=409;
constant period_EOP:integer:=1;

constant period_SOF:integer:=12000; --11890+8+3*8+2; --11924

constant PAS:integer:=5;
constant DEMI_PAS:integer:=2;--5/2;

constant TIME_OUT:integer:=8; -- 7.5bit

constant REPORT_LEN:integer:=9; -- bytes report length

signal step_ps3_test:integer range 0 to 11:=0;

signal step_cmd: integer range 0 to 12 := 0;

begin

process(CLK7_5MHz) is
	variable step_ps3:integer range 0 to 41:=0;
	-- variable step_cmd:integer range 0 to 12:=0;
	variable next_cmd:boolean:=false;
	variable counter_RESET:integer range 0 to period_RESET*PAS:=0;
	variable counter_IDLE:integer range 0 to period_IDLE+period_EOP:=0;
	variable counter_PAS:integer range 0 to PAS:=0;
	variable counter_SOF_stuff:integer range 0 to period_SOF:=0;
	
	variable counter_TRAME:integer:=0;
	
	variable last_USB_DATA:std_logic_vector(1 downto 0):=EOP;
	variable mode_receive:boolean:=false;
	variable JOY_mem:std_logic_vector(8*REPORT_LEN-1 downto 0):=(others=>'0');
	variable JOY_CANDIDATE_mem:std_logic_vector(8*REPORT_LEN-1 downto 0):=(others=>'0');
	constant DATA_MAX_SIZE:integer:=8*REPORT_LEN;
	variable SIZE_mem:std_logic_vector(7 downto 0):=(others=>'0');
	variable PID_mem:std_logic_vector(7 downto 0):=(others=>'0');
	variable CRC16_mem:std_logic_vector(15 downto 0):=(others=>'0');
	
	variable frame_number:std_logic_vector(10 downto 0):=(others=>'0');
	
	variable crc5_value:std_logic_vector(4 downto 0);
	procedure crc5_init is
	begin
		crc5_value:=(others=>'1');
	end procedure;
	subtype crc5_result is STD_LOGIC_VECTOR(4 downto 0);
	function crc5(d:std_logic;crc5:std_logic_vector(4 downto 0)) return crc5_result is
		variable a:std_logic;
		variable b:std_logic;
		variable crc:std_logic_vector(4 downto 0);
	begin
		crc:=crc5; -- fronti�re pour a=f(a);
		b:=d; -- fronti�re (parano ?)
		a:=crc(4) xor b;
		crc:=crc(3 downto 0) & a;
		crc(2):=crc(2) xor a;
		return crc;
	end function;
	
	
	--x^16+x^15+x^2+1
	variable crc16_value:std_logic_vector(15 downto 0);
	procedure crc16_init is
	begin
		crc16_value:=(others=>'1');
	end procedure;
	subtype crc16_result is STD_LOGIC_VECTOR(15 downto 0);
	function crc16(d:std_logic;crc16:std_logic_vector(15 downto 0)) return crc16_result is
		variable a:std_logic;
		variable b:std_logic;
		variable crc:std_logic_vector(15 downto 0);
	begin
		crc:=crc16; -- fronti�re pour a=f(a);
		b:=d; -- fronti�re (parano ?)
		a:=crc(15) xor b;
		crc:=crc(14 downto 0) & a;
		crc(2):=crc(2) xor a;
		crc(15):=crc(15) xor a;
		return crc;
	end function;
	
	variable last_nrzi:std_logic;
	variable result:std_logic;
	procedure nrzi(d:std_logic;last_nrzi : inout std_logic;result: out std_logic) is
	begin
		if d='1' then
			--no change level
			result:=last_nrzi;
		else
			--change level
			last_nrzi:=not(last_nrzi);
			result:=last_nrzi;
		end if;
	end procedure;
	procedure nrzi_inv(d:std_logic;last_nrzi : inout std_logic;result: out std_logic) is
	begin
		if d=last_nrzi then
			--no change level
			result:='1';
		else
			--change level
			result:='0';
			last_nrzi:=d;
		end if;
	end procedure;
	
	
	
	variable zap:boolean:=false;
	variable counter6:integer range 0 to 5:=0;
	procedure stuff_init is
	begin
		counter6:=1;
	end procedure;
	procedure stuff(b:std_logic) is
	begin
		if b='1' then
			if counter6=5 then	
				counter6:=0;
				zap:=true;
			else
				counter6:=counter6+1;
			end if;
		else
			counter6:=0;
		end if;
	end procedure;
	
	variable sleep:boolean:=false;
	variable counter_sleep:integer:=0;
	procedure pause(p:integer) is
	begin
		sleep:=true;
		counter_sleep:=p;
	end procedure;
	
	variable time_out:boolean:=false;
	
	procedure sof_init is
	begin
		counter_RESET:=0;
--		counter_IDLE:=0;
		counter_SOF_stuff:=0;
		counter_TRAME:=0;
		counter_PAS:=0;
		mode_receive:=false;
	end procedure;
		
		
	procedure nrzi_init is
	begin
		last_nrzi:='0';
	end procedure;


	variable TRAME_GET_SETUP:std_logic_vector(8+11+5-1 downto 0):=SETUP & ADDR0_ENDP0;
	variable TRAME_GET_DATA0:std_logic_vector(11*8-1 downto 0):=GET_DESCRIPTOR_DEVICE_40h;
	variable IN_ADDR_ENDP:std_logic_vector(8+11+5-1 downto 0):=IN_IN & ADDR0_ENDP0;
	variable OUT_ADDR_ENDP:std_logic_vector(8+11+5-1 downto 0):=OUT_OUT & ADDR1_ENDP1;
	variable TRAME_OUT_DATA1:std_logic_vector(3*8-1 downto 0):=OUT_DATA1;
	variable TRAME_OUT_DATA1_length:integer range 0 to TRAME_OUT_DATA1'length:=0;
	procedure trame_read(ADDR_ENDP:std_logic_vector(11+5-1 downto 0); DATA:std_logic_vector(11*8-1 downto 0)) is
	begin
		TRAME_GET_SETUP:=SETUP & ADDR_ENDP;
		TRAME_GET_DATA0:=DATA;
		IN_ADDR_ENDP:=IN_IN & ADDR_ENDP;
		OUT_ADDR_ENDP:=OUT_OUT & ADDR_ENDP;
		TRAME_OUT_DATA1_length:=OUT_DATA1'length;
		TRAME_OUT_DATA1:=(others=>'0');
		TRAME_OUT_DATA1(TRAME_OUT_DATA1_length-1 downto 0):=OUT_DATA1;
		step_ps3:=18;
	end procedure;
	

	variable TRAME_SET_SETUP:std_logic_vector(8+11+5-1 downto 0):=SETUP & ADDR0_ENDP0;
	variable TRAME_SET_DATA0:std_logic_vector(11*8-1 downto 0):=SET_ADDRESS_1;
	procedure trame_set(ADDR_ENDP:std_logic_vector(11+5-1 downto 0); DATA:std_logic_vector(11*8-1 downto 0)) is
	begin
		TRAME_SET_SETUP:=SETUP & ADDR_ENDP;
		TRAME_SET_DATA0:=DATA;
		IN_ADDR_ENDP:=IN_IN & ADDR_ENDP;
		step_ps3:=7;
	end procedure;

	procedure plug(ADDR_ENDP:std_logic_vector(11+5-1 downto 0)) is
	begin
		IN_ADDR_ENDP:=IN_IN & ADDR_ENDP;
		
		step_ps3:=34;
	end procedure;

	variable interval:std_logic_vector(7 downto 0):=(others=>'0');
	
	variable joystick_left_mem:std_logic:='0';
	variable joystick_right_mem:std_logic:='0';
	variable joystick_up_mem:std_logic:='0';
	variable joystick_down_mem:std_logic:='0';
	variable joystick_button1_mem:std_logic:='0';
	variable joystick_button2_mem:std_logic:='0';
	variable joystick_button3_mem:std_logic:='0';
	variable joystick_button4_mem:std_logic:='0';
	
	
	
begin
step_ps3_test<=step_ps3;
if rising_edge(CLK7_5MHz) then

	LEDS(3 downto 0)<=conv_std_logic_vector(step_cmd,8)(3 downto 0);
	--LEDS<=conv_std_logic_vector(step_ps3,8);

	for i in 4 to 7 loop
	  --LEDS(i)<=JOY_mem(i + 8*conv_integer(PLAGE));
	  LEDS(i)<= JOY_mem(i + 8*0)
	        xor JOY_mem(i + 8*1)
	        xor JOY_mem(i + 8*2)
	        xor JOY_mem(i + 8*3)
	        xor JOY_mem(i + 8*4)
	        xor JOY_mem(i + 8*5)
	        xor JOY_mem(i + 8*6)
	        xor JOY_mem(i + 8*7);
	end loop;

	joystick_left<=joystick_left_mem;
	joystick_right<=joystick_right_mem;
	joystick_up<=joystick_up_mem;
	joystick_down<=joystick_down_mem;
	joystick_button1<=joystick_button1_mem;
	joystick_button2<=joystick_button2_mem;
	joystick_button3<=joystick_button3_mem;
	joystick_button4<=joystick_button4_mem;
	
	if zap then
		if counter_PAS=DEMI_PAS then
			if mode_receive then
				--nrzi('0',last_nrzi,result);
				nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
				if result='0' then
					--cool
				else
					-- pas cool
crc16_value:=(others=>'0');
crc5_value:=(others=>'0');
-- TRAMES TROP LONGUE POUR TOLERER FATAL ERROR step_ps3:=2;
				end if;
			else
				nrzi('0',last_nrzi,result);
				USB_DATA<=bit2data(result);
			end if;
			zap:=false;
		end if;
	elsif sleep then
		if counter_PAS=DEMI_PAS then
			USB_DATA<="ZZ";
			counter_sleep:=counter_sleep-1;
			if counter_sleep=0 then
				sleep:=false;
			end if;
		end if;
	elsif time_out then
		mode_receive:=false;
		if counter_IDLE=0 then
			USB_DATA<=EOP;
		else
			USB_DATA<=UN;
		end if;
		if counter_SOF_stuff=0 then
			time_out:=false;
			sof_init;
		end if;
	else
		case step_ps3 is
			--=========
			-- CONNECT
			--=========
			when 0=>
				USB_DATA<="ZZ";
				step_ps3:=3;
			when 1=> -- test
			when 2=> -- erreur zap en mode_receive
			when 3=>
				if USB_DATA=UN then
					step_ps3:=4;
				end if;
--step_ps3:=4; -- FOR TESTBENCH
			--=======
			-- RESET
			--=======
			when 4=>
				USB_DATA<=EOP;
				if counter_RESET=period_RESET*PAS-1 then
					counter_RESET:=0;
					step_ps3:=5;
					USB_DATA<="ZZ";
				else
					counter_RESET:=counter_RESET+1;
				end if;
			when 5=>
				-- end of reset
				if USB_DATA=UN then
					step_ps3:=6;
				end if;
			when 6=>
				USB_DATA<=UN;
				if counter_RESET=10*PAS-1 then
					step_ps3:=1;
					next_cmd:=true;
					sof_init;
				else
					counter_RESET:=counter_RESET+1;
				end if;
			


			--=====================================================
			-- TRAME SET (SOF,TRAME_SET_SETUP,TRAME_SET_DATA0,ACK)
			--=====================================================
			when 7=>
			--PID_SOF
				--frame_number 0 to 11
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						stuff(SOF(8+8 -1-counter_TRAME));
						nrzi(SOF(8+8 -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_init;
					elsif counter_TRAME<8+8+11 then -- stuff osef (si �a passe pas, �a passe pas)
						stuff(frame_number(counter_TRAME-8-8));
						nrzi(frame_number(counter_TRAME-8-8),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_value:=crc5(frame_number(counter_TRAME-8-8),crc5_value);
					elsif counter_TRAME<8+8+11+5 then
						-- reverse and inverse
						stuff(not(crc5_value(8+8+11+5 -1-counter_TRAME)));
						nrzi(not(crc5_value(8+8+11+5 -1-counter_TRAME)),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+8+11+5+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+8+11+5+2+3 then
						USB_DATA<="ZZ";
					else
						counter_TRAME:=0;
						frame_number:=frame_number+1;
						step_ps3:=8;
					end if;
					if step_ps3=7 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 8=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+TRAME_SET_SETUP'length then
						stuff(TRAME_SET_SETUP(8+TRAME_SET_SETUP'length -1-counter_TRAME));
						nrzi(TRAME_SET_SETUP(8+TRAME_SET_SETUP'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+TRAME_SET_SETUP'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+TRAME_SET_SETUP'length+2+5 then -- on va dire 5 � la place de 3 IDLE
						USB_DATA<=UN;
					elsif counter_TRAME<8+TRAME_SET_SETUP'length+2+5 +8 then
						USB_DATA<=bit2data(SYNCHRO(8+TRAME_SET_SETUP'length+2+5 +8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+TRAME_SET_SETUP'length+2+5 +8+TRAME_SET_DATA0'length then
						stuff(TRAME_SET_DATA0(8+TRAME_SET_SETUP'length+2+5 +8+TRAME_SET_DATA0'length -1-counter_TRAME));
						nrzi(TRAME_SET_DATA0(8+TRAME_SET_SETUP'length+2+5 +8+TRAME_SET_DATA0'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+TRAME_SET_SETUP'length+2+5 +8+TRAME_SET_DATA0'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+TRAME_SET_SETUP'length+2+5 +8+TRAME_SET_DATA0'length+2+1 then
						USB_DATA<=UN;
					elsif counter_TRAME<8+TRAME_SET_SETUP'length+2+5 +8+TRAME_SET_DATA0'length+2+1+1 then
						USB_DATA<="ZZ";
					elsif counter_TRAME<8+TRAME_SET_SETUP'length+2+5 +8+TRAME_SET_DATA0'length+2+1+1 +8 then
						-- TIME_OUT ?
						step_ps3:=9;
					else
						counter_TRAME:=0;
						time_out:=true;
						step_ps3:=7; -- next SOF
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
			when 9=> --
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8+TRAME_SET_SETUP'length+2+5 +8+TRAME_SET_DATA0'length+2+1+1 +8 then
						USB_DATA<="ZZ";
					else
						-- TIME_OUT
						step_ps3:=8;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
				
				if USB_DATA=ZERO then
					last_USB_DATA:=EOP;-- not(USB_DATA=ZERO)
					mode_receive:=true;
					step_ps3:=10;
					counter_TRAME:=0;
					counter_PAS:=0;
				end if;
			when 10=> -- reception ACK ????
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						if not(SYNCHRO(8 -1-counter_TRAME)=data2bit(USB_DATA)) then
							-- pas cool
							step_ps3:=11;counter_TRAME:=0;mode_receive:=false;
						end if;
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+ACK'length then
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						if not(result=ACK(8+ACK'length -1-counter_TRAME)) then
							-- pas cool
							step_ps3:=11;counter_TRAME:=0;mode_receive:=false;
						end if;
					else
						pause(5);
						time_out:=true;
						step_ps3:=12; --next INSTRUCTION
					end if;
					if step_ps3=10 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 11=>
				-- wait EOP
				if counter_PAS=DEMI_PAS and USB_DATA=EOP then -- DEMI_PAS ? plus long ??? ne pas rendre un "entre deux �tats"
					pause(5);
					time_out:=true;
					step_ps3:=7; --next SOF
				end if;
			--==================================
			-- TRAME SET (SOF,IN_ADDR_ENDP,ACK)
			--==================================
			when 12=>
			--PID_SOF
				--frame_number 0 to 11
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						stuff(SOF(8+8 -1-counter_TRAME));
						nrzi(SOF(8+8 -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_init;
					elsif counter_TRAME<8+8+11 then -- stuff osef (si �a passe pas, �a passe pas)
						stuff(frame_number(counter_TRAME-8-8));
						nrzi(frame_number(counter_TRAME-8-8),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_value:=crc5(frame_number(counter_TRAME-8-8),crc5_value);
					elsif counter_TRAME<8+8+11+5 then
						-- reverse and inverse
						stuff(not(crc5_value(8+8+11+5 -1-counter_TRAME)));
						nrzi(not(crc5_value(8+8+11+5 -1-counter_TRAME)),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+8+11+5+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+8+11+5+2+3 then
						USB_DATA<="ZZ";
					else
						counter_TRAME:=0;
						frame_number:=frame_number+1;
						step_ps3:=13;
					end if;
					if step_ps3=12 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 13=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length then
						stuff(IN_ADDR_ENDP(8+IN_ADDR_ENDP'length -1-counter_TRAME));
						nrzi(IN_ADDR_ENDP(8+IN_ADDR_ENDP'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1 then
						USB_DATA<=UN;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 then
						USB_DATA<="ZZ";
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 +8 then
						-- TIME_OUT ?
						step_ps3:=14;
					else
						step_ps3:=12;-- next SOF
						time_out:=true;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
			when 14=> --
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 +8*10 then
						USB_DATA<="ZZ";
					else
						-- TIME_OUT
						step_ps3:=13;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
				
				if USB_DATA=ZERO then
					last_USB_DATA:=EOP;-- not(USB_DATA=ZERO)
					mode_receive:=true;
					step_ps3:=15;
					counter_TRAME:=0;
					counter_PAS:=0;
				end if;
			when 15=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						if not(SYNCHRO(8 -1-counter_TRAME)=data2bit(USB_DATA)) then
							-- pas cool
							step_ps3:=16;counter_TRAME:=0;mode_receive:=false;
						end if;
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						PID_mem(8+8 -1-counter_TRAME):=result;
						if counter_TRAME=8+8-1 then
							if PID_mem=DATA1 then
								-- cool
							elsif PID_mem=NACK then
								-- pas cool : attendre
								step_ps3:=16;counter_TRAME:=0;mode_receive:=false;
							else -- STALL or DATA0
								-- pas cool : reset cmd
								step_ps3:=11;counter_TRAME:=0;mode_receive:=false;
							end if;
						end if;
					elsif USB_DATA=EOP then
						SIZE_mem:=conv_std_logic_vector(counter_TRAME-16-16,8); -- NO_DATA=0
						counter_TRAME:=0;
						pause(5);
						mode_receive:=false;
						step_ps3:=17;
					else
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						-- DATA & CRC16
					end if;
					if step_ps3=15 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 16=>
				-- wait EOP
				if USB_DATA=EOP and counter_PAS=DEMI_PAS then
					pause(5);
					time_out:=true;
					step_ps3:=12; -- next SOF
				end if;
			when 17=>
				-- envoyer un ACK
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+ACK'length then
						stuff(ACK(8+ACK'length -1-counter_TRAME));
						nrzi(ACK(8+ACK'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+ACK'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+ACK'length+2+1 then
						USB_DATA<=UN;
					else
						pause(3);
						time_out:=true;
						step_ps3:=1;-- next SOF next INSTRUCTION
						next_cmd:=true;
					end if;
					if step_ps3=17 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;







			--========================================================
			-- TRAME_GET (SOF, TRAME_GET_SETUP, TRAME_GET_DATA0, ACK)
			--========================================================
			when 18=>
			--PID_SOF
				--frame_number 0 to 11
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						stuff(SOF(8+8 -1-counter_TRAME));
						nrzi(SOF(8+8 -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_init;
					elsif counter_TRAME<8+8+11 then -- stuff osef (si �a passe pas, �a passe pas)
						stuff(frame_number(counter_TRAME-8-8));
						nrzi(frame_number(counter_TRAME-8-8),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_value:=crc5(frame_number(counter_TRAME-8-8),crc5_value);
					elsif counter_TRAME<8+8+11+5 then
						-- reverse and inverse
						stuff(not(crc5_value(8+8+11+5 -1-counter_TRAME)));
						nrzi(not(crc5_value(8+8+11+5 -1-counter_TRAME)),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+8+11+5+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+8+11+5+2+3 then
						USB_DATA<="ZZ";
					else
						counter_TRAME:=0;
						frame_number:=frame_number+1;
						step_ps3:=19;
					end if;
					if step_ps3=18 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 19=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+TRAME_GET_SETUP'length then
						stuff(TRAME_GET_SETUP(8+TRAME_GET_SETUP'length -1-counter_TRAME));
						nrzi(TRAME_GET_SETUP(8+TRAME_GET_SETUP'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+TRAME_GET_SETUP'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+TRAME_GET_SETUP'length+2+5 then -- on va dire 5 � la place de 3 IDLE
						USB_DATA<=UN;
					elsif counter_TRAME<8+TRAME_GET_SETUP'length+2+5 +8 then
						USB_DATA<=bit2data(SYNCHRO(8+TRAME_GET_SETUP'length+2+5 +8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+TRAME_GET_SETUP'length+2+5 +8+TRAME_GET_DATA0'length then
						stuff(TRAME_GET_DATA0(8+TRAME_GET_SETUP'length+2+5 +8+TRAME_GET_DATA0'length -1-counter_TRAME));
						nrzi(TRAME_GET_DATA0(8+TRAME_GET_SETUP'length+2+5 +8+TRAME_GET_DATA0'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+TRAME_GET_SETUP'length+2+5 +8+TRAME_GET_DATA0'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+TRAME_GET_SETUP'length+2+5 +8+TRAME_GET_DATA0'length+2+1 then
						USB_DATA<=UN;
					elsif counter_TRAME<8+TRAME_GET_SETUP'length+2+5 +8+TRAME_GET_DATA0'length+2+1+1 then
						USB_DATA<="ZZ";
					elsif counter_TRAME<8+TRAME_GET_SETUP'length+2+5 +8+TRAME_GET_DATA0'length+2+1+1 +8 then
						-- TIME_OUT ?
						step_ps3:=20;
					else
						counter_TRAME:=0;
						time_out:=true;
						step_ps3:=18; -- next SOF
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
			when 20=> --
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8+TRAME_GET_SETUP'length+2+5 +8+TRAME_GET_DATA0'length+2+1+1 +8 then
						USB_DATA<="ZZ";
					else
						-- TIME_OUT
						step_ps3:=19;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
				
				if USB_DATA=ZERO then
					last_USB_DATA:=EOP;-- not(USB_DATA=ZERO)
					mode_receive:=true;
					step_ps3:=21;
					counter_TRAME:=0;
					counter_PAS:=0;
				end if;
			when 21=> -- reception ACK
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						if not(SYNCHRO(8 -1-counter_TRAME)=data2bit(USB_DATA)) then
							-- pas cool
							step_ps3:=22;counter_TRAME:=0;mode_receive:=false;
						end if;
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+ACK'length then
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						if not(result=ACK(8+ACK'length -1-counter_TRAME)) then
							-- pas cool
							step_ps3:=22;counter_TRAME:=0;mode_receive:=false;
						end if;
					else
						pause(5);
						time_out:=true;
							step_ps3:=23; --24; next INSTRUCTION
					end if;
					if step_ps3=21 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 22=>
				-- wait EOP
				if USB_DATA=EOP and counter_PAS=DEMI_PAS then
					pause(5);
					time_out:=true;
					step_ps3:=18; -- next SOF
				end if;
			--========================
			-- TRAME_GET (SOF,IN_ADDR_ENDP,ACK)
			--========================
			when 23=>
			--PID_SOF
				--frame_number 0 to 11
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						stuff(SOF(8+8 -1-counter_TRAME));
						nrzi(SOF(8+8 -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_init;
					elsif counter_TRAME<8+8+11 then -- stuff osef (si �a passe pas, �a passe pas)
						stuff(frame_number(counter_TRAME-8-8));
						nrzi(frame_number(counter_TRAME-8-8),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_value:=crc5(frame_number(counter_TRAME-8-8),crc5_value);
					elsif counter_TRAME<8+8+11+5 then
						-- reverse and inverse
						stuff(not(crc5_value(8+8+11+5 -1-counter_TRAME)));
						nrzi(not(crc5_value(8+8+11+5 -1-counter_TRAME)),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+8+11+5+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+8+11+5+2+3 then
						USB_DATA<="ZZ";
					else
						counter_TRAME:=0;
						frame_number:=frame_number+1;
						step_ps3:=24;
					end if;
					if step_ps3=23 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 24=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length then
						stuff(IN_ADDR_ENDP(8+IN_ADDR_ENDP'length -1-counter_TRAME));
						nrzi(IN_ADDR_ENDP(8+IN_ADDR_ENDP'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1 then
						USB_DATA<=UN;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 then
						USB_DATA<="ZZ";
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 +8 then
						-- TIME_OUT ?
						step_ps3:=25;
					else
						step_ps3:=23;-- next SOF
						time_out:=true;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
			when 25=> --
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 +8*10 then
						USB_DATA<="ZZ";
					else
						-- TIME_OUT
						step_ps3:=24;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
				
				if USB_DATA=ZERO then
					last_USB_DATA:=EOP;-- not(USB_DATA=ZERO)
					mode_receive:=true;
					step_ps3:=26;
					counter_TRAME:=0;
					counter_PAS:=0;
				end if;
			when 26=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						if not(SYNCHRO(8 -1-counter_TRAME)=data2bit(USB_DATA)) then
							-- pas cool
							step_ps3:=27;counter_TRAME:=0;mode_receive:=false;
						end if;
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						PID_mem(8+8 -1-counter_TRAME):=result;
						if counter_TRAME=8+8-1 then
							crc16_init;
							if PID_mem=DATA1 or PID_mem=DATA0 then
								-- cool
							elsif PID_mem=NACK then
								-- pas cool : attendre
								step_ps3:=27;counter_TRAME:=0;mode_receive:=false;
							else -- STALL
								-- pas cool : reset cmd
								step_ps3:=22;counter_TRAME:=0;mode_receive:=false;
							end if;
						end if;
					elsif USB_DATA=EOP then
						SIZE_mem:=conv_std_logic_vector(counter_TRAME-16-16,8);
						counter_TRAME:=0;
						pause(5);
						mode_receive:=false;
						step_ps3:=28;
						if conv_integer(SIZE_mem)>0 then
							for i in 0 to 15 loop
								CRC16_mem(i):=not(CRC16_mem(i));
							end loop;
							if not(CRC16_mem=crc16_value) then
								step_ps3:=41; -- 40 IS NACK AND THEN TIME_OUT
							else
								--JOY_mem:=JOY_CANDIDATE_mem;
							end if;
						end if;
					else
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						if counter_TRAME>=8+8+16 then
							crc16_value:=crc16(CRC16_mem(15),crc16_value);
						end if;
						CRC16_mem:=CRC16_mem(14 downto 0) & result;
						-- DATA & CRC16


--						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
--						stuff(result);
						-- DATA & CRC16
					end if;
					if step_ps3=26 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 27=>
				-- wait EOP
				if USB_DATA=EOP and counter_PAS=DEMI_PAS then
					pause(5);
					time_out:=true;
					step_ps3:=23; -- next SOF
				end if;
			when 28=>
				-- envoyer un ACK
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+ACK'length then
						stuff(ACK(8+ACK'length -1-counter_TRAME));
						nrzi(ACK(8+ACK'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+ACK'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+ACK'length+2+1 then
						USB_DATA<=UN;
					else
						pause(3);
						time_out:=true;
						if conv_integer(SIZE_mem)=DATA_MAX_SIZE then
							--encore !
							step_ps3:=23; -- next SOF
						else
							--merci et au revoir
							--step_ps3:=1;
							step_ps3:=29; -- next SOF next INSTRUCTION
						end if;
					end if;
					if step_ps3=28 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;				
				
				
				
				
				
				
			when 41=>
				-- envoyer un NACK
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+NACK'length then
						stuff(NACK(8+NACK'length -1-counter_TRAME));
						nrzi(NACK(8+NACK'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+NACK'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+NACK'length+2+1 then
						USB_DATA<=UN;
					else
						pause(3);
						time_out:=true;
						--encore !
						step_ps3:=23; -- next SOF
					end if;
					if step_ps3=41 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			--========================
			-- TRAME_GET (SOF,OUT_ADDR_ENDP,OUT_DATA1,ACK)
			--========================
			when 29=>
			--PID_SOF
				--frame_number 0 to 11
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						stuff(SOF(8+8 -1-counter_TRAME));
						nrzi(SOF(8+8 -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_init;
					elsif counter_TRAME<8+8+11 then -- stuff osef (si �a passe pas, �a passe pas)
						stuff(frame_number(counter_TRAME-8-8));
						nrzi(frame_number(counter_TRAME-8-8),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_value:=crc5(frame_number(counter_TRAME-8-8),crc5_value);
					elsif counter_TRAME<8+8+11+5 then
						-- reverse and inverse
						stuff(not(crc5_value(8+8+11+5 -1-counter_TRAME)));
						nrzi(not(crc5_value(8+8+11+5 -1-counter_TRAME)),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+8+11+5+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+8+11+5+2+3 then
						USB_DATA<="ZZ";
					else
						counter_TRAME:=0;
						frame_number:=frame_number+1;
						step_ps3:=30;
					end if;
					if step_ps3=29 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 30=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length then
						stuff(OUT_ADDR_ENDP(8+OUT_ADDR_ENDP'length -1-counter_TRAME));
						nrzi(OUT_ADDR_ENDP(8+OUT_ADDR_ENDP'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length+2+5 then -- on va dire 5 � la place de 3 IDLE
						USB_DATA<=UN;
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length+2+5 +8 then
						USB_DATA<=bit2data(SYNCHRO(8+OUT_ADDR_ENDP'length+2+5 +8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length+2+5 +8+TRAME_OUT_DATA1_length then
						stuff(TRAME_OUT_DATA1(8+OUT_ADDR_ENDP'length+2+5 +8+TRAME_OUT_DATA1_length -1-counter_TRAME));
						nrzi(TRAME_OUT_DATA1(8+OUT_ADDR_ENDP'length+2+5 +8+TRAME_OUT_DATA1_length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length+2+5 +8+TRAME_OUT_DATA1_length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length+2+5 +8+TRAME_OUT_DATA1_length+2+1 then
						USB_DATA<=UN;
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length+2+5 +8+TRAME_OUT_DATA1_length+2+1+1 then
						USB_DATA<="ZZ";
					elsif counter_TRAME<8+OUT_ADDR_ENDP'length+2+5 +8+TRAME_OUT_DATA1_length+2+1+1 +8 then
						-- TIME_OUT ?
						step_ps3:=31;
					else
						counter_TRAME:=0;
						time_out:=true;
						step_ps3:=29; -- next SOF
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
			when 31=> --
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8+OUT_ADDR_ENDP'length+2+5 +8+TRAME_OUT_DATA1_length+2+1+1 +8 then
						USB_DATA<="ZZ";
					else
						-- TIME_OUT
						step_ps3:=30;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
				
				if USB_DATA=ZERO then
					last_USB_DATA:=EOP;-- not(USB_DATA=ZERO)
					mode_receive:=true;
					step_ps3:=32;
					counter_TRAME:=0;
					counter_PAS:=0;
				end if;
			when 32=> -- reception ACK
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						if not(SYNCHRO(8 -1-counter_TRAME)=data2bit(USB_DATA)) then
							-- pas cool
							step_ps3:=33;counter_TRAME:=0;mode_receive:=false;
						end if;
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+ACK'length then
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						if not(result=ACK(8+ACK'length -1-counter_TRAME)) then
							-- pas cool
							step_ps3:=33;counter_TRAME:=0;mode_receive:=false;
						end if;
					else
						pause(5);
						time_out:=true;
							step_ps3:=1; -- next INSTRUCTION
							next_cmd:=true;
					end if;
					if step_ps3=32 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 33=>
				-- wait EOP
				if USB_DATA=EOP and counter_PAS=DEMI_PAS then
					pause(5);
					time_out:=true;
					step_ps3:=29; -- next SOF
				end if;
				
				
			
				

				
				
				
				
				
	











			
			
			
			--=============================
			-- PLUG (SOF,IN_ADDR_ENDP,ACK)
			--=============================
			-- toujours vide, non lanc� du coup
			when 34=>
			--PID_SOF
				--frame_number 0 to 11
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						stuff(SOF(8+8 -1-counter_TRAME));
						nrzi(SOF(8+8 -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_init;
					elsif counter_TRAME<8+8+11 then -- stuff osef (si �a passe pas, �a passe pas)
						stuff(frame_number(counter_TRAME-8-8));
						nrzi(frame_number(counter_TRAME-8-8),last_nrzi,result);
						USB_DATA<=bit2data(result);
						crc5_value:=crc5(frame_number(counter_TRAME-8-8),crc5_value);
					elsif counter_TRAME<8+8+11+5 then
						-- reverse and inverse
						stuff(not(crc5_value(8+8+11+5 -1-counter_TRAME)));
						nrzi(not(crc5_value(8+8+11+5 -1-counter_TRAME)),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+8+11+5+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+8+11+5+2+3 then
						USB_DATA<="ZZ";
					else
						counter_TRAME:=0;
						frame_number:=frame_number+1;
						
						if interval>bInterval+1 then
							interval:=x"00";
							step_ps3:=35;
						else
							interval:=interval+1;
							time_out:=true; -- wait next SOF
						end if;
						
					end if;
					if step_ps3=34 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 35=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length then
						stuff(IN_ADDR_ENDP(8+IN_ADDR_ENDP'length -1-counter_TRAME));
						nrzi(IN_ADDR_ENDP(8+IN_ADDR_ENDP'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1 then
						USB_DATA<=UN;
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 then
						USB_DATA<="ZZ";
					elsif counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 +8 then
						-- TIME_OUT ?
						step_ps3:=36;
					else
						step_ps3:=34;-- next SOF
						time_out:=true;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
			when 36=> --
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8+IN_ADDR_ENDP'length+2+1+1 +8*10 then
						USB_DATA<="ZZ";
					else
						-- TIME_OUT
						step_ps3:=35;
					end if;
					counter_TRAME:=counter_TRAME+1;
				end if;
				
				if USB_DATA=ZERO then
					last_USB_DATA:=EOP;-- not(USB_DATA=ZERO)
					mode_receive:=true;
					step_ps3:=37;
--JOY_mem:=JOY_mem+1;
					counter_TRAME:=0;
					counter_PAS:=0;
				end if;
			when 37=>
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						if not(SYNCHRO(8 -1-counter_TRAME)=data2bit(USB_DATA)) then
							-- pas cool
							step_ps3:=38;counter_TRAME:=0;mode_receive:=false;
						end if;
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+8 then
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						
						PID_mem(8+8 -1-counter_TRAME):=result;
						if counter_TRAME=8+8-1 then
							crc16_init;
							--JOY_mem:=PID_mem;
							if PID_mem=DATA0 or PID_mem=DATA1 then
								--cool
							elsif PID_mem=STALL then
							--	-- RESET ALL : mauvaise id�e : un reset �a prend du temps, ce n'est donc pas une r�action normale du syst�me
							--	counter_TRAME:=0;mode_receive:=false;	
							--	pause(5);
							--	time_out:=true;
							--	step_ps3:=0;-- next INSTRUCTION
							--	step_cmd:=0;
							--	next_cmd:=false;
								step_ps3:=2; -- death
							else
								-- pas cool : surement le NACK (ping failed)
								step_ps3:=38;counter_TRAME:=0;mode_receive:=false;	
							end if;
						end if;
					elsif USB_DATA=EOP then
							SIZE_mem:=conv_std_logic_vector(counter_TRAME-16-16,8);
							counter_TRAME:=0;
							pause(5);
							mode_receive:=false;
							step_ps3:=39;
							if conv_integer(SIZE_mem)>0 then
								for i in 0 to 15 loop
									CRC16_mem(i):=not(CRC16_mem(i));
								end loop;
								if not(CRC16_mem=crc16_value) then
									step_ps3:=40; -- envoyer un NACK
								else
									JOY_mem:=JOY_CANDIDATE_mem;

									joystick_left_mem:='0';
									joystick_right_mem:='0';
									joystick_up_mem:='0';
									joystick_down_mem:='0';
									joystick_button1_mem:=JOY_CANDIDATE_mem(3*8+3);
									joystick_button2_mem:=JOY_CANDIDATE_mem(3*8+2);
									joystick_button3_mem:=JOY_CANDIDATE_mem(3*8+1);
									joystick_button4_mem:=JOY_CANDIDATE_mem(3*8);
									
									case JOY_CANDIDATE_mem(3*8+7 downto 3*8+4) is
										when "0000"=>
											joystick_up_mem:='1';
										when "1000"=>
											joystick_up_mem:='1';
											joystick_right_mem:='1';
										when "0100"=>
											joystick_right_mem:='1';
										when "1100"=>
											joystick_right_mem:='1';
											joystick_down_mem:='1';
										when "0010"=>
											joystick_down_mem:='1';
										when "1010"=>
											joystick_down_mem:='1';
											joystick_left_mem:='1';
										when "0110"=>
											joystick_left_mem:='1';
										when "1110"=>
											joystick_left_mem:='1';
											joystick_up_mem:='1';
										when others=>
									end case;
								end if;
							end if;
					else
						nrzi_inv(data2bit(USB_DATA),last_nrzi,result);
						stuff(result);
						if counter_TRAME>=8+8+16 then
							crc16_value:=crc16(CRC16_mem(15),crc16_value);
						end if;
						CRC16_mem:=CRC16_mem(14 downto 0) & result;
						-- DATA & CRC16
					end if;
					if counter_TRAME>=8+8 and counter_TRAME<8+8+8*REPORT_LEN then
						JOY_CANDIDATE_mem(8+8+8*REPORT_LEN -1-counter_TRAME):=result;
					end if;
					if counter_SOF_stuff*2>period_SOF then
						-- timeout !
						step_ps3:=38;counter_TRAME:=0;mode_receive:=false;
					end if;

					if step_ps3=37 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			when 38=>
				-- wait EOP
				if USB_DATA=EOP and counter_PAS=DEMI_PAS then
					pause(5);
					time_out:=true;
					step_ps3:=34; -- next SOF
				end if;
			when 39=>
				-- envoyer un ACK
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+ACK'length then
						stuff(ACK(8+ACK'length -1-counter_TRAME));
						nrzi(ACK(8+ACK'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+ACK'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+ACK'length+2+1 then
						USB_DATA<=UN;
					else
						pause(3);
						time_out:=true;
						step_ps3:=1;-- loop -- next SOF next INSTRUCTION
						next_cmd:=true;
					end if;
					if step_ps3=39 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			
			when 40=>
				-- envoyer un NACK
				if counter_PAS=DEMI_PAS then
					if counter_TRAME<8 then
						USB_DATA<=bit2data(SYNCHRO(8 -1-counter_TRAME));
						stuff_init;
						nrzi_init;
					elsif counter_TRAME<8+NACK'length then
						stuff(NACK(8+NACK'length -1-counter_TRAME));
						nrzi(NACK(8+NACK'length -1-counter_TRAME),last_nrzi,result);
						USB_DATA<=bit2data(result);
					elsif counter_TRAME<8+NACK'length+2 then
						USB_DATA<=EOP;
					elsif counter_TRAME<8+NACK'length+2+1 then
						USB_DATA<=UN;
					else
						pause(3);
						time_out:=true;
						step_ps3:=1;-- loop -- next SOF next INSTRUCTION
						next_cmd:=true;
					end if;
					if step_ps3=40 then
						counter_TRAME:=counter_TRAME+1;
					end if;
				end if;
			
				


			
		end case;
	end if;
	
	counter_PAS:=counter_PAS+1;
	if mode_receive then
		if not(USB_DATA=last_USB_DATA) then
			if counter_PAS<DEMI_PAS then
				counter_PAS:=0;
			elsif counter_PAS>DEMI_PAS then
				counter_PAS:=PAS;
			end if;
		end if;
		last_USB_DATA:=USB_DATA;
	end if;
	if counter_PAS=PAS then
		counter_PAS:=0;
	end if;
	
	if counter_PAS=DEMI_PAS then
		counter_IDLE:=counter_IDLE+1;
		if counter_IDLE=period_IDLE+period_EOP then
			counter_IDLE:=0;
		end if;
		counter_SOF_stuff:=counter_SOF_stuff+1;
		if counter_SOF_stuff=period_SOF then
			counter_SOF_stuff:=0;
		end if;
	end if;
				



--SETUP 00000000000 DATA0 00000001 01100000 00000000_10000000 00000000_00000000 00000010_00000000
--GET_DESCRIPTOR_DEVICE length=40h
--SETUP 00000000000 DATA0 00000000 10100000 10000000_00000000 00000000_00000000 00000000_00000000
--SET_ADDRESS 1
--SETUP 10000000000 DATA0 00000001 01100000 00000000_10000000 00000000_00000000 01001000_00000000
--GET_DESCRIPTOR_DEVICE length=12h
--SETUP 10000000000 DATA0 00000001 01100000 00000000_01000000 00000000_00000000 11111111_00000000
--GET_DESCRIPTOR_CONFIG length=FFh
--SETUP 10000000000 DATA0 00000001 01100000 00000000_11000000 00000000_00000000 11111111_00000000
--GET_DESCRIPTOR_STRING length=FFh
--SETUP 10000000000 DATA0 00000001 01100000 01000000_11000000 10010000_00100000 11111111_00000000
--GET_DESCRIPTOR_STRING length=FFh
--SETUP 10000000000 DATA0 00000001 01100000 00000000_10000000 00000000_00000000 01001000_00000000
--GET_DESCRIPTOR_DEVICE length=12h
--SETUP 10000000000 DATA0 00000001 01100000 00000000_01000000 00000000_00000000 10010000_00000000
--GET_DESCRIPTOR_CONFIG length=09h
--SETUP 10000000000 DATA0 00000001 01100000 00000000_01000000 00000000_00000000 10010100_00000000
--GET_DESCRIPTOR_CONFIG length=29h
--SETUP 10000000000 DATA0 00000000 10010000 10000000_00000000 00000000_00000000 00000000_00000000
--SET_CONFIGURATION 1
--SETUP 10000000000 DATA0 10000100 01010000 00000000_00000000 00000000_00000000 00000000_00000000
--GET_INTERFACE 0
--SETUP 10000000000 DATA0 10000001 01100000 00000000_01000100 00000000_00000000 11101101_00000000
--GET_DESCRIPTOR_? length=B7h
--IN 10000001000
--...


-- il y a trois pattern :
-- -les SETUP :
--   -SET_ADDRESS, SET_CONFIGURATION,GET_INTERFACE, qui IN jusqu'� NO_DATA et ACK simplement
--   -ceux qui attendent des r�ponses IN jusqu'� (DATA_SIZE<DATA_MAX_SIZE or else NO_DATA) et qui OUT du coup et attendent le ACK
--     ==>DATA_SIZE ne peut pas �tre d�termin� avant la fin d'un crc16 (cad un EOP), et le crc16 ne peut pas �tre d�termin� sans un stuff_inv. il faut donc compter la taille du tout, en unstuff pour d�terminer DATA_SIZE.
-- -le IN qui r�ceptionne la donn�e du joystick

if next_cmd then
	next_cmd:=false;
	case (step_cmd) is
		when 0=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_DEVICE_40h);
			step_cmd<=1;
		when 1=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_DEVICE_12h);
			step_cmd<=2;
		when 2=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_CONFIG_09h);
			step_cmd<=3;
		when 3=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_CONFIG_29h);
			step_cmd<=4;
		when 4=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_STRING_0_FFh);
			step_cmd<=5;
		when 5=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_STRING_2_FFh);
			step_cmd<=6;
		when 6=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_STRING_1_FFh);
			step_cmd<=7;
		when 7=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_CONFIG_09h);
			step_cmd<=8;
		when 8=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_CONFIG_09h);
			step_cmd<=9;
		when 9=>
			trame_set(ADDR0_ENDP0,C_SET_CONFIGURATION_1); -- no OUT
			step_cmd<=10;
		when 10=>
			trame_set(ADDR0_ENDP0,C_SET_CONFIGURATION_1); -- no OUT
--			trame_set(ADDR0_ENDP0,C_SET_IDLE_0);
			step_cmd<=11;
		when 11=>
			trame_read(ADDR0_ENDP0,C_GET_DESCRIPTOR_REPORT_277h);
			step_cmd<=12;
		when others =>
			plug(C_ADDR0_ENDP1);
	end case;
end if;

		
end if;

end process;

end Behavioral;

