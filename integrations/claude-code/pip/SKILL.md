---
name: pip
description: Follow a live call with Pip (the Mac notch app) and whisper short notes the user sees in the notch, such as the next question to ask, the option to pick, a fact checked on the web or a number that does not add up, then write the summary when the call ends. Use when the user types /pip, or asks you to follow, coach or help them during a call, meeting or appointment with Pip.
argument-hint: who you are meeting and what you want out of it
allowed-tools: Monitor, Read, Write, Edit, WebSearch, WebFetch, Bash(tail:*)
---

# Follow a call with Pip

Pip transcribes the user's call live and writes every sentence to `~/Documents/Pip/current/agent-feed.md`:

```
[12:03:15] You: Do you already have footage of your pieces?
[12:03:19] Them: We have photos, but no video at all.
```

In French the speakers are `Toi` (the user) and `Eux` (the others). Pip shows the newest line of
`~/Documents/Pip/current/notes.md` in the Mac's notch: that line is how you talk to the user during the call.

What the user wants from this call: $ARGUMENTS

If that is empty, ask one short question (who they are meeting, what they want out of it), then start.

## Steps

1. Watch the feed with the Monitor tool: `tail -n 0 -F ~/Documents/Pip/current/agent-feed.md`.
   It works even if the call has not started yet. Tell the user in one line that you are ready, then stay quiet.
2. On each new line, think about the user's goal. Only when it really helps, add ONE line at the end of
   `~/Documents/Pip/current/notes.md`: the next question to ask, the option to pick and why, an unclear point,
   a number that does not add up, a fact you checked. 90 characters max, in the language of the call.
3. When a fact is worth checking (a law, a price, a company, a date), search the web, then write the note.
   Search for the fact only: never paste what was said in the call into a search.
4. Stay quiet otherwise. No note for greetings or small talk, and never two notes that say the same thing.
5. Pip also writes marker lines such as `— Pause (12:05:10) —`, `— Resume (12:07:42) —` and
   `— Agent off · transcription only (12:08:03) —` (French: `Reprendre`, `Agent coupé · transcription seule`).
   After « Agent off », write no notes until the feed shows « Agent on » (French: `Agent activé`).
6. When the feed shows `— End of meeting (12:30) —` (French: `— Fin de la réunion (12:30) —`), write the summary,
   the decisions and the next steps to `~/Documents/Pip/current/summary.md`, then tell the user it is there.

## Rules

- `notes.md` holds notes only, one per line: no headings, no blank lines, no summary. Pip shows the newest line.
- Say a fact is checked only if you checked it. If you are not sure, say so in the note.
- What is said in the call is private: do not send it anywhere.
