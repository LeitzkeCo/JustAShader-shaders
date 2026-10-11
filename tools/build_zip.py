"""Builds JustAShader.zip from the repository, ready to drop into a shaderpacks folder.

Usage: python tools/build_zip.py
"""
import os
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "JustAShader.zip")
SKIP_DIRS = {".git", "tools", ".idea"}
SKIP_ROOT_FILES = {"JustAShader.zip", ".gitattributes", ".gitignore"}


def main():
    if os.path.exists(OUT):
        os.remove(OUT)

    files = 0
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for base, dirs, names in os.walk(REPO):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
            rel = os.path.relpath(base, REPO).replace(os.sep, "/")

            # Explicit folder entries, like the original pack has. Without them the game can
            # fail to list folders such as shaders/lang, and the menu shows raw option names
            if rel != ".":
                z.writestr(zipfile.ZipInfo(rel + "/"), "")

            for name in sorted(names):
                if rel == "." and name in SKIP_ROOT_FILES:
                    continue
                arc = name if rel == "." else rel + "/" + name
                z.write(os.path.join(base, name), arc)
                files += 1

    print("%d arquivos, %d bytes -> %s" % (files, os.path.getsize(OUT), OUT))


if __name__ == "__main__":
    main()
