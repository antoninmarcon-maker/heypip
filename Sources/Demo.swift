import AppKit
import Foundation

/// `Pip --demo [en|fr]`: a scripted call, for screenshots, the README GIF and videos.
/// No microphone, no permission, nothing written to disk.
@MainActor extension IslandController {
  func runDemo(french: Bool) {
    let lines: [(Speaker, String)] = french ? [
      (.them, "Merci de prendre l'appel. On lance notre application le mois prochain."),
      (.me, "Super. Vous avez déjà une idée du budget pour la vidéo de lancement ?"),
      (.them, "On pensait à environ cinq cents euros, avec une version pour les réseaux."),
    ] : [
      (.them, "Thanks for taking the call. We're launching our app next month."),
      (.me, "Great. Do you already have a budget in mind for the launch video?"),
      (.them, "We were thinking around five hundred euros, with a cut for social media."),
    ]
    let note = french ? "Demande la date exacte de lancement" : "Ask for the exact launch date"
    let note2 = french ? "490 € l'Essentiel, 990 € avec les formats courts" : "Quote 490 € basic, 990 € with the short cuts"
    meeting.name = french ? "Appel client" : "Client call"
    Task {
      func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
      await wait(1.5)
      pin()                                            // the island opens
      await wait(1.2)
      meeting.busy = true; meeting.status = L10n.t("model")
      await wait(1.4)
      meeting.busy = false
      meeting.running = true; meeting.startedAt = Date(); meeting.status = L10n.t("listening")
      for (who, text) in lines {
        meeting.hears = [who: true]
        var shown = ""
        for word in text.split(separator: " ") {      // words appear as they are recognised
          shown += (shown.isEmpty ? "" : " ") + word
          meeting.volatile = [who: shown]
          await wait(0.16)
        }
        meeting.volatile = [:]
        meeting.write(who, text)
        meeting.hears = [:]
        await wait(0.9)
      }
      unpin()                                          // back to the notch…
      await wait(1.0)
      meeting.notes = [note]                           // …and Pip whispers
      meeting.feed.append(FeedItem(time: Date(), kind: .note, text: note))
      meeting.peek = note
      await wait(4.0)
      meeting.peek = nil
      await wait(0.8)
      meeting.notes = [note2, note]
      meeting.feed.append(FeedItem(time: Date(), kind: .note, text: note2))
      meeting.peek = note2
      await wait(3.5)
      meeting.peek = nil
      await wait(0.6)
      pin()                                            // open again: transcript and notes
      await wait(3.0)
      meeting.togglePauseForDemo()
      await wait(2.2)
      meeting.togglePauseForDemo()
      await wait(1.0)
      meeting.running = false; meeting.startedAt = nil; meeting.endedAt = Date(); meeting.status = L10n.t("ended")
      await wait(3.0)
      unpin()
    }
  }
}

@MainActor extension Meeting {
  /// Pause without files (demo).
  func togglePauseForDemo() {
    paused.toggle()
    status = L10n.t(paused ? "paused" : "listening")
  }
}
