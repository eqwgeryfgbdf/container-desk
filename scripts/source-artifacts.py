#!/usr/bin/env python3
"""Keep local build provenance; GitHub Release attachments contain only the DMG."""
import argparse
import hashlib
import json
import pathlib
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("dmg", type=pathlib.Path)
parser.add_argument("commit", help="commit captured before building")
parser.add_argument("--source-archive", action="store_true", help="Create an optional local source archive (never a release attachment)")
args = parser.parse_args()
root = pathlib.Path(__file__).resolve().parents[1]

def git(*command):
    return subprocess.check_output(["git", "-C", str(root), *command])

commit = git("rev-parse", "HEAD").decode().strip()
if commit != args.commit or git("status", "--porcelain").strip():
    raise SystemExit("Source changed during packaging. Commit changes and rebuild the DMG.")
if not args.dmg.is_file() or args.dmg.suffix != ".dmg":
    raise SystemExit("A completed DMG is required.")

stem = args.dmg.stem.removesuffix("-arm64-preview").removesuffix("-arm64")
if args.dmg.stem.endswith("-preview"):
    stem += "-preview"
out = root.parent / "work" / "release-metadata" / stem
out.mkdir(parents=True, exist_ok=True)
artifacts = [args.dmg]
if args.source_archive:
    archive = out / (stem + "-source.zip")
    temporary = archive.with_suffix(".zip.tmp")
    try:
        subprocess.run(["git", "-C", str(root), "archive", "--format=zip",
                        "--prefix=ContainerDesk/", "-o", str(temporary), commit], check=True)
        temporary.replace(archive)
        artifacts.append(archive)
    finally:
        temporary.unlink(missing_ok=True)

def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()

manifest = out / (stem + "-manifest.json")
manifest.write_text(json.dumps({
    "source_commit": commit,
    "source_tree": git("rev-parse", "HEAD^{tree}").decode().strip(),
    "channel": "preview" if args.dmg.stem.endswith("-preview") else "release",
    "license_file_included": (root / "LICENSE").is_file(),
    "artifacts": [{"name": p.name, "size": p.stat().st_size, "sha256": digest(p)}
                  for p in artifacts],
}, indent=2) + "\n")
checksums = out / (stem + "-SHA256SUMS.txt")
checksums.write_text("".join(f"{digest(p)}  {p.name}\n" for p in [*artifacts, manifest]))
print(f"Release attachment: {args.dmg}\nLocal provenance only: {manifest}\nLocal checksums only: {checksums}")
