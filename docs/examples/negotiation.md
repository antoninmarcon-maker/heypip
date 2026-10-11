# A negotiation, with Claude in the room

**English** · [Français](negotiation.fr.md)

A test call with Pip and Claude Code, run on 11 October 2026. The client is fictional and every line of the call
was scripted; Claude's notes and summary are copied here **unedited**.

**How it was run.** A script wrote the 15 lines of the call into `agent-feed.md` at speaking pace, the way Pip does
(no audio here, so add the 1–3 s of transcription of a real call). The agent was a fresh Claude Code session
(2.1.295, Sonnet 5.5, web search allowed) that got the brief below and the prompt from the README.
The « You » lines were scripted too: they do not follow Claude's notes. So this shows what the agent caught and
suggested, not how the call would have ended if you had listened.

## The brief given to Claude before the call

> I'm Sacha, a freelance video maker based in France (sachapraljak.com). In a minute I have a call with Atelier Lune, a French ceramics brand that wants a launch video. My packages: Essential €490 (one 30 s video, French or English voice-over, 2 rounds of feedback), Complete €990 (the video + 3 short formats for stories and Reels). My goal: close the deal, ideally the Complete package, paid within 30 days at most.

## The call, and what Pip whispered

| | Said | Pip whispered | After |
|---|---|---|---|
| 0:00 | **Them:** Hi Sacha, thanks for taking the time. | | |
| 0:04 | **You:** My pleasure. You're launching a new collection, right? | | |
| 0:09 | **Them:** Yes, our winter collection comes out on November 15, and we want a video for Instagram. | Nov 15 = 5 wks. Ask: samples ready when? Instagram -> pitch Complete (Reels/stories) | 5.5 s |
| 0:15 | **Them:** We're torn between two options: just a 30-second video, or the video plus three short formats for stories. | Pick Complete: +€500 buys 3 formats (~€167 each), Nov 15 push needs stories. Ask payment <30d | 4.4 s |
| 0:15 |  | Pick Complete: +€500 = 3 formats (~€167 each), stories matter for Nov 15. Lock 30d pay | 7.0 s |
| 0:20 | **You:** Got it. Do you already have footage of your pieces? | | |
| 0:24 | **Them:** We have photos, but no video at all. | No footage: shoot needed. Clarify who films, where, days, travel costs inside the price? | 3.2 s |
| 0:29 | **Them:** Our budget is 800 euros, max. | €800 < €990 (gap €190). Don't cut Complete: offer Essential + 2 formats ~€800, or 2 pay steps | 4.2 s |
| 0:29 |  | Budget €800 < €990. Don't just discount: offer Essential + 2 formats at ~€800 | 6.7 s |
| 0:34 | **You:** That leaves some room on the basic package. | | |
| 0:40 | **Them:** Also, could you invoice us at 90 days? That's what we do with all our suppliers. | Fact: FR law caps B2B payment at 60 d from invoice (L441-10). 90 d not allowed | 16.7 s |
| 0:44 | **You:** I'll look into it. | | |
| 0:49 | **Them:** And we'd need the video by November 10 at the latest. | Nov 10 = 30 days left. Fix shoot date now, 2 feedback rounds must fit before it | 7.6 s |
| 0:54 | **Them:** We'd also need subtitles, well, maybe, we'll see. | Subtitles 'maybe': not in packages. Ask yes/no now, price as extra, avoid scope creep | 4.7 s |
| 1:00 | **Them:** So if I sum up: three short formats at 100 euros each plus the video at 490, that's 700 euros. | WRONG: 490+3x100 = 790, not 700. Also never quoted 100/format: Complete = €990. Correct now | 3.2 s |
| 1:00 |  | STOP: 490+3x100 = 790, not 700. And formats not €100 each: Complete = €990. Correct | 4.9 s |
| 1:05 | **You:** I'll send you a quote tomorrow. | Before hanging up: confirm option, 30 d pay (or deposit on signing), shoot date, subtitles | 3.6 s |
| 1:09 | **Them:** Perfect, thanks, talk soon. | | |

Seconds are measured from the line that called for the note to the moment the note was written. Claude ran one web search during the call, on the 90-day payment term. It sometimes wrote the same note twice.

## The summary Claude wrote when the call ended (`summary.md`)

> # Atelier Lune call: summary (2026-10-11)
>
> ## Result
> No deal closed. Sacha promised a quote for tomorrow. The client has not chosen a package.
>
> ## What the client said
> - Winter collection launches **Nov 15**. The video is for **Instagram**.
> - Video needed by **Nov 10 at the latest** (30 days from today).
> - They hesitate between the 30 s video alone and the video plus 3 short formats for stories.
> - They have **photos only, no video footage**.
> - Budget: **€800 max**.
> - They want to be invoiced at **90 days** (their standard for all suppliers).
> - Subtitles: "maybe, we'll see".
>
> ## Decisions
> - None firm. Sacha said "I'll look into it" on the 90-day term and will send a quote tomorrow.
>
> ## Problems to fix in the quote
> 1. **Budget gap**: Complete is €990, budget is €800 (gap €190).
> 2. **Their sum was wrong**: they said 3 formats at €100 + video at €490 = €700. Real result is €790, and €100 per format is not Sacha's price. The feed does not show Sacha correcting this, so the client may still think €700. State the real price in writing.
> 3. **90-day payment**: French law caps B2B payment at 60 days from invoice date (45 days end of month alternative), Code de commerce L441-10. A web search backed this up. I did not read the statute on Légifrance, so check before citing it. Sacha's goal is 30 days. Do not accept 90.
> 4. **No footage**: a shoot is needed. The packages do not say who films, where, how many days, or whether travel is included.
> 5. **Subtitles** are outside both packages. Decide yes or no and price them as an extra.
> 6. **Deadline**: Nov 10 leaves about 30 days for shoot, edit and 2 feedback rounds.
>
> ## Suggested options for the quote (my suggestion, not agreed)
> - A: Essential €490 + 2 formats, about €800. Fits the budget. The per-format price is Sacha's call: €155 gives €800, €167 gives €824.
> - B: Complete €990 with 50% deposit at signing and the balance at 30 days. This is the stronger offer for Sacha's goal but is over budget.
> - Do not simply discount Complete to €800 without cutting scope.
>
> ## Next steps
> - [ ] Send quote tomorrow (Oct 12) with exact prices and what is included.
> - [ ] Put payment terms in the quote: 30 days, or a deposit plus a 30-day balance. State that French law caps terms at 60 days.
> - [ ] Fix the shoot date and state the shoot scope and travel in the quote.
> - [ ] Ask for product samples and the brief this week.
> - [ ] Settle subtitles: in or out, and the price.
> - [ ] Set a deadline for the client to sign, to protect the Nov 10 delivery.
