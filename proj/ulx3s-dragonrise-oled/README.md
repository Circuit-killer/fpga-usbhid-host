# Project for DragonRise Joystick

    idVendor           0x0079 DragonRise Inc.
    idProduct          0x0006 PC TWIN SHOCK Gamepad
    bcdDevice            1.07
    iManufacturer           1 DragonRise Inc.  
    iProduct                2 Generic   USB  Joystick  

This joystick by default uses USB 1.1 (full-speed) HID protocol
when plugged into PC.

But it can also speak USB 1.0 (low speed) HID protocol and
it is used here.

In principle it works but USB host state machine often gets stuck
so its currently not reliable enough to be used.
