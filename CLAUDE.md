# Gram Frames: notes for Claude

Jon is not technical: keep reports short and plain.

## Every build / release (Jon asked for this every time)
1. Bump the version in `GramFrames/GramFrames.toc` (`## Version:`), `GT.version` in `GramFrames/Core.lua`, and the `Version` line in `README.md`. Add a `CHANGELOG.md` entry.
2. **Update the main picture** `images/gramframes-banner.png` every build:
   - version badge: `python3 tools/images/badge.py`
   - show the new feature on the frames in the picture (and a bullet if it's a big one). `tools/images/common.py` + `txt.py` have helpers (outlined text, borders, recolor).
   - keep `images/gramframes-raid.png` / `gramframes-party-card.png` in step when the feature shows on frames.
3. Rebuild the zip from the repo root: `rm -f GramFrames.zip && zip -qr GramFrames.zip GramFrames -x '*.ttf' '*.otf' '*Expressway*'` and check `unzip -l` has no font files. Expressway is a paid font: never commit or zip it.
4. Commit as `Jon <jonathan.wehman@gmail.com>`, push to main, then run the "Upload to CurseForge" workflow (`curseforge.yml`, inputs `changelog`, `release_type`). Check the job log says "Uploaded Gram Frames <version> to CurseForge."
5. Remind Jon: GitHub-download users re-download GramFrames.zip and replace the folder in `_forever_\Interface\AddOns`, then /reload. CurseForge pictures (Images tab) have to be uploaded by Jon by hand.
