"""Package the two installable addon files using the version in the manifest."""

import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


def main():
    root = Path(__file__).resolve().parents[1]
    addon = root / "CharContext"
    manifest = addon / "CharContext.toc"
    version = re.search(r"^## Version:\s*(\d+\.\d+\.\d+)\s*$", manifest.read_text(encoding="utf-8"), re.M)
    if not version:
        raise SystemExit("Expected a three-part version in CharContext.toc")

    output = root / "dist" / f"CharContext-{version[1]}.zip"
    output.parent.mkdir(exist_ok=True)
    with ZipFile(output, "w") as archive:
        for path in (manifest, addon / "CharContext.lua"):
            entry = ZipInfo("CharContext/" + path.name)
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, path.read_bytes(), compress_type=ZIP_DEFLATED)
    print(output)


if __name__ == "__main__":
    main()
