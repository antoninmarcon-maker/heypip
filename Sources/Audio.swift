import AVFoundation
import CoreMedia
import ScreenCaptureKit
import Speech

enum Speaker: String {
  case me, them
  var label: String { L10n.t(self == .me ? "you" : "them") }
}

// MARK: - CMSampleBuffer → AVAudioPCMBuffer

func pcmBuffer(from sb: CMSampleBuffer) -> AVAudioPCMBuffer? {
  guard let desc = sb.formatDescription, var asbd = desc.audioStreamBasicDescription,
        let format = AVAudioFormat(streamDescription: &asbd) else { return nil }
  let frames = AVAudioFrameCount(sb.numSamples)
  guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
  buf.frameLength = frames
  let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sb, at: 0, frameCount: Int32(frames), into: buf.mutableAudioBufferList)
  return status == noErr ? buf : nil
}

// MARK: - Live transcription of one source (you or them), on device

protocol Transcribing: AnyObject, Sendable {
  func start(languageID: String, words: [String], onResult: @escaping @Sendable (Speaker, String, Bool) -> Void) async throws
  /// Records `buf`; the transcriber hears `heard` (the gated microphone) when given, else `buf`.
  func feed(_ buf: AVAudioPCMBuffer, heard: AVAudioPCMBuffer?)
  func stop() async
}

extension Transcribing {
  func feed(_ buf: AVAudioPCMBuffer) { feed(buf, heard: nil) }
}

/// SpeechAnalyzer on macOS 26 (better, faster), SFSpeechRecognizer before.
func makeTranscriber(speaker: Speaker, fileURL: URL) -> Transcribing {
  if #available(macOS 26, *) { return LiveTranscriber(speaker: speaker, fileURL: fileURL) }
  return LegacyTranscriber(speaker: speaker, fileURL: fileURL)
}

/// Writes one side of the call to an .m4a file. The file keeps the format of the first buffer; later buffers in another
/// format (the microphone changed, AirPods switching to call mode) are converted instead of being dropped.
final class Recorder: @unchecked Sendable {
  private var file: AVAudioFile?
  private var converter: AVAudioConverter?
  private let url: URL
  init(url: URL) { self.url = url }
  func write(_ buf: AVAudioPCMBuffer) {
    if file == nil {
      let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: buf.format.sampleRate,
                                     AVNumberOfChannelsKey: buf.format.channelCount, AVEncoderBitRateKey: 64000]
      file = try? AVAudioFile(forWriting: url, settings: settings, commonFormat: buf.format.commonFormat, interleaved: buf.format.isInterleaved)
    }
    guard let file else { return }
    let target = file.processingFormat
    if buf.format == target { try? file.write(from: buf); return }
    if converter == nil || converter?.inputFormat != buf.format { converter = AVAudioConverter(from: buf.format, to: target) }
    if let out = convert(buf, with: converter, to: target) { try? file.write(from: out) }
  }
  func close() { file = nil; converter = nil }
}

/// One buffer through an AVAudioConverter (sample rate and channel changes included).
func convert(_ buf: AVAudioPCMBuffer, with converter: AVAudioConverter?, to target: AVAudioFormat) -> AVAudioPCMBuffer? {
  guard let converter else { return nil }
  let capacity = AVAudioFrameCount(Double(buf.frameLength) * target.sampleRate / buf.format.sampleRate) + 1024
  guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
  var fed = false
  var error: NSError?
  converter.convert(to: out, error: &error) { _, status in
    if fed { status.pointee = .noDataNow; return nil }
    fed = true
    status.pointee = .haveData
    return buf
  }
  return error == nil && out.frameLength > 0 ? out : nil
}

@available(macOS 26, *)
final class LiveTranscriber: Transcribing, @unchecked Sendable {
  let speaker: Speaker
  private var analyzer: SpeechAnalyzer?
  private var input: AsyncStream<AnalyzerInput>.Continuation?
  private var format: AVAudioFormat?
  private var converter: AVAudioConverter?
  private var resultsTask: Task<Void, Never>?
  private let recorder: Recorder
  private let lock = NSLock()

  init(speaker: Speaker, fileURL: URL) {
    self.speaker = speaker
    self.recorder = Recorder(url: fileURL)
  }

  static func locale(for id: String) async -> Locale? {
    // (macOS 26 only)
    await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: id))
  }

  func start(languageID: String, words: [String], onResult: @escaping @Sendable (Speaker, String, Bool) -> Void) async throws {
    guard let locale = await Self.locale(for: languageID) else {
      throw NSError(domain: "Pip", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.t("noLanguage")])
    }
    let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
    if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
      try await request.downloadAndInstall()
    }
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    if !words.isEmpty {
      let context = AnalysisContext()
      context.contextualStrings[.general] = words
      try await analyzer.setContext(context)
    }
    format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    input = continuation
    try await analyzer.start(inputSequence: stream)
    self.analyzer = analyzer
    let who = speaker
    resultsTask = Task {
      do {
        for try await r in transcriber.results {
          onResult(who, String(r.text.characters), r.isFinal)
        }
      } catch {}
    }
  }

  /// Called from ScreenCaptureKit's audio queue.
  func feed(_ buf: AVAudioPCMBuffer, heard: AVAudioPCMBuffer?) {
    lock.lock(); defer { lock.unlock() }
    recorder.write(buf)
    let heard = heard ?? buf
    guard let target = format, let input else { return }
    if converter == nil || converter?.inputFormat != heard.format {
      converter = AVAudioConverter(from: heard.format, to: target)
    }
    if let out = convert(heard, with: converter, to: target) { input.yield(AnalyzerInput(buffer: out)) }
  }

  private func closeInput() {
    lock.lock(); defer { lock.unlock() }
    input?.finish()
    input = nil
    recorder.close()
  }

  func stop() async {
    closeInput()
    try? await analyzer?.finalizeAndFinishThroughEndOfInput()
    _ = await resultsTask?.value
  }
}

/// macOS 15: SFSpeechRecognizer, on device when the language allows it. A recognition task is restarted
/// after each final result, so long calls keep going.
final class LegacyTranscriber: Transcribing, @unchecked Sendable {
  let speaker: Speaker
  private let recorder: Recorder
  private let lock = NSLock()
  private var recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var words: [String] = []
  private var onResult: (@Sendable (Speaker, String, Bool) -> Void)?
  private var stopped = false

  init(speaker: Speaker, fileURL: URL) {
    self.speaker = speaker
    self.recorder = Recorder(url: fileURL)
  }

  func start(languageID: String, words: [String], onResult: @escaping @Sendable (Speaker, String, Bool) -> Void) async throws {
    let status = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
    guard status == .authorized, let recognizer = SFSpeechRecognizer(locale: Locale(identifier: languageID)), recognizer.isAvailable else {
      throw NSError(domain: "Pip", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.t("noLanguage")])
    }
    self.recognizer = recognizer
    self.words = words
    self.onResult = onResult
    startTask()
  }

  private func startTask() {
    lock.lock(); defer { lock.unlock() }
    newTask()
  }

  private func finishAll() {
    lock.lock(); defer { lock.unlock() }
    stopped = true
    request?.endAudio()
    task?.finish()
    recorder.close()
  }

  private func newTask() {
    guard !stopped, let recognizer else { return }
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
    request.addsPunctuation = true
    request.contextualStrings = words
    self.request = request
    let who = speaker
    task = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self else { return }
      if let result {
        self.onResult?(who, result.bestTranscription.formattedString, result.isFinal)
      }
      if error != nil || result?.isFinal == true {
        self.lock.lock()
        self.request?.endAudio()
        self.newTask()
        self.lock.unlock()
      }
    }
  }

  func feed(_ buf: AVAudioPCMBuffer, heard: AVAudioPCMBuffer?) {
    lock.lock(); defer { lock.unlock() }
    recorder.write(buf)
    request?.append(heard ?? buf)
  }

  func stop() async {
    finishAll()
    try? await Task.sleep(for: .milliseconds(600))
  }
}

// MARK: - Capture: the Mac's audio (them) + the microphone (you)

/// Ask for the microphone before the capture starts, so the system's question never lands in the middle of a capture.
func microphoneAllowed() async -> Bool {
  switch AVCaptureDevice.authorizationStatus(for: .audio) {
  case .authorized: return true
  case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
  default: return false
  }
}

final class Capture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
  private var stream: SCStream?
  private let queue = DispatchQueue(label: "heypip.audio")
  var onAudio: ((AVAudioPCMBuffer, Speaker) -> Void)?
  var onError: ((String) -> Void)?

  func start() async throws {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let display = content.displays.first else {
      throw NSError(domain: "Pip", code: 2, userInfo: [NSLocalizedDescriptionKey: L10n.t("noDisplay")])
    }
    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.capturesAudio = true
    config.excludesCurrentProcessAudio = true
    config.captureMicrophone = true
    config.sampleRate = 48000
    config.channelCount = 1
    config.width = 2
    config.height = 2
    config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
    config.queueDepth = 3
    let s = SCStream(filter: filter, configuration: config, delegate: self)
    try s.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
    try s.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
    try await s.startCapture()
    stream = s
  }

  func stop() async {
    try? await stream?.stopCapture()
    stream = nil
  }

  func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
    let speaker: Speaker
    switch type {
    case .audio: speaker = .them
    case .microphone: speaker = .me
    default: return
    }
    guard sb.isValid, let buf = pcmBuffer(from: sb) else { return }
    onAudio?(buf, speaker)
  }

  func stream(_ stream: SCStream, didStopWithError error: Error) {
    onError?(error.localizedDescription)
  }
}
