# FPGA USB-joystick attempt

The minimalistic USB-host driver for USB HID device (joystick)
connected on D+/D- any 2 pins of FPGA over 27 ohm
resistors and 3.6V Zener diodes. Tested on ULX3S board.

Started from joystick FPGA USB host driver from 
[CoreAmstrad](https://github.com/renaudhelias/CoreAmstrad).
and made driver for Saitek Cyborg joystick by modifying
USB_logitech.vhd

Joystick works but has latency. From pressing joystick buttons to signal
response there is some short but annying delay of 100-200 ms. On PC the same
joystick works with unnoticeable delay.

"USB_saitek.vhd" contains minimal state machine that acts as USB host for
the joystick. Instead of proper enumeration, it replays constant USB 
packets to initialize the joystick, receives eventual USB response, 
ignores it and starts listening to USB HID reports.

Additionally a VHDL package "usb_req_gen_func_pack.vhd" is written with functions that
reverse bit order and calculate crc5 and crc16, for easier creating 
VHDL usb packet hex constants.

New HID device may be USB-sniffed with wireshark on linux
and then file "USB_saitek.vhd" can be modified to support new device.

    modprobe usbmon
    chown user:user /dev/usbmon*
    wireshark

Plug device and push its buttons or replug it few times to find out
which usbmon device sniffs its traffic, then select
this usbmon as wireshark capture device.

plug joystick in and find 8-byte data from sniffed "URB setup", source
"host", e.g.

    80 06 00 01 00 00 12 00

and copy it to the USB constants here as 

    usb_data_gen(C_DATA0 & x"8006000100001200"):

at the end of "USB_saitek.vhd" file, configure the
state machine to replay all packets in the sniffed order
to the joystick. Eventually some packets will not work
so experiment a bit.

# Additional info from original author

some info on it
http://www.cpcwiki.eu/index.php/FPGAmstrad#USB_joystick

Part of original wiki:

USB joystick

Before learning final platform and its embedded controlers (USB joystick with a controler, is just 7 wires : left right up down buttonX buttonY buttonZ), and after having destroyed 12 collector original joysticks during tests... I did some research about simply connecting a modern USB joystick into FPGA. It was a part of my Agile Method run, I worked about two months on it.

http://www.youtube.com/watch?v=5BERbI2kyfM
Sniffing USB frames

USB uses two wires in order to transmit frames, green and white, each with two logical values: 0v and 5v.

Let's plug a joystick on PC, if you listen at its two wires, you can sniff a USB transmission. Finally you can save it for example on RAM.

These two wires can be traduced into one with four states: 00 01 10 11.

One of this states is sleep state, in fact it depends on USB mode you use.
USB mode: USB1 or USB2; low speed, full speed or high speed

For sampling, I speed up five times the saving speed on RAM. I succeed sampling an USB1 transmission: "Logitech dual action USB joystick", and an USB2: "Sony PS3 USB joystick". PS3 joystick is not stable enough with my FPGA, but Logitech joystick is correct.

http://github.com/renaudhelias/CoreAmstrad/blob/master/BuildYourOwnZ80Computer/USB_logitech.vhd

http://www.youtube.com/watch?v=2zEp1tHroBs

http://github.com/renaudhelias/CoreAmstrad/blob/master/BuildYourOwnZ80Computer/USB_ps3.vhd

http://www.youtube.com/watch?v=fh4v4OXridc

USB is just a state machine (welcome how are you today, show me your state, show me your state, show me your state....), encoding (have to read USB manual), you can use some usb sniffer softwares to decode them (wireshark unix version does it fine). Sniffer software does not show low level messages (ack ko ok) but does show the high level messages (ones that show that a button is pressed or not)

As it is just encoding, you can capture signals and show that they differ only when you do unpress or press a button.
pull up and pull down

If you respect USB protocol, you have to plug some pull-up and pull-down resistors and some capacitors. But as I am a bad electrician, I just simulate then in VHDL, they are important because they cause USB speed negotiations. You also have an electronic mechanism in order to detect presence of joystick plug, I don't care about it.

For reaching which wire you have to pull-up or pull-down, here the tips :

    For slave (ideal for sniffing) : just take your USB1 joystick without plug it, just supply it (+5v red, 0v black), and test while-black and green-black with voltmeter, if you have got 5v then put a VHDL pull-up, and if you have got 0v then put a VHDL pull-down.
    For master (ideal for creating a mini-host) : just take your PC USB1 port, and test white-black and green-black with voltmeter, if you have got 5v then put a VHDL pull-up, and if you have got 0v then put a VHDL pull-down. Normally you result two pull-down.

Synchronize, decode and check USB frames

One time sample is done, it is not readable. In fact USB frames are synchronized (they started with a certain synchronization pattern), encoded (NRZI), and checked (CRC). CRC type depends on frame length. Encoding is done for synchronization optimization.

Then using USB HID manual, you can understand type of frames, and author of them, and remark that the author alternates: USB master (PC) or USB slave (joystick)

You can use some "USB sniffer software" in order to understand more easily some frames contain, but they generally don't give all frame, and full frame.

great crc check example in perl - offered by www.usb.org
Build a minimum USB master frames state-machine

Let's just plug a USB joystick on FPGA, directly, permanently, thinking about minimum coding size : we can't implement full HID USB protocol on FPGA ^^'

Objective here is to build a minimum state-machine graph, having for transaction between state a "frame transmission". It is normal on USB protocol to have error of transmission, so you have also to put "error frame transmission" on the graph.

At stabilization, you finally switch between two states, one sending a certain frame that contains at different offset simply certain values of joystick button.

At start, some frames are employed for "next frame description", they can generally be ignored, as our USB architecture is fixed and minimal (one USB joystick, that's all)
go further with USB sniffer

A better way to snif USB could be generation of TCP/IP packets encapsulating USB packets, and to record them directly on PC from a RJ45 plug, using this way I could save more than 10 seconds of information transmission (RAM size is limited on FPGA platfoms)
Usb-paf.png
http://www.ulule.com/usb-paf (unfunded) => but MiST-board final platform does offer USB pro competition Joystick compatibility <3 <3 <3 
