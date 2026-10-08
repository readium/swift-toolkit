#!/usr/bin/env bash
# =============================================================================
# generate.sh
# =============================================================================
# Generates the audio fixtures of this folder, which are committed. This is a
# developer tool: it is not run by the tests.
#
# Requirements:
#   - ffmpeg
#   - Python 3 with mutagen, for example in a virtual environment:
#       python3 -m venv venv && venv/bin/pip install mutagen
#       PYTHON=venv/bin/python ./generate.sh
#
# The chapters of the MP3 files are written by mutagen, not by ffmpeg, which
# writes a `CTOC` frame with a size that is invalid in ID3v2.4.
# =============================================================================

set -euo pipefail

OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PYTHON:-python3}"
TMP="$(mktemp -d)"
trap 'rm -r "$TMP"' EXIT

run_ffmpeg() {
    ffmpeg -hide_banner -loglevel error -y "$@"
}

# Three seconds of audio without tags.
SINE=(-f lavfi -i "sine=frequency=440:duration=3" -ac 1 -map_metadata -1 -fflags +bitexact)

# Covers.
run_ffmpeg -f lavfi -i "color=c=red:s=32x32" -frames:v 1 -fflags +bitexact "$OUT/cover.jpg"
run_ffmpeg -f lavfi -i "testsrc=s=32x32" -frames:v 1 -fflags +bitexact "$OUT/cover.png"
run_ffmpeg -f lavfi -i "color=c=blue:s=16x16" -frames:v 1 -fflags +bitexact "$TMP/back.jpg"

# MP4 files with a QuickTime chapter track, the last chapter being untitled.
# ffmpeg writes a Nero `chpl` atom next to the chapter track.
cat > "$TMP/chapters.ffmeta" <<'EOF'
;FFMETADATA1
[CHAPTER]
TIMEBASE=1/1000
START=0
END=1000
title=Opening
[CHAPTER]
TIMEBASE=1/1000
START=1000
END=2500
title=Chapitre deux é
[CHAPTER]
TIMEBASE=1/1000
START=2500
END=3000
title=
EOF
run_ffmpeg "${SINE[@]}" -c:a aac -b:a 32k -f mp4 "$TMP/base.m4a"
MP4_CHAPTERS=(-i "$TMP/base.m4a" -i "$TMP/chapters.ffmeta" -map 0:a -map_metadata 1 -map_chapters 1 -c copy -fflags +bitexact -f mp4)
# `moov` at the end of the file, the default of ffmpeg.
run_ffmpeg "${MP4_CHAPTERS[@]}" "$OUT/tagged.m4b"
# `moov` at the start of the file.
run_ffmpeg "${MP4_CHAPTERS[@]}" -movflags +faststart "$OUT/faststart.m4b"

# MP4 file without chapters, which get Nero chapters below.
cp "$TMP/base.m4a" "$OUT/nero.m4b"

# MP3 files.
run_ffmpeg "${SINE[@]}" -c:a libmp3lame -b:a 32k -id3v2_version 0 "$OUT/tagged.mp3"
cp "$OUT/tagged.mp3" "$OUT/tagged-v23.mp3"
cp "$OUT/tagged.mp3" "$OUT/nested-toc.mp3"
# Variable bitrate without a Xing header.
run_ffmpeg "${SINE[@]}" -c:a libmp3lame -q:a 9 -id3v2_version 0 -write_xing 0 "$OUT/noxing.mp3"

# One second of audio without tags.
run_ffmpeg -f lavfi -i "sine=frequency=440:duration=1" -ac 1 -ar 8000 -map_metadata -1 -fflags +bitexact -c:a pcm_s16le "$OUT/untagged.wav"

"$PYTHON" - "$OUT" "$TMP" <<'EOF'
import struct
import sys
from pathlib import Path

from mutagen.id3 import (
    APIC, CHAP, COMM, CTOC, ID3, MVIN, MVNM, TALB, TCOM, TCON, TDES, TDRC,
    TDRL, TIT2, TIT3, TLAN, TPE1, TPE2, TPUB, TSOA, TSOT, TXXX, TYER, CTOCFlags,
)
from mutagen.mp4 import MP4, MP4Cover, MP4FreeForm

out = Path(sys.argv[1])
tmp = Path(sys.argv[2])
jpeg_cover = (out / "cover.jpg").read_bytes()
png_cover = (out / "cover.png").read_bytes()
back_cover = (tmp / "back.jpg").read_bytes()


def freeform(value):
    return [MP4FreeForm(value.encode())]


def tag_mp4(path, subtitle, freeform_subtitle):
    """Writes every MP4 atom of the reference.

    An MP4 value is not split on `/`, so the values of the atoms feeding a
    field with several values hold one.
    """
    tags = MP4(path)
    tags["\xa9nam"] = ["Part One"]
    tags["\xa9alb"] = ["The Book"]
    tags["\xa9st3"] = [subtitle]
    tags["----:com.apple.iTunes:SUBTITLE"] = freeform(freeform_subtitle)
    tags["aART"] = ["Jane Author/Jill Author"]
    # An atom with two values.
    tags["\xa9ART"] = ["Jane Author/Jill Author", "Nora Narrator"]
    tags["\xa9nrt"] = ["Nora Narrator/Ned Narrator"]
    tags["\xa9wrt"] = ["Carl Composer/Cleo Composer"]
    tags["\xa9mvn"] = ["The Movement"]
    tags["\xa9mvi"] = [3]
    # A freeform atom named in lowercase.
    tags["----:com.apple.iTunes:series"] = freeform("The Saga")
    # A freeform atom with another mean, to ignore. mutagen writes the
    # freeform atoms from the smallest to the largest, so it comes first.
    tags["----:com.example:SERIES"] = freeform("Other")
    tags["----:com.apple.iTunes:SERIES-PART"] = freeform("2.5")
    tags["\xa9pub"] = ["Acme Audio/Books"]
    tags["\xa9day"] = ["2021-03-04"]
    tags["\xa9gen"] = ["Fantasy; Adventure"]
    tags["ldes"] = ["A long description."]
    tags["desc"] = ["A summary."]
    tags["\xa9cmt"] = ["A comment."]
    # The second value is not a language, as it is not split.
    tags["----:com.apple.iTunes:LANGUAGE"] = [MP4FreeForm(b"fra"), MP4FreeForm(b"eng/deu")]
    tags["----:com.apple.iTunes:ISBN"] = freeform("978-1-234-56789-7")
    tags["soal"] = ["Saga 2 - The Book"]
    tags["sonm"] = ["Part 1"]
    tags["covr"] = [MP4Cover(jpeg_cover, imageformat=MP4Cover.FORMAT_JPEG)]
    tags.save()


def replace_in_nero_chapters(path, old, new):
    """Replaces a title of the Nero `chpl` atom by one of the same length."""
    old, new = old.encode(), new.encode()
    data = bytearray(path.read_bytes())
    assert len(old) == len(new) and data.count(b"chpl") == 1
    at = data.index(old, data.index(b"chpl"))
    data[at : at + len(old)] = new
    path.write_bytes(data)


def atoms(data, start, end):
    """Lists the atoms of `data` between `start` and `end`, as (type, offset, size)."""
    result = []
    while start < end:
        size, kind = struct.unpack(">I4s", data[start : start + 8])
        assert size >= 8, "Extended atom sizes are not handled"
        result.append((kind, start, size))
        start += size
    return result


def add_nero_chapters(path, chapters):
    """Adds a Nero `chpl` atom to `moov/udta`, from chapters given as (seconds, title)."""
    chpl = b"\x01\x00\x00\x00" + bytes(4) + bytes([len(chapters)])
    for start, title in chapters:
        title = title.encode()
        chpl += struct.pack(">QB", int(start * 10_000_000), len(title)) + title
    chpl = struct.pack(">I4s", 8 + len(chpl), b"chpl") + chpl

    data = bytearray(path.read_bytes())
    kind, moov, moov_size = atoms(data, 0, len(data))[-1]
    # No chunk offset changes when `moov` is the last atom of the file.
    assert kind == b"moov", "`moov` must be at the end of the file"
    udta = [a for a in atoms(data, moov + 8, moov + moov_size) if a[0] == b"udta"]
    if udta:
        _, udta, udta_size = udta[0]
        data[udta + udta_size : udta + udta_size] = chpl
        data[udta : udta + 4] = struct.pack(">I", udta_size + len(chpl))
    else:
        chpl = struct.pack(">I4s", 8 + len(chpl), b"udta") + chpl
        data += chpl
    data[moov : moov + 4] = struct.pack(">I", moov_size + len(chpl))
    path.write_bytes(data)


def save_id3(tags, path, version):
    """Saves the tag without padding.

    On iOS 18, AVFoundation reads no tag from an ID3v2.4 file holding a frame
    larger than 127 bytes which is followed by padding.
    """
    tags.save(path, v2_version=version, v1=0, padding=lambda info: 0)


def tag_mp3_v24(path):
    """Writes the ID3v2.4 frames of the reference."""
    tags = ID3()
    tags.add(TIT2(encoding=3, text=["Part 2"]))
    tags.add(TALB(encoding=3, text=["The Book"]))
    tags.add(TIT3(encoding=3, text=["A Subtitle"]))
    tags.add(TPE2(encoding=3, text=["Jane Author"]))
    # A frame with two values, separated by a null character.
    tags.add(TPE1(encoding=3, text=["Jane Author", "Nora Narrator"]))
    # A value to split on `/`.
    tags.add(TXXX(encoding=3, desc="NARRATOR", text=["Nora Narrator / Ned Narrator"]))
    tags.add(TCOM(encoding=3, text=["Carl Composer"]))
    tags.add(MVNM(encoding=3, text=["The Movement"]))
    tags.add(MVIN(encoding=3, text=["3/5"]))
    # A user-defined frame named in lowercase.
    tags.add(TXXX(encoding=3, desc="series", text=["The Saga"]))
    tags.add(TXXX(encoding=3, desc="SERIES-PART", text=["2.5"]))
    tags.add(TPUB(encoding=3, text=["Acme Audio"]))
    tags.add(TDRL(encoding=3, text=["2021-03-04"]))
    tags.add(TDRC(encoding=3, text=["2020-01-02T10:20"]))
    # The year of ID3v2.3, to ignore in favor of `TDRC`.
    tags.add(TYER(encoding=3, text=["1999"]))
    tags.add(TCON(encoding=3, text=["Fantasy; Adventure"]))
    tags.add(TXXX(encoding=3, desc="DESCRIPTION", text=["A long description."]))
    tags.add(TDES(encoding=3, text=["A summary."]))
    # A technical comment, then the comment, which is the largest of the two.
    tags.add(COMM(encoding=3, lang="eng", desc="iTunNORM", text=[" 00000A2B 00000A2B"]))
    tags.add(COMM(encoding=3, lang="eng", desc="", text=["A comment following the technical comment."]))
    tags.add(TLAN(encoding=3, text=["fra/eng"]))
    tags.add(TXXX(encoding=3, desc="ISBN", text=["9781234567897"]))
    tags.add(TSOA(encoding=3, text=["Saga 2 - The Book"]))
    tags.add(TSOT(encoding=3, text=["Part 2"]))
    # A linked front cover, a back cover, then the embedded front cover.
    # mutagen writes the frames of a same kind from the smallest to the
    # largest.
    tags.add(APIC(encoding=0, mime="-->", type=3, desc="linked", data=b"https://example.com/cover.jpg"))
    tags.add(APIC(encoding=0, mime="image/jpeg", type=4, desc="back", data=back_cover))
    tags.add(APIC(encoding=0, mime="image/png", type=3, desc="front", data=png_cover))
    assert len(back_cover) < len(png_cover)
    # Chapters listed out of order by the table of contents, the last one
    # being untitled. AVFoundation only reads the chapters listed by a flat
    # `CTOC` frame which is top-level and ordered.
    tags.add(CTOC(
        element_id="toc", flags=CTOCFlags.TOP_LEVEL | CTOCFlags.ORDERED,
        child_element_ids=["chp2", "chp3", "chp1"], sub_frames=[],
    ))
    for element_id, start, end, title in [
        ("chp1", 0, 1000, "Opening"),
        ("chp2", 1000, 2500, "Chapitre deux é"),
        ("chp3", 2500, 3000, None),
    ]:
        tags.add(CHAP(
            element_id=element_id, start_time=start, end_time=end,
            start_offset=0xFFFFFFFF, end_offset=0xFFFFFFFF,
            sub_frames=[TIT2(encoding=3, text=[title])] if title else [],
        ))
    save_id3(tags, path, version=4)


def tag_mp3_nested_toc(path):
    """Writes chapters grouped by a nested table of contents.

    AVFoundation reads none of them.
    """
    tags = ID3()
    tags.add(TIT2(encoding=3, text=["Nested"]))
    tags.add(CTOC(
        element_id="toc", flags=CTOCFlags.TOP_LEVEL | CTOCFlags.ORDERED,
        child_element_ids=["part", "chp2"], sub_frames=[],
    ))
    tags.add(CTOC(
        element_id="part", flags=CTOCFlags.ORDERED,
        child_element_ids=["chp1"], sub_frames=[TIT2(encoding=3, text=["Part"])],
    ))
    for element_id, start, end, title in [("chp1", 0, 1000, "One"), ("chp2", 1000, 3000, "Two")]:
        tags.add(CHAP(
            element_id=element_id, start_time=start, end_time=end,
            start_offset=0xFFFFFFFF, end_offset=0xFFFFFFFF,
            sub_frames=[TIT2(encoding=3, text=[title])],
        ))
    save_id3(tags, path, version=4)


def tag_mp3_v23(path):
    """Writes ID3v2.3 frames. mutagen joins the values of a frame with `/`."""
    tags = ID3()
    tags.add(TIT2(encoding=1, text=["Part 3"]))
    tags.add(TPE2(encoding=1, text=["Jane Author", "Jill Author"]))
    tags.add(TPE1(encoding=1, text=["Jane Author", "Nora Narrator"]))
    tags.add(TCOM(encoding=1, text=["Nora Narrator", "Ned Narrator"]))
    tags.add(TPUB(encoding=1, text=["Acme Audio", "Other Press"]))
    tags.add(TLAN(encoding=1, text=["eng", "fra"]))
    tags.add(TYER(encoding=1, text=["2021"]))
    # A reference to the ID3v1 genre list, then a name.
    tags.add(TCON(encoding=1, text=["(12)Fantasy"]))
    # A cover with a MIME type to normalize.
    tags.add(APIC(encoding=0, mime="image/jpg", type=0, desc="", data=jpeg_cover))
    save_id3(tags, path, version=3)


# A blank `©st3` atom, to ignore in favor of the freeform atom, then a `©st3`
# atom which has priority over the freeform atom.
for name, subtitle, freeform_subtitle in [
    ("tagged.m4b", "  ", "A Subtitle"),
    ("faststart.m4b", "A Subtitle", "Another Subtitle"),
]:
    tag_mp4(out / name, subtitle, freeform_subtitle)
    # The chapter track has priority over the Nero atom, which is given a
    # different title to tell them apart.
    replace_in_nero_chapters(out / name, "Opening", "Ignored")
add_nero_chapters(out / "nero.m4b", [(0, "One"), (1.5, "Two")])
tag_mp3_v24(out / "tagged.mp3")
tag_mp3_v23(out / "tagged-v23.mp3")
tag_mp3_nested_toc(out / "nested-toc.mp3")
# Bytes which are not audio.
(out / "garbage.mp3").write_bytes(bytes((i * 37 + 11) % 256 for i in range(4096)))
EOF

ls -l "$OUT"
