# Changelog

## 0.1.0

First public version.

- The island in the notch: hover to open, click to keep open, right-click for the menu.
- A little printed Pip on the left of the notch shows where Pip lives (can be hidden from the menu).
- Or Pip in the menu bar instead of the notch (a setting): click its icon to open the island under it; notes and the
  recording time show there too.
- Pip and its states: ready, getting ready, listening, nobody talking, paused, a note for you, saved, a problem.
- Live transcription, sentence by sentence: on device with SpeechAnalyzer on macOS 26; on macOS 15 the previous recognizer,
  on device when your language's model is available, otherwise through Apple's servers.
- You (microphone) and Them (the call's audio) on separate tracks.
- Agent switch: the agent only sees `agent-feed.md`, only while it is on.
- Pause, vocabulary, transcription and interface language (English, French).
- Asks for the microphone before the first recording, and restarts the capture by itself if one side stops sending
  audio (microphone changed, AirPods switching to call mode); a recording keeps one format when the microphone changes.
- The `/pip` command for Claude Code: follows the call, whispers notes, writes the summary.

Known limitation: without headphones the microphone also hears the call, so You and Them mix. Use headphones.
