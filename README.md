# Commando - for MEGA65

Commando is Capcom's 1985 vertically scrolling run-and-gun arcade game.
The player controls Super Joe as he advances through enemy territory,
fighting soldiers and other forces while rescuing prisoners and
progressing through increasingly difficult stages.

This project ports the **Commando** FPGA core from **Jotego's JTCORES
project** to the MEGA65.

The upstream Commando core used as the basis of this port is:

[Jotego JTCORES -
Commando](https://github.com/jotego/jtcores/tree/master/cores/commnd)

The original Commando FPGA implementation, JTFRAME infrastructure and
associated supporting cores are the work of **Jotego and the JTCORES
contributors**.

The MEGA65 port uses the
[MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework and
[QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for integration with
the MEGA65, including FAT32 ROM loading and the on-screen menu.

## Credits

Commando was originally developed and released by **Capcom** in 1985.

This MEGA65 core would not exist without the work of **Jotego and the
JTCORES contributors**. The MEGA65 version is based on the JTCORES
Commando implementation linked above.

Additional credit goes to **sy2002, MJoergen and the MiSTer2MEGA65
contributors** for the MiSTer2MEGA65 framework and QNICE-FPGA
integration used by this port.

## How to install the core

### 1. Obtain the Commando ROM set

You need the MAME **Commando** ROM set:

`commando.zip`

ROM files are **not included** with this repository.

The ROM conversion scripts expect the ZIP to contain the following
files:

``` text
cm04.9m
cm03.8m
cm02.9f
vt01.5d
vt05.7e
vt06.8e
vt07.9e
vt08.7h
vt09.8h
vt10.9h
vt11.5a
vt12.6a
vt13.7a
vt14.8a
vt15.9a
vt16.10a
vtb1.1d
vtb2.2d
vtb3.3d
vtb4.1h
vtb5.6l
vtb6.6e
```

The conversion will stop with an error if one of the required ROMs is
missing, has an unexpected size, or does not match the expected CRC.

### 2. Generate the MEGA65 ROM images

Three equivalent ROM conversion scripts are provided:

-   `commando.py` - Python
-   `commando.ps1` - Windows PowerShell
-   `commando.sh` - Linux/macOS shell

The scripts read the files directly from `commando.zip`; you do **not**
need to extract the MAME ZIP first.

They also perform the transformations required by the MEGA65 port,
including character byte ordering, graphics ROM interleaving and the
JTFRAME `hvvvvxx` address transformation required by the Commando
object/sprite graphics.

#### Windows / PowerShell

Place `commando.ps1` and `commando.zip` in the same directory and run:

``` powershell
.\commando.ps1 .\commando.zip
```

If Windows marks the downloaded PowerShell script as coming from the
Internet, you can unblock it with:

``` powershell
Unblock-File .\commando.ps1
```

#### Linux / macOS

Place `commando.sh` and `commando.zip` in the same directory.

Make the script executable if necessary:

``` bash
chmod +x commando.sh
```

Then run:

``` bash
./commando.sh commando.zip
```

The shell version requires `bash`, `unzip`, `perl`, `cat` and `wc`.

#### Python

The Python version can be run with:

``` bash
python3 commando.py commando.zip
```

On Windows, depending on your Python installation, you can also use:

``` powershell
python .\commando.py .\commando.zip
```

### 3. Generated ROM files

By default the scripts create a directory named:

``` text
commando_roms
```

containing:

``` text
commando_main.rom
commando_sound.rom
commando_char.rom
commando_obj.rom
commando_tiles.rom
commando_prom.rom
commando_irq.rom
```

The expected ROM sizes are:

  File                          Size
  ---------------------- -----------
  `commando_main.rom`      `0x0C000`
  `commando_sound.rom`     `0x04000`
  `commando_char.rom`      `0x04000`
  `commando_obj.rom`       `0x18000`
  `commando_tiles.rom`     `0x20000`
  `commando_prom.rom`      `0x00500`
  `commando_irq.rom`       `0x00100`

### 4. Copy the ROMs to the MEGA65 SD card

Copy the generated Commando ROM files to the directory expected by the
core on your MEGA65 SD card.

The folder where the ROMs reside must be:

``` text
/arcade/commando
```

Also copy the supplied Commando configuration file to this directory.

Both the bottom SD card slot and the rear SD card slot can be used. As
with other MEGA65 cores, the rear SD card takes precedence when both are
present.

Install the Commando `.cor` file using the normal MEGA65 core
installation procedure.

## Game setup

Press the **HELP** key while the core is running to open the
MiSTer2MEGA65 on-screen menu.

The menu provides display, control and DIP-switch settings for the core.

### Video output

Commando is a vertically oriented arcade game. The MEGA65 port uses the
MiSTer2MEGA65 rotation/frame-buffer support to present the arcade
display in the correct orientation.

The core supports the MiSTer2MEGA65 digital video modes as well as
analog/VGA output modes.

The VGA menu provides:

-   Standard output
-   Retro 15 kHz mode with separate HS/VS
-   Retro 15 kHz mode with CSYNC

### Controls

The MEGA65 joystick ports are used for the arcade controls.

Commando uses two action buttons: **fire** and **grenade**.

The second fire button can be connected through the MEGA65 POT lines.
The on-screen menu provides independent configuration for each joystick:

- Joy 1 second fire: POTX or POTY
- Joy 2 second fire: POTX or POTY
- Joy 1 second-fire polarity
- Joy 2 second-fire polarity

If a second fire button appears permanently pressed or behaves
backwards, change the polarity setting for that joystick port.

#### Two-player controls and cabinet mode

The original Commando arcade hardware handles the second player's
controls according to the cabinet DIP-switch setting.

When the cabinet is configured as **Upright**, **joystick port 2 is not
active**. This is normal behaviour and does not indicate a problem with
the MEGA65 joystick port or the core.

To use **joystick port 2**, set the cabinet DIP switch to **Cocktail**
mode using the on-screen menu. The DIP switch settings for **Cocktail**  
mode can be found

The MEGA65 port does not physically rotate or invert the displayed
picture when Cocktail mode is selected. The **screen always remains
upright**, regardless of the Upright/Cocktail cabinet setting.

In practice:

- **Upright mode** - screen remains upright; joystick 1 works; joystick 2
  is not active.
- **Cocktail mode** - screen remains upright; joystick 1 and joystick 2
  can be used for the respective players.

Therefore, if you want to use both MEGA65 joystick ports for a
two-player game, select **Cocktail** cabinet mode.

### DIP switches

The original Commando arcade DIP switches can be configured from the
on-screen menu.

The DIP-switch menus expose the individual arcade settings so the
original game configuration can be adjusted from the MEGA65.

## Upstream projects

This port builds upon the work of several open-source FPGA projects:

-   [Jotego JTCORES](https://github.com/jotego/jtcores)
-   [Commando core in
    JTCORES](https://github.com/jotego/jtcores/tree/master/cores/commnd)
-   [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
-   [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA)

Please support the upstream projects and developers whose work made this
MEGA65 port possible.

## Status

This is an initial MEGA65 release of the Commando core.

Please report MEGA65-specific problems through the Commando MEGA65
project rather than to the upstream JTCORES project unless the problem
has also been reproduced on the original upstream implementation.
