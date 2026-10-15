# Working on Pip (for AI agents and humans)

Pip is a macOS notch app that transcribes calls on device and shows notes written by an AI agent.
Swift 5 language mode, SwiftUI + AppKit, no dependencies, no Xcode project: `swiftc` via `build.sh`.

## Map

| File | What |
|---|---|
| `Sources/App.swift` | entry point, app delegate, `--test` file mode |
| `Sources/Island.swift` | the notch island: fixed window, hover from mouse-move events (open/close), shape, all views |
| `Sources/Pip.swift` | the Pip character and its moods (`PipMood`) |
| `Sources/Meeting.swift` | a meeting: start/stop/pause, feed, notes, agent switch, sound levels |
| `Sources/Audio.swift` | ScreenCaptureKit capture (mic = You, system audio = Them), transcribers (SpeechAnalyzer on macOS 26, SFSpeechRecognizer on 15), recorder |
| `Sources/Sentences.swift` | turns the recogniser's running text into finished sentences (offset based) |
| `Sources/Echo.swift` | keeps the call's echo out of « You »: `MicGate` (the You transcriber only hears the mic when it is louder than the call's echo), `EchoText` (drops You sentences that repeat Them), `micIsEcho` |
| `Sources/Replay.swift` | `--replay`: a recorded call (you.m4a + them.m4a) through Pip, silently; `PIP_TRACE` debug log |
| `Sources/Updater.swift` | updates from GitHub releases: checks `releases/latest`, downloads `Pip.zip`, verifies Team ID + signature + Gatekeeper, replaces the app between meetings |
| `Sources/Store.swift` | settings (UserDefaults `com.sachapraljak.heypip`), meeting folders and files |
| `Sources/L10n.swift` | every UI string, English + French. Add both when you add a string. |
| `scripts/make-icon.swift`, `scripts/make-moods.swift` | render the icon and the moods sheet from `Pip.swift` |
| `integrations/claude-code/pip/SKILL.md` | the `/pip` command for Claude Code. Its marker lines (pause, agent off, end of meeting) must match what `Meeting.swift` writes to `agent-feed.md` |
| `docs/examples/` | the negotiation test call (scripted client, unedited agent notes, measured delays) |
| `build.sh` / `release.sh` | universal build / signed + notarized zip |

## Build and check

```bash
bash build.sh                                                    # must finish with no error and no warning
./Pip.app/Contents/MacOS/Pip --test some.m4a en-US --realtime    # transcription as if live: sentences 1–3 s after speech
./Pip.app/Contents/MacOS/Pip --pin                               # island open, for screenshots
./Pip.app/Contents/MacOS/Pip --peek "A note"                     # a note popping out
./Pip.app/Contents/MacOS/Pip -meetingsFolder /tmp/pip-test --start   # a meeting at launch, in a test folder
./Pip.app/Contents/MacOS/Pip -meetingsFolder /tmp/pip-test --start --stop-after 40   # …ended properly after 40 s
./Pip.app/Contents/MacOS/Pip -meetingsFolder /tmp/pip-test --replay you.m4a them.m4a   # a recorded call, silently
```

Always pass `-meetingsFolder` with `--start` or `--replay`, so the test meeting does not land in `~/Documents/Pip`.
For echo issues, replay the reporter's two tracks: `PIP_TRACE=trace.txt` logs every 20 ms decision of the gate
(`G open mic echo gain floor`) and every « You » sentence (`R` recognised, `W` written, `X` dropped), and `PIP_GATE=0`
turns the gate off to compare.

There is no unit test target yet. Before a change is done: build clean, run `--test` on a real recording, look at the island
(`--pin`, `--peek`) with `screencapture`, and test a real call when audio code changed.

## Rules

- **Privacy first.** Pip never sends audio or text anywhere. No network code, no analytics, no telemetry. The agent only
  gets `agent-feed.md`, only while the agent switch is on.
- **Notch alignment.** At rest the island is exactly the notch (`NotchGeometry`). Never resize the panel: it is fixed and
  click-through; the island is drawn inside it. Resizing the panel brings back the hover open/close loop.
- **Strings** in `L10n.swift`, English and French. Lowercase-friendly, short.
- **macOS 15 support.** Anything newer than macOS 15 goes behind `if #available`.
- Keep the code plain: no new dependency without a strong reason.

## Release

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist`, add the version to `CHANGELOG.md`.
2. `DEVELOPER_ID="Developer ID Application: … (93UZLJAMCN)" bash release.sh` → signed, notarized `Pip.zip`.
3. `gh release create vX.Y.Z Pip.zip --title "Pip X.Y.Z" --notes-file <notes>`. The asset must be named `Pip.zip`:
   installed copies update themselves from it.

## Issues

1. Reproduce (build, `--test`, `--pin`, real call if audio).
2. Fix on a branch, build clean, verify, open a PR that says what was wrong, what changed and how it was checked.
3. Never close an issue as fixed without a check you actually ran.
