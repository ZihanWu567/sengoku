"""Offline repository checks. --verify-import also verifies the import baseline.

Python standard library only. This is not a Lua interpreter or a TTS GPU test.
"""
from pathlib import Path
import argparse
import ast
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    if not condition:
        raise SystemExit("FAIL: " + message)


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify-import", action="store_true")
    args = parser.parse_args()
    subprocess.run([sys.executable, str(ROOT / "tools/tts/sync_global.py"), "--check"], check=True)
    for path in (ROOT / "tools/tts").glob("*.py"):
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    json_paths = list((ROOT / "docs/tbs").rglob("*.json"))
    for path in json_paths:
        json.loads(path.read_text(encoding="utf-8-sig"))
    lua = (ROOT / "tts/Global.lua").read_text(encoding="utf-8")
    section = lua.split("UNIT_CONFIGS = {", 1)[1].split("COUNT_CONFIGS = {", 1)[0]
    tags = re.findall(r'tag\s*=\s*"(unit_[^"]+)"', section)
    require(len(tags) == len(set(tags)) and len(tags) > 0, "duplicate or absent troop tags")
    max_digit = int(re.search(r"local UNIT_MAX_DIGIT\s*=\s*(\d+)", lua).group(1))
    values = re.findall(r"(?:max_front|max_back|front_move|back_move)\s*=\s*(\d+)", section)
    require(all(0 <= int(x) <= max_digit for x in values), "unit values outside image range")
    for bank in ("UNIT_NUMBER_IMAGES", "UNIT_NUMBER_BACK_IMAGES"):
        block = re.search(r"^" + bank + r"\s*=\s*\{(.*?)^\}", lua, re.M | re.S).group(1)
        keys = {int(x) for x in re.findall(r"\[(\d+)\]\s*=", block)}
        require(keys == set(range(max_digit + 1)), bank + " missing a digit")
    for event in ("onLoad", "onSave", "onObjectSpawn", "onObjectDestroy", "onObjectHover",
                  "onObjectRotate", "onObjectDrop", "onObjectEnterContainer", "onObjectLeaveContainer",
                  "onObjectStateChange", "onPlayerChangeColor", "onPlayerDisconnect"):
        require(len(re.findall(r"^function " + event + r"\(", lua, re.M)) == 1,
                "event entry point duplicated or absent: " + event)
    require(not re.search(r"\b(?:front|back)_(?:name|number)_color\s*=", section),
            "retired per-unit text color fields reintroduced")
    print(f"PASS: Python syntax, {len(json_paths)} JSON files, {len(tags)} troop tags, digit banks and events")
    if args.verify_import:
        sources = json.loads((ROOT / "docs/tbs/import-sources.json").read_text(encoding="utf-8"))
        for row in sources["files"]:
            path = ROOT / row["destination"]
            require(path.is_file(), "missing import: " + row["destination"])
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            require(digest == row["imported_sha256"], "changed import: " + row["destination"])
            if row["note"] == "原样导入":
                require(digest == row["source_sha256"], "source mismatch: " + row["destination"])
        inventory = json.loads((ROOT / "docs/tbs/asset-inventory.json").read_text(encoding="utf-8"))
        protected = list(inventory["protected_trees"])
        for path, sha in inventory["protected_trees"].items():
            actual = git("rev-parse", inventory["base_main"] + ":" + path).decode().strip()
            require(actual == sha, "unexpected baseline tree: " + path)
        require(not git("diff", "--name-only", inventory["base_main"], "--", *protected),
                "protected artwork/Photoshop changed")
        require(not git("ls-files", "--others", "--exclude-standard", "--", *protected),
                "untracked files in protected artwork/Photoshop paths")
        pngs = [x for x in inventory["files"]
                if re.match(r"^素材/合成成品/[^/]+/[^/]+\.png$", x["path"])]
        families = {}
        for item in pngs:
            name = item["path"].split("/")[2]
            families[name] = families.get(name, 0) + 1
        require(len(pngs) == 96 and len(families) == 12 and set(families.values()) == {8},
                "expected 12 types x 8 colors")
        print(f"PASS: {len(sources['files'])} import hashes; 96 PNGs / 12 types / 8 colors; protected paths unchanged")


if __name__ == "__main__":
    main()
