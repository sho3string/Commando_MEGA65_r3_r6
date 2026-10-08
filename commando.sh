#!/usr/bin/env bash
set -euo pipefail

ZIP="${1:-commando.zip}"
OUT="${2:-commando_roms}"

mkdir -p "$OUT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Expected ROM: size (hex) CRC32
declare -A SIZE CRC
add_rom() { SIZE["$1"]="$2"; CRC["$1"]="${3,,}"; }

add_rom cm04.9m  8000 8438b694
add_rom cm03.8m  4000 35486542
add_rom cm02.9f  4000 f9cc4a74
add_rom vt01.5d  4000 505726e0
add_rom vt05.7e  4000 79f16e3d
add_rom vt06.8e  4000 26fee521
add_rom vt07.9e  4000 ca88bdfd
add_rom vt08.7h  4000 2019c883
add_rom vt09.8h  4000 98703982
add_rom vt10.9h  4000 f069d2f8
add_rom vt11.5a  4000 7b2e1b48
add_rom vt12.6a  4000 81b417d3
add_rom vt13.7a  4000 5612dbd2
add_rom vt14.8a  4000 2b2dee36
add_rom vt15.9a  4000 de70babf
add_rom vt16.10a 4000 14178237
add_rom vtb1.1d  0100 3aba15a1
add_rom vtb2.2d  0100 88865754
add_rom vtb3.3d  0100 4c14c3f6
add_rom vtb4.1h  0100 b388c246
add_rom vtb5.6l  0100 712ac508
add_rom vtb6.6e  0100 0eaf5158

for cmd in unzip perl cat wc mkdir mktemp; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: required command '$cmd' was not found" >&2
        exit 1
    }
done

for name in "${!SIZE[@]}"; do
    unzip -p "$ZIP" "$name" > "$TMP/$name" || { echo "ERROR: missing $name"; exit 1; }
    actual_size=$(wc -c < "$TMP/$name")
    expected_size=$((16#${SIZE[$name]}))
    [[ "$actual_size" -eq "$expected_size" ]] || {
        printf 'ERROR: %s expected size 0x%s, got 0x%X\n' "$name" "${SIZE[$name]}" "$actual_size"
        exit 1
    }

    # Same CRC extraction method used by the working Exed Exes shell builder.
    actual_crc=$(unzip -v "$ZIP" "$name" | awk -v n="$name" '$NF==n {print $(NF-1); exit}')
    actual_crc=${actual_crc,,}
    [[ "$actual_crc" == "${CRC[$name]}" ]] || {
        echo "ERROR: $name expected CRC ${CRC[$name]}, got ${actual_crc:-unknown}"
        exit 1
    }
done

# Main and sound ROMs.
cat "$TMP/cm04.9m" "$TMP/cm03.8m" > "$OUT/commando_main.rom"
cp "$TMP/cm02.9f" "$OUT/commando_sound.rom"

# Character ROM: swap each 16-bit byte pair.
od -An -v -tu1 "$TMP/vt01.5d" | awk '
{
    for (i=1; i<=NF; i+=2)
        printf "%c%c", $(i+1), $i
}' > "$OUT/commando_char.rom"

# Byte interleave helper: output lane0[0], lane1[0], ...
interleave() {
    local out="$1"; shift
    paste "$@" | awk '{
        for (i=1; i<=NF; i++) printf "%c", $i
    }' > "$out"
}

# Convert binary files to one decimal byte per line for portable awk processing.
bytes() { od -An -v -tu1 "$1" | awk '{for(i=1;i<=NF;i++) print $i}'; }

for f in vt05.7e vt06.8e vt07.9e vt08.7h vt09.8h vt10.9h \
         vt11.5a vt12.6a vt13.7a vt14.8a vt15.9a vt16.10a; do
    bytes "$TMP/$f" > "$TMP/$f.bytes"
done

interleave "$TMP/obj0" "$TMP/vt08.7h.bytes" "$TMP/vt05.7e.bytes"
interleave "$TMP/obj1" "$TMP/vt09.8h.bytes" "$TMP/vt06.8e.bytes"
interleave "$TMP/obj2" "$TMP/vt10.9h.bytes" "$TMP/vt07.9e.bytes"
cat "$TMP/obj0" "$TMP/obj1" "$TMP/obj2" > "$TMP/obj_unsorted"

# JTFRAME gfx_sort: hvvvvxx
# Address permutation:
#   dst A2 <- src A6
#   dst A3 <- src A2
#   dst A4 <- src A3
#   dst A5 <- src A4
#   dst A6 <- src A5
perl -e '
    use strict;
    use warnings;
    local $/;
    my $d = <>;
    my $out = "\0" x length($d);

    for (my $src = 0; $src < length($d); $src++) {
        my $dst = $src & ~0x7c;
        $dst |= (($src >> 6) & 1) << 2;
        $dst |= (($src >> 2) & 1) << 3;
        $dst |= (($src >> 3) & 1) << 4;
        $dst |= (($src >> 4) & 1) << 5;
        $dst |= (($src >> 5) & 1) << 6;
        substr($out, $dst, 1) = substr($d, $src, 1);
    }

    print $out;
' < "$TMP/obj_unsorted" > "$OUT/commando_obj.rom"

# Scroll/tile ROMs. Deliberately duplicate lanes 4 and 5 as the Python does.
interleave "$TMP/tile0" \
    "$TMP/vt11.5a.bytes" "$TMP/vt13.7a.bytes" \
    "$TMP/vt15.9a.bytes" "$TMP/vt15.9a.bytes"
interleave "$TMP/tile1" \
    "$TMP/vt12.6a.bytes" "$TMP/vt14.8a.bytes" \
    "$TMP/vt16.10a.bytes" "$TMP/vt16.10a.bytes"
cat "$TMP/tile0" "$TMP/tile1" > "$OUT/commando_tiles.rom"

cat "$TMP/vtb1.1d" "$TMP/vtb2.2d" "$TMP/vtb3.3d" \
    "$TMP/vtb4.1h" "$TMP/vtb6.6e" > "$OUT/commando_prom.rom"
cp "$TMP/vtb5.6l" "$OUT/commando_irq.rom"

for f in "$OUT"/*.rom; do
    printf '%-22s %06X\n' "$(basename "$f")" "$(wc -c < "$f")"
done
