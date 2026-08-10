# Moto RSD Lite

Flash Motorola firmware packages (RSD / fastboot XML) on **Windows**, **macOS**, and **Linux**.

Bundled **Android platform-tools 37.0.1** (`adb` + `fastboot`) for all three platforms.

---

## Features

- Interactive firmware folder + XML selection
- `flashfile.xml` — **Erase Data !!!** (full wipe)
- `servicefile.xml` — **Update Only** (keep userdata when possible)
- Red error highlighting and end-of-flash error summary
- No need to copy firmware images into the tool folder

---

## Windows

1. Install Motorola USB / Google USB drivers if the phone is not detected
2. Put the phone in **AP Fastboot / Bootloader** mode
3. Double-click `rsd-flash.bat`, or in PowerShell / CMD:

```bat
rsd-flash.bat
rsd-flash.bat "D:\path\to\firmware"
rsd-flash.bat "D:\path\to\firmware" flashfile.xml
```

4. Choose the firmware folder (or press Enter for this folder)
5. Pick the XML file from the list
6. Press Enter to start, then Enter again at the end to reboot

---

## macOS / Linux

1. Open a terminal and `cd` into this folder
2. Make scripts executable (first time):

```bash
chmod +x rsd-flash.sh files/adblinux files/fastbootlinux files/adbosx files/fastbootosx
```

3. Run:

```bash
./rsd-flash.sh
./rsd-flash.sh /path/to/firmware/
./rsd-flash.sh /path/to/firmware/ flashfile.xml
```

4. Enter the Motorola firmware package directory (or press Enter for this folder)
5. Pick the XML flash file from the numbered list
6. Press Enter to start flashing, then Enter again to reboot

---

## Notes

- Firmware images referenced by the XML must stay in the **same package directory** as the XML.
- They do **not** need to be copied into this tool folder.

### Bundled tools (`files/`)

| Platform | Files |
|----------|--------|
| Linux | `adblinux`, `fastbootlinux` |
| macOS | `adbosx`, `fastbootosx` |
| Windows | `adb.exe`, `fastboot.exe`, `AdbWinApi.dll`, `AdbWinUsbApi.dll`, `libwinpthread-1.dll` |

### Boot into AP Fastboot

1. Power off the phone  
2. Hold **Volume Down + Power** to boot AP Fastboot mode  

---

## Credits

Based on the original [RSD-Lite-Mac-Linux](https://github.com/rootjunky/RSD-Lite-Mac-Linux) by RootJunky.  
Updated as **Moto RSD Lite** by LuoJuly.
