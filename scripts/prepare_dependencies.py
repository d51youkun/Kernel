#!/usr/bin/env python3
"""Fetch pinned upstream binaries and repair StikJIT's module/type name collision."""
import hashlib
import pathlib
import shutil
import tempfile
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
FRAMEWORKS = ROOT / "Frameworks"
DEPENDENCIES = [
    ("llama", "https://github.com/ggml-org/llama.cpp/releases/download/b10549/llama-b10549-xcframework.zip",
     "636709d4a7b49ac7f2ed6dc8a4de3f278c257cac7248fe40d6a513f671e4bff4"),
    ("StikJIT", "https://github.com/StikDebug/StikJIT/releases/download/1.5.0/StikJIT.xcframework.zip",
     "444b8d439df8455c34afbb51e279fd225265279195475f9b3fdbcf3a71a27e85"),
]


def main():
    FRAMEWORKS.mkdir(exist_ok=True)
    for name, url, digest in DEPENDENCIES:
        destination = FRAMEWORKS / f"{name}.xcframework"
        if not destination.exists():
            with tempfile.TemporaryDirectory() as temporary:
                archive = pathlib.Path(temporary) / "framework.zip"
                print(f"Downloading {name}…", flush=True)
                urllib.request.urlretrieve(url, archive)
                if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
                    raise RuntimeError(f"Checksum mismatch: {name}")
                extracted = pathlib.Path(temporary) / "extracted"
                with zipfile.ZipFile(archive) as bundle:
                    bundle.extractall(extracted)
                matches = list(extracted.rglob(f"{name}.xcframework"))
                if len(matches) != 1:
                    raise RuntimeError(f"Unexpected archive layout: {name}")
                shutil.move(str(matches[0]), destination)
        if name == "StikJIT":
            # Swift emits module-qualified names that resolve to the identically named enum
            # when a newer compiler rebuilds this interface. No ABI/binary changes.
            for interface in destination.rglob("*.swiftinterface"):
                text = interface.read_text()
                fixed = text.replace("StikJIT.", "")
                if fixed != text:
                    interface.write_text(fixed)
        print(f"Ready: {destination.relative_to(ROOT)}", flush=True)


if __name__ == "__main__":
    main()
