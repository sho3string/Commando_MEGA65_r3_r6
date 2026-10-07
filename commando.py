#!/usr/bin/env python3

from pathlib import Path
import argparse
import zipfile
import zlib


# -----------------------------------------------------------------------------
# Expected source ROMs
# -----------------------------------------------------------------------------

EXPECTED = {
    # Main / sound / character
    "cm04.9m":  (0x8000, 0x8438B694),
    "cm03.8m":  (0x4000, 0x35486542),
    "cm02.9f":  (0x4000, 0xF9CC4A74),
    "vt01.5d":  (0x4000, 0x505726E0),

    # Objects
    "vt05.7e":  (0x4000, 0x79F16E3D),
    "vt06.8e":  (0x4000, 0x26FEE521),
    "vt07.9e":  (0x4000, 0xCA88BDFD),
    "vt08.7h":  (0x4000, 0x2019C883),
    "vt09.8h":  (0x4000, 0x98703982),
    "vt10.9h":  (0x4000, 0xF069D2F8),

    # Tiles
    "vt11.5a":  (0x4000, 0x7B2E1B48),
    "vt12.6a":  (0x4000, 0x81B417D3),
    "vt13.7a":  (0x4000, 0x5612DBD2),
    "vt14.8a":  (0x4000, 0x2B2DEE36),
    "vt15.9a":  (0x4000, 0xDE70BABF),
    "vt16.10a": (0x4000, 0x14178237),

    # PROMs
    "vtb1.1d":  (0x0100, 0x3ABA15A1),
    "vtb2.2d":  (0x0100, 0x88865754),
    "vtb3.3d":  (0x0100, 0x4C14C3F6),
    "vtb4.1h":  (0x0100, 0xB388C246),
    "vtb5.6l":  (0x0100, 0x712AC508),
    "vtb6.6e":  (0x0100, 0x0EAF5158),
}


# -----------------------------------------------------------------------------
# ROM helpers
# -----------------------------------------------------------------------------

def read_rom(zip_file, name):
    data = zip_file.read(name)

    expected_size, expected_crc = EXPECTED[name]
    actual_crc = zlib.crc32(data) & 0xFFFFFFFF

    if len(data) != expected_size or actual_crc != expected_crc:
        raise ValueError(
            f"{name}: expected {expected_size:#x}/{expected_crc:08x}, "
            f"got {len(data):#x}/{actual_crc:08x}"
        )

    return data


def interleave(*lanes):
    if len({len(lane) for lane in lanes}) != 1:
        raise ValueError("lane sizes differ")

    output = bytearray(len(lanes) * len(lanes[0]))

    for index, lane in enumerate(lanes):
        output[index::len(lanes)] = lane

    return bytes(output)


def swap16(data):
    output = bytearray(len(data))

    output[0::2] = data[1::2]
    output[1::2] = data[0::2]

    return bytes(output)


def write_rom(output_dir, name, data):
    path = output_dir / name
    path.write_bytes(data)

    crc = zlib.crc32(data) & 0xFFFFFFFF

    print(
        f"{name:22s} "
        f"{len(data):06X} "
        f"crc={crc:08x}"
    )


# -----------------------------------------------------------------------------
# JTFRAME graphics sorting
# -----------------------------------------------------------------------------

def gfx_sort_hvvvvxx(data):
    """
    Exact equivalent of:

        gfx_sort: hvvvvxx

    JTFRAME parses this as:

        mode = gfx16c
        b0   = 2

    Which ultimately performs:

        remapBits(addr, 2, [4, 0, 1, 2, 3])

    Address mapping:

        dst A2 <- src A6
        dst A3 <- src A2
        dst A4 <- src A3
        dst A5 <- src A4
        dst A6 <- src A5

    A0, A1 and A7+ remain unchanged.
    """

    output = bytearray(len(data))

    for src in range(len(data)):
        dst = src

        # Clear destination address bits A2..A6.
        dst &= ~0x7C

        # Apply JTFRAME address permutation.
        dst |= ((src >> 6) & 1) << 2
        dst |= ((src >> 2) & 1) << 3
        dst |= ((src >> 3) & 1) << 4
        dst |= ((src >> 4) & 1) << 5
        dst |= ((src >> 5) & 1) << 6

        output[dst] = data[src]

    return bytes(output)


# -----------------------------------------------------------------------------
# Build ROMs
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Build MEGA65 ROM images for Jotego Commando"
    )

    parser.add_argument(
        "zip",
        nargs="?",
        default="commando.zip",
        help="MAME Commando ROM ZIP"
    )

    parser.add_argument(
        "-o",
        "--out",
        default="commando_roms",
        help="Output directory"
    )

    args = parser.parse_args()

    output_dir = Path(args.out)
    output_dir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(args.zip) as zip_file:

        def rom(name):
            return read_rom(zip_file, name)

        # ---------------------------------------------------------------------
        # Main CPU
        # ---------------------------------------------------------------------

        main_rom = (
            rom("cm04.9m") +
            rom("cm03.8m")
        )

        # ---------------------------------------------------------------------
        # Sound CPU
        # ---------------------------------------------------------------------

        sound_rom = rom("cm02.9f")

        # ---------------------------------------------------------------------
        # Character graphics
        # ---------------------------------------------------------------------

        char_rom = swap16(
            rom("vt01.5d")
        )

        # ---------------------------------------------------------------------
        # Object / sprite graphics
        # ---------------------------------------------------------------------

        object_roms = [
            rom("vt05.7e"),
            rom("vt06.8e"),
            rom("vt07.9e"),
            rom("vt08.7h"),
            rom("vt09.8h"),
            rom("vt10.9h"),
        ]

        obj_unsorted = (
            interleave(object_roms[3], object_roms[0]) +
            interleave(object_roms[4], object_roms[1]) +
            interleave(object_roms[5], object_roms[2])
        )

        # Reproduce JTFRAME:
        #
        #     gfx_sort: hvvvvxx
        #
        obj_rom = gfx_sort_hvvvvxx(obj_unsorted)

        # ---------------------------------------------------------------------
        # Scroll / tile graphics
        # ---------------------------------------------------------------------

        tile_roms = [
            rom("vt11.5a"),
            rom("vt12.6a"),
            rom("vt13.7a"),
            rom("vt14.8a"),
            rom("vt15.9a"),
            rom("vt16.10a"),
        ]

        tiles_rom = (
            interleave(
                tile_roms[0],
                tile_roms[2],
                tile_roms[4],
                tile_roms[4],
            ) +
            interleave(
                tile_roms[1],
                tile_roms[3],
                tile_roms[5],
                tile_roms[5],
            )
        )

        # ---------------------------------------------------------------------
        # Palette / lookup PROMs
        # ---------------------------------------------------------------------

        prom_rom = (
            rom("vtb1.1d") +
            rom("vtb2.2d") +
            rom("vtb3.3d") +
            rom("vtb4.1h") +
            rom("vtb6.6e")
        )

        # Interrupt timing PROM.
        irq_rom = rom("vtb5.6l")

    # -------------------------------------------------------------------------
    # Write output files
    # -------------------------------------------------------------------------

    outputs = [
        ("commando_main.rom",  main_rom),
        ("commando_sound.rom", sound_rom),
        ("commando_char.rom",  char_rom),
        ("commando_obj.rom",   obj_rom),
        ("commando_tiles.rom", tiles_rom),
        ("commando_prom.rom",  prom_rom),
        ("commando_irq.rom",   irq_rom),
    ]

    for name, data in outputs:
        write_rom(output_dir, name, data)


if __name__ == "__main__":
    main()