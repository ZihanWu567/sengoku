"""Synchronize existing Lua sources; --check is read-only.

Global.lua owns the troop prefix, commanders.lua the panel and standalone
event wrappers. map_flags.lua is injected into both. TTS needs no require().
"""
from pathlib import Path
import argparse
import re

ROOT = Path(__file__).resolve().parents[2]
EVENTS = "-- BEGIN STANDALONE EVENTS"
MARKER = "-- ===== 備隊面板 v2 ====="
BEGIN, END = "-- BEGIN MAP FLAGS MODULE", "-- END MAP FLAGS MODULE"


def synchronized_sources(root=ROOT):
    standalone_path = root / "tts/modules/commanders.lua"
    global_path = root / "tts/Global.lua"
    standalone = standalone_path.read_text(encoding="utf-8")
    module = (root / "tts/modules/map_flags.lua").read_text(encoding="utf-8").strip()
    if not (module.startswith(BEGIN) and module.endswith(END)):
        raise ValueError("map_flags.lua module markers missing")
    if standalone.count(BEGIN) != 1 or standalone.count(END) != 1:
        raise ValueError("commanders.lua must contain exactly one map flag module")
    start, stop = standalone.index(BEGIN), standalone.index(END) + len(END)
    standalone = standalone[:start] + module + standalone[stop:]
    old_global = global_path.read_text(encoding="utf-8")
    if standalone.count(EVENTS) != 1 or old_global.count(MARKER) != 1:
        raise ValueError("source boundary markers missing or duplicated")
    prefix = old_global.split(MARKER)[0].splitlines(keepends=True)
    header = standalone.splitlines()[0]
    version = re.search(r"v\d+\.\d+(?:\.\d+)?", header).group(0)
    description = header.split("：", 1)[1]
    updated = re.search(r"-- 更新日：(\d{4}-\d{2}-\d{2})", standalone).group(1)
    prefix[0] = "-- 兵種＋備隊面板 " + version + "：" + description + "（" + updated + "）\n"
    merged = "".join(prefix) + MARKER + "\n" + standalone.split(EVENTS)[0]
    return {standalone_path: standalone, global_path: merged}, version


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check without changing files")
    args = parser.parse_args()
    outputs, version = synchronized_sources()
    mismatches = [str(p.relative_to(ROOT)) for p, text in outputs.items()
                  if p.read_text(encoding="utf-8") != text]
    release = ROOT / "tts/releases" / ("Global_" + version + ".txt")
    global_path = ROOT / "tts/Global.lua"
    if args.check:
        if not release.exists() or release.read_bytes() != global_path.read_bytes():
            mismatches.append(str(release.relative_to(ROOT)))
        if mismatches:
            raise SystemExit("Out of sync: " + ", ".join(mismatches))
        print("PASS: commander/map modules and byte-identical release (" + version + ")")
        return
    for path, text in outputs.items():
        if path.read_text(encoding="utf-8") != text:
            newline = "\r\n" if b"\r\n" in path.read_bytes() else "\n"
            path.write_text(text, encoding="utf-8", newline=newline)
    release.parent.mkdir(parents=True, exist_ok=True)
    release.write_bytes(global_path.read_bytes())
    print("Synchronized Lua sources and release (" + version + ")")


if __name__ == "__main__":
    main()
