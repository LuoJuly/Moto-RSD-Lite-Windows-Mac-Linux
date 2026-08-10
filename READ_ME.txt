Moto RSD Lite — Flash Motorola firmware (RSD / fastboot XML)
Windows / macOS / Linux
platform-tools: 37.0.1 (adb + fastboot bundled in files/)

================================================================
Windows
================================================================
1. Install Motorola USB / Google USB drivers if the phone is not detected
2. Put the phone in AP Fastboot / Bootloader mode
3. Double-click rsd-flash.bat
   or in PowerShell / CMD:
     rsd-flash.bat
     rsd-flash.bat "D:\path\to\firmware"
     rsd-flash.bat "D:\path\to\firmware" flashfile.xml
4. Choose the firmware folder (or press Enter for this folder)
5. Pick XML:
     flashfile.xml  (Erase Data !!!)  — full wipe
     servicefile.xml (Update Only)    — keep userdata when possible
6. Press Enter to start, then Enter again at the end to reboot

================================================================
macOS / Linux
================================================================
1. open a terminal and cd to this folder
2. run:
     chmod +x rsd-flash.sh files/adblinux files/fastbootlinux files/adbosx files/fastbootosx
     ./rsd-flash.sh
     ./rsd-flash.sh /path/to/firmware/
     ./rsd-flash.sh /path/to/firmware/ flashfile.xml
3. enter the Motorola firmware package directory (or press Enter for this folder)
4. pick the XML flash file from the numbered list
5. press Enter to start flashing
6. when finished, press Enter again to reboot the device

Firmware images referenced by the XML must stay in the same package
directory as the XML. They do not need to be copied into this tool folder.

Bundled tools (files/):
  Linux   : adblinux, fastbootlinux
  macOS   : adbosx, fastbootosx
  Windows : adb.exe, fastboot.exe (+ AdbWinApi.dll, AdbWinUsbApi.dll, libwinpthread-1.dll)

Note: device must be in Bootloader / AP Fastboot mode
1. power off phone
2. hold volume down and power to boot AP fastboot mode
