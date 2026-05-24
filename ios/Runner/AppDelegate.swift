import AVFoundation
import Flutter
import TensorFlowLiteC
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var indoorEventSink: FlutterEventSink?
  private var indoorNavigationRunning = false
  private var indoorNavigationEngine: IndoorNavigationEngine?
  private weak var indoorRegistrar: FlutterPluginRegistrar?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard
      let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WareenyNativeBridge")
    else {
      return
    }
    indoorRegistrar = registrar
    let messenger = registrar.messenger()

    FlutterMethodChannel(
      name: "com.wareeny.bridge/audio_haptics",
      binaryMessenger: messenger
    ).setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "audio.speak":
        let arguments = call.arguments as? [String: Any]
        let text = arguments?["text"] as? String ?? ""
        let interrupt = arguments?["interrupt"] as? Bool ?? true
        self?.speak(text, interrupt: interrupt)
        result(nil)
      case "audio.stopSpeech":
        self?.speechSynthesizer.stopSpeaking(at: .immediate)
        result(nil)
      case "haptics.play":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterMethodChannel(
      name: "com.wareeny.bridge/indoor_navigation",
      binaryMessenger: messenger
    ).setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "indoorNav.start":
        self?.indoorNavigationRunning = true
        self?.ensureIndoorNavigationEngine()?.start()
        result(nil)
      case "indoorNav.stop":
        self?.indoorNavigationRunning = false
        self?.indoorNavigationEngine?.stop()
        result(nil)
      case "indoorNav.processFrame":
        self?.indoorNavigationEngine?.processFrame(call.arguments as? [String: Any])
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    FlutterEventChannel(
      name: "com.wareeny.bridge/indoor_navigation/events",
      binaryMessenger: messenger
    ).setStreamHandler(self)
  }

  private func ensureIndoorNavigationEngine() -> IndoorNavigationEngine? {
    if let indoorNavigationEngine {
      return indoorNavigationEngine
    }
    guard let indoorRegistrar else {
      return nil
    }

    let engine = IndoorNavigationEngine(registrar: indoorRegistrar) { [weak self] state in
      DispatchQueue.main.async {
        self?.emitPathState(state)
      }
    }
    indoorNavigationEngine = engine
    return engine
  }

  private func speak(_ text: String, interrupt: Bool) {
    if interrupt {
      speechSynthesizer.stopSpeaking(at: .immediate)
    }

    let utterance = AVSpeechUtterance(string: text)
    utterance.voice =
      AVSpeechSynthesisVoice(language: "ar-EG") ??
      AVSpeechSynthesisVoice(language: "ar")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    speechSynthesizer.speak(utterance)
  }

  @discardableResult
  private func emitPathState(_ state: IndoorPathState) -> Bool {
    guard indoorNavigationRunning else {
      return false
    }

    indoorEventSink?([
      "code": state.code,
      "severity": state.severity,
      "score": state.score,
      "stateText": state.stateText,
      "objectLabel": state.objectLabel as Any,
      "timestampMillis": Int(Date().timeIntervalSince1970 * 1000),
    ])
    return true
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    indoorEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    indoorEventSink = nil
    return nil
  }
}

private final class IndoorNavigationEngine {
  private let queue = DispatchQueue(label: "com.wareeny.indoorNavigation")
  private let planner = IndoorPathPlanner()
  private let emitState: (IndoorPathState) -> Void
  private let registrar: FlutterPluginRegistrar
  private var detector: YoloLiteRtDetector?
  private var running = false
  private var busy = false

  init(registrar: FlutterPluginRegistrar, emitState: @escaping (IndoorPathState) -> Void) {
    self.registrar = registrar
    self.emitState = emitState
  }

  func start() {
    running = true
    queue.async { [weak self] in
      guard let self, self.detector == nil else { return }
      do {
        self.detector = try YoloLiteRtDetector(registrar: self.registrar)
      } catch {
        self.emitState(IndoorPathPlanner.state("LOW LIGHT - UNCERTAIN", score: 0.58))
      }
    }
  }

  func stop() {
    running = false
    queue.async { [weak self] in
      self?.busy = false
    }
  }

  func processFrame(_ arguments: [String: Any]?) {
    guard running, let arguments else { return }
    queue.async { [weak self] in
      guard let self, self.running, !self.busy else { return }
      self.busy = true
      defer { self.busy = false }

      do {
        guard let converted = try IndoorCameraFrameConverter.convert(arguments) else { return }
        if converted.brightness < IndoorPathPlanner.darkFrameMeanThreshold {
          self.emitState(IndoorPathPlanner.state("LOW LIGHT - UNCERTAIN", score: 0.82))
          return
        }
        guard let detector = self.detector else { return }
        let detections = try detector.detect(frame: converted.frame)
        self.emitState(
          self.planner.analyze(
            detections: detections,
            frameWidth: converted.frame.width,
            frameHeight: converted.frame.height,
            brightness: converted.brightness
          )
        )
      } catch {
        self.emitState(IndoorPathPlanner.state("LOW LIGHT - UNCERTAIN", score: 0.58))
      }
    }
  }
}

private final class YoloLiteRtDetector {
  private let labels: [String]
  private let model: OpaquePointer
  private let options: OpaquePointer
  private let interpreter: OpaquePointer
  private let inputSize: Int
  private let outputChannels: Int
  private let outputBoxes: Int
  private let confidenceThreshold: Float
  private let nmsThreshold: Float

  init(registrar: FlutterPluginRegistrar) throws {
    let config = try IndoorModelConfig.load(registrar: registrar)
    labels = try Self.loadLabels(registrar: registrar, asset: config.labelsPath)
    let modelPath = Self.assetPath(registrar: registrar, asset: config.modelPath)
    guard let createdModel = TfLiteModelCreateFromFile(modelPath) else {
      throw IndoorNavigationError.modelLoadFailed
    }
    model = createdModel

    guard let createdOptions = TfLiteInterpreterOptionsCreate() else {
      TfLiteModelDelete(createdModel)
      throw IndoorNavigationError.modelLoadFailed
    }
    options = createdOptions
    TfLiteInterpreterOptionsSetNumThreads(options, 2)

    guard let createdInterpreter = TfLiteInterpreterCreate(model, options) else {
      TfLiteInterpreterOptionsDelete(options)
      TfLiteModelDelete(model)
      throw IndoorNavigationError.modelLoadFailed
    }
    interpreter = createdInterpreter

    guard TfLiteInterpreterAllocateTensors(interpreter) == kTfLiteOk else {
      TfLiteInterpreterDelete(interpreter)
      TfLiteInterpreterOptionsDelete(options)
      TfLiteModelDelete(model)
      throw IndoorNavigationError.modelLoadFailed
    }

    let inputTensor = TfLiteInterpreterGetInputTensor(interpreter, 0)
    inputSize = inputTensor.flatMap { TfLiteTensorNumDims($0) > 1 ? Int(TfLiteTensorDim($0, 1)) : nil } ?? config.inputSize

    let outputTensor = TfLiteInterpreterGetOutputTensor(interpreter, 0)
    outputChannels = outputTensor.flatMap { TfLiteTensorNumDims($0) > 1 ? Int(TfLiteTensorDim($0, 1)) : nil } ?? labels.count + 4
    outputBoxes = outputTensor.flatMap { TfLiteTensorNumDims($0) > 2 ? Int(TfLiteTensorDim($0, 2)) : nil } ?? 8400
    confidenceThreshold = config.confidenceThreshold
    nmsThreshold = config.nmsThreshold
  }

  deinit {
    TfLiteInterpreterDelete(interpreter)
    TfLiteInterpreterOptionsDelete(options)
    TfLiteModelDelete(model)
  }

  func detect(frame: RgbFrame) throws -> [NormalizedDetection] {
    let scaleX = Float(frame.width) / Float(inputSize)
    let scaleY = Float(frame.height) / Float(inputSize)
    var input = [Float32]()
    input.reserveCapacity(inputSize * inputSize * 3)

    for y in 0..<inputSize {
      let srcY = min(frame.height - 1, Int(Float(y) * scaleY))
      for x in 0..<inputSize {
        let srcX = min(frame.width - 1, Int(Float(x) * scaleX))
        let color = frame.pixels[srcY * frame.width + srcX]
        input.append(Float32((color >> 16) & 0xff) / 255.0)
        input.append(Float32((color >> 8) & 0xff) / 255.0)
        input.append(Float32(color & 0xff) / 255.0)
      }
    }

    guard let inputTensor = TfLiteInterpreterGetInputTensor(interpreter, 0) else {
      throw IndoorNavigationError.inferenceFailed
    }
    let inputStatus = input.withUnsafeBufferPointer { pointer in
      TfLiteTensorCopyFromBuffer(
        inputTensor,
        pointer.baseAddress,
        input.count * MemoryLayout<Float32>.size
      )
    }
    guard inputStatus == kTfLiteOk else {
      throw IndoorNavigationError.inferenceFailed
    }
    guard TfLiteInterpreterInvoke(interpreter) == kTfLiteOk,
      let outputTensor = TfLiteInterpreterGetOutputTensor(interpreter, 0)
    else {
      throw IndoorNavigationError.inferenceFailed
    }

    let outputCount = Int(TfLiteTensorByteSize(outputTensor)) / MemoryLayout<Float32>.size
    var output = [Float32](repeating: 0, count: outputCount)
    let outputByteCount = output.count * MemoryLayout<Float32>.size
    let outputStatus = output.withUnsafeMutableBufferPointer { pointer in
      TfLiteTensorCopyToBuffer(
        outputTensor,
        pointer.baseAddress,
        outputByteCount
      )
    }
    guard outputStatus == kTfLiteOk else {
      throw IndoorNavigationError.inferenceFailed
    }
    return nonMaxSuppression(decode(output: output, scaleX: scaleX, scaleY: scaleY))
  }

  private func decode(output: [Float32], scaleX: Float, scaleY: Float) -> [NormalizedDetection] {
    let classCount = min(labels.count, outputChannels - 4)
    var detections = [NormalizedDetection]()
    for boxIndex in 0..<outputBoxes {
      var bestClass = -1
      var bestScore: Float = 0
      for classIndex in 0..<classCount {
        let valueIndex = (4 + classIndex) * outputBoxes + boxIndex
        guard valueIndex < output.count else { continue }
        let score = output[valueIndex]
        if score > bestScore {
          bestScore = score
          bestClass = classIndex
        }
      }

      guard bestScore >= confidenceThreshold, bestClass >= 0, bestClass < labels.count else {
        continue
      }

      let cx = output[boxIndex] * scaleX
      let cy = output[outputBoxes + boxIndex] * scaleY
      let width = output[2 * outputBoxes + boxIndex] * scaleX
      let height = output[3 * outputBoxes + boxIndex] * scaleY
      detections.append(
        NormalizedDetection(
          label: labels[bestClass],
          confidence: bestScore,
          x1: cx - width / 2,
          y1: cy - height / 2,
          x2: cx + width / 2,
          y2: cy + height / 2
        )
      )
    }
    return detections
  }

  private func nonMaxSuppression(_ detections: [NormalizedDetection]) -> [NormalizedDetection] {
    var sorted = detections.sorted { $0.confidence > $1.confidence }
    var result = [NormalizedDetection]()
    while !sorted.isEmpty && result.count < 20 {
      let best = sorted.removeFirst()
      result.append(best)
      sorted.removeAll { other in
        other.label == best.label && iou(best, other) > nmsThreshold
      }
    }
    return result
  }

  private func iou(_ a: NormalizedDetection, _ b: NormalizedDetection) -> Float {
    let left = max(a.x1, b.x1)
    let top = max(a.y1, b.y1)
    let right = min(a.x2, b.x2)
    let bottom = min(a.y2, b.y2)
    let intersection = max(0, right - left) * max(0, bottom - top)
    let areaA = max(0, a.x2 - a.x1) * max(0, a.y2 - a.y1)
    let areaB = max(0, b.x2 - b.x1) * max(0, b.y2 - b.y1)
    return intersection / max(1, areaA + areaB - intersection)
  }

  private static func assetPath(registrar: FlutterPluginRegistrar, asset: String) -> String {
    let key = registrar.lookupKey(forAsset: asset)
    if let path = Bundle.main.path(forResource: key, ofType: nil) {
      return path
    }
    return Bundle.main.path(forResource: "flutter_assets/\(asset)", ofType: nil) ?? asset
  }

  private static func loadLabels(registrar: FlutterPluginRegistrar, asset: String) throws -> [String] {
    let path = assetPath(registrar: registrar, asset: asset)
    return try String(contentsOfFile: path)
      .split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

private struct IndoorModelConfig {
  let modelPath: String
  let labelsPath: String
  let inputSize: Int
  let confidenceThreshold: Float
  let nmsThreshold: Float

  static func load(registrar: FlutterPluginRegistrar) throws -> IndoorModelConfig {
    let key = registrar.lookupKey(forAsset: "assets/models/indoor_navigation/manifest.json")
    let path =
      Bundle.main.path(forResource: key, ofType: nil) ??
      Bundle.main.path(forResource: "flutter_assets/assets/models/indoor_navigation/manifest.json", ofType: nil) ??
      key
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return IndoorModelConfig(
      modelPath: json?["modelPath"] as? String ?? "assets/models/indoor_navigation/model.tflite",
      labelsPath: json?["labelsPath"] as? String ?? "assets/models/indoor_navigation/labels.txt",
      inputSize: json?["inputSize"] as? Int ?? 640,
      confidenceThreshold: (json?["confidenceThreshold"] as? NSNumber)?.floatValue ?? 0.35,
      nmsThreshold: (json?["nmsThreshold"] as? NSNumber)?.floatValue ?? 0.45
    )
  }
}

private enum IndoorNavigationError: Error {
  case modelLoadFailed
  case inferenceFailed
}

private struct IndoorCameraFrameConverter {
  static func convert(_ arguments: [String: Any]) throws -> (frame: RgbFrame, brightness: Double)? {
    guard
      let width = arguments["width"] as? Int,
      let height = arguments["height"] as? Int,
      let planes = arguments["planes"] as? [[String: Any]],
      let firstPlane = planes.first,
      let firstBytes = firstPlane["bytes"] as? FlutterStandardTypedData
    else {
      return nil
    }

    if planes.count == 1 {
      return convertBgra(width: width, height: height, plane: firstPlane, data: firstBytes.data)
    }
    return convertYuv(width: width, height: height, planes: planes)
  }

  private static func convertBgra(
    width: Int,
    height: Int,
    plane: [String: Any],
    data: Data
  ) -> (frame: RgbFrame, brightness: Double)? {
    let bytesPerRow = plane["bytesPerRow"] as? Int ?? width * 4
    var pixels = [Int](repeating: 0, count: width * height)
    var brightness = 0.0
    var count = 0

    data.withUnsafeBytes { rawBuffer in
      let bytes = rawBuffer.bindMemory(to: UInt8.self)
      for y in 0..<height {
        for x in 0..<width {
          let index = y * bytesPerRow + x * 4
          guard index + 2 < bytes.count else { continue }
          let b = Int(bytes[index])
          let g = Int(bytes[index + 1])
          let r = Int(bytes[index + 2])
          pixels[y * width + x] = (r << 16) | (g << 8) | b
          brightness += 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
          count += 1
        }
      }
    }

    guard count > 0 else { return nil }
    return (RgbFrame(width: width, height: height, pixels: pixels), brightness / Double(count))
  }

  private static func convertYuv(
    width: Int,
    height: Int,
    planes: [[String: Any]]
  ) -> (frame: RgbFrame, brightness: Double)? {
    guard
      planes.count >= 3,
      let yBytes = (planes[0]["bytes"] as? FlutterStandardTypedData)?.data,
      let uBytes = (planes[1]["bytes"] as? FlutterStandardTypedData)?.data,
      let vBytes = (planes[2]["bytes"] as? FlutterStandardTypedData)?.data
    else {
      return nil
    }

    let yRowStride = planes[0]["bytesPerRow"] as? Int ?? width
    let uRowStride = planes[1]["bytesPerRow"] as? Int ?? width / 2
    let vRowStride = planes[2]["bytesPerRow"] as? Int ?? width / 2
    let uPixelStride = planes[1]["bytesPerPixel"] as? Int ?? 1
    let vPixelStride = planes[2]["bytesPerPixel"] as? Int ?? 1
    var pixels = [Int](repeating: 0, count: width * height)
    var brightness = 0.0
    var count = 0

    yBytes.withUnsafeBytes { yRaw in
      uBytes.withUnsafeBytes { uRaw in
        vBytes.withUnsafeBytes { vRaw in
          let yBuffer = yRaw.bindMemory(to: UInt8.self)
          let uBuffer = uRaw.bindMemory(to: UInt8.self)
          let vBuffer = vRaw.bindMemory(to: UInt8.self)
          for y in 0..<height {
            for x in 0..<width {
              let yIndex = y * yRowStride + x
              let uIndex = (y / 2) * uRowStride + (x / 2) * uPixelStride
              let vIndex = (y / 2) * vRowStride + (x / 2) * vPixelStride
              guard yIndex < yBuffer.count, uIndex < uBuffer.count, vIndex < vBuffer.count else {
                continue
              }

              let yy = Int(yBuffer[yIndex])
              let uu = Int(uBuffer[uIndex]) - 128
              let vv = Int(vBuffer[vIndex]) - 128
              let r = clamp(yy + Int(1.402 * Double(vv)))
              let g = clamp(yy - Int(0.344136 * Double(uu)) - Int(0.714136 * Double(vv)))
              let b = clamp(yy + Int(1.772 * Double(uu)))
              pixels[y * width + x] = (r << 16) | (g << 8) | b
              brightness += Double(yy)
              count += 1
            }
          }
        }
      }
    }

    guard count > 0 else { return nil }
    return (RgbFrame(width: width, height: height, pixels: pixels), brightness / Double(count))
  }

  private static func clamp(_ value: Int) -> Int {
    min(255, max(0, value))
  }
}

private struct NormalizedDetection {
  let label: String
  let confidence: Float
  let x1: Float
  let y1: Float
  let x2: Float
  let y2: Float
}

private struct IndoorPathState {
  let code: String
  let severity: String
  let score: Double
  let stateText: String
  let objectLabel: String?
}

private struct RgbFrame {
  let width: Int
  let height: Int
  let pixels: [Int]
}

private final class IndoorPathPlanner {
  static let darkFrameMeanThreshold = 30.0
  private var recentStates = [String]()

  func analyze(
    detections: [NormalizedDetection],
    frameWidth: Int,
    frameHeight: Int,
    brightness: Double
  ) -> IndoorPathState {
    let raw = analyzeRaw(detections: detections, frameWidth: frameWidth, frameHeight: frameHeight, brightness: brightness)
    recentStates.append(raw.stateText)
    if recentStates.count > Self.smoothingWindow {
      recentStates.removeFirst()
    }
    let smoothed = smoothedState(fallback: raw.stateText)
    return smoothed == raw.stateText ? raw : Self.state(smoothed)
  }

  private func analyzeRaw(
    detections: [NormalizedDetection],
    frameWidth: Int,
    frameHeight: Int,
    brightness: Double
  ) -> IndoorPathState {
    if brightness < Self.darkFrameMeanThreshold {
      return Self.state("LOW LIGHT - UNCERTAIN", score: 0.82)
    }

    let grid = buildOccupancyGrid(detections: detections, frameWidth: frameWidth, frameHeight: frameHeight)
    let center = centerLaneBounds(frameWidth: frameWidth)
    var bestText = "CLEAR PATH"
    var bestDetection: NormalizedDetection?
    var bestScore = 0.0

    for detection in detections {
      let classified = classifyDetection(detection, frameWidth: frameWidth, frameHeight: frameHeight, centerLeft: center.0, centerRight: center.1)
      if classified.text != "CLEAR PATH" &&
        (Self.priority(classified.text) > Self.priority(bestText) ||
          (classified.text == bestText && classified.score > bestScore))
      {
        bestText = classified.text
        bestDetection = detection
        bestScore = classified.score
      }
    }

    let narrowScore = narrowPathScore(detections: detections, frameWidth: frameWidth, frameHeight: frameHeight)
    if narrowScore > 0 &&
      (["CLEAR PATH", "CAUTION LEFT", "CAUTION RIGHT", "OBSTACLE AHEAD", "TRIP HAZARD CENTER"].contains(bestText) ||
        (bestText == "PATH BLOCKED" && bestDetection != nil && !fillsVirtualPath(bestDetection!, frameWidth: frameWidth, frameHeight: frameHeight)))
    {
      return Self.state("NARROW PATH", score: narrowScore)
    }

    if let detection = bestDetection,
      ["OBSTACLE AHEAD", "TRIP HAZARD CENTER", "PATH BLOCKED"].contains(bestText)
    {
      let planned = planLocalRoute(grid: grid, blockingDetection: detection, frameWidth: frameWidth, frameHeight: frameHeight)
      return Self.state(planned, score: bestScore, objectLabel: detection.label)
    }

    return Self.state(bestText, score: bestScore, objectLabel: bestDetection?.label)
  }

  private func classifyDetection(
    _ detection: NormalizedDetection,
    frameWidth: Int,
    frameHeight: Int,
    centerLeft: Double,
    centerRight: Double
  ) -> (text: String, score: Double) {
    let width = max(0, Double(detection.x2 - detection.x1))
    let height = max(0, Double(detection.y2 - detection.y1))
    let areaRatio = (width * height) / Double(frameWidth * frameHeight)
    let boxCenterX = Double(detection.x1 + detection.x2) / 2
    let bottomRatio = Double(detection.y2) / Double(frameHeight)
    let band = depthBand(bottomRatio)
    let lowerFrame = bottomRatio >= Self.lowerFrameStartRatio
    let nearFloor = bottomRatio >= Self.nearBottomRatio
    let veryNear = bottomRatio >= Self.veryNearBottomRatio
    let triangle = pathTriangle(frameWidth: frameWidth, frameHeight: frameHeight)
    let triangleOverlap = triangleBoxOverlapRatio(detection, triangle: triangle)
    let triangleFill = triangleFillRatio(detection, triangle: triangle, frameHeight: frameHeight)
    let centerOverlap = overlapRatio(Double(detection.x1), Double(detection.x2), centerLeft, centerRight)
    let inCenterLane = centerOverlap >= Self.centerOverlapRatio || triangleOverlap >= Self.triangleWarningOverlapRatio
    let tripClass = Self.tripHazardClasses.contains(detection.label.lowercased())
    let largeObject = areaRatio >= Self.largeBoxAreaRatio
    let meaningfulTripSize = areaRatio >= Self.minTripAreaRatio
    let riskScore = (
      Double(detection.confidence) * 0.35 +
        min(areaRatio / Self.largeBoxAreaRatio, 1) * 0.25 +
        bottomRatio * 0.25 +
        max(centerOverlap, triangleOverlap) * 0.15
    ).clamped01()
    let fillsPath = (band != .far && triangleFill >= Self.triangleFillBlockedRatio) ||
      (nearFloor && triangleFill >= Self.triangleNearFillBlockedRatio)
    let collisionOverlap = triangleOverlap >= Self.triangleCollisionOverlapRatio

    if inCenterLane && (veryNear || fillsPath || (largeObject && lowerFrame && collisionOverlap)) {
      return ("PATH BLOCKED", riskScore)
    }
    if inCenterLane && tripClass && nearFloor && meaningfulTripSize && collisionOverlap {
      return ("TRIP HAZARD CENTER", riskScore)
    }
    if inCenterLane && (largeObject || (tripClass && lowerFrame) || collisionOverlap) {
      return ("OBSTACLE AHEAD", riskScore)
    }
    if lowerFrame && (tripClass || largeObject) {
      if boxCenterX < centerLeft { return ("CAUTION LEFT", riskScore) }
      if boxCenterX > centerRight { return ("CAUTION RIGHT", riskScore) }
    }
    return ("CLEAR PATH", riskScore)
  }

  private func smoothedState(fallback: String) -> String {
    if recentStates.count < Self.requiredVotes { return fallback }
    let counts = Dictionary(grouping: recentStates, by: { $0 }).mapValues(\.count)
    let candidates = counts.filter { $0.value >= Self.requiredVotes }.map(\.key)
    return candidates.max { Self.priority($0) < Self.priority($1) } ?? fallback
  }

  private func planLocalRoute(
    grid: [DepthBand: [Lane: Double]],
    blockingDetection: NormalizedDetection,
    frameWidth: Int,
    frameHeight: Int
  ) -> String {
    if fillsVirtualPath(blockingDetection, frameWidth: frameWidth, frameHeight: frameHeight) {
      return "PATH BLOCKED"
    }
    let obstacleBand = depthBand(Double(blockingDetection.y2) / Double(frameHeight))
    let nearCenter = grid[.near]?[.center] ?? 0
    let leftNear = grid[.near]?[.left] ?? 0
    let rightNear = grid[.near]?[.right] ?? 0
    let leftRoute = routeScore(grid: grid, lane: .left)
    let rightRoute = routeScore(grid: grid, lane: .right)
    let leftIsClear = leftNear < Self.sideClearScoreThreshold
    let rightIsClear = rightNear < Self.sideClearScoreThreshold
    let centerIsClearNow = nearCenter < Self.centerClearScoreThreshold
    let blockerCenter = Double(blockingDetection.x1 + blockingDetection.x2) / 2

    if [.far, .mid].contains(obstacleBand) && centerIsClearNow {
      return delayedTurnState(leftRoute: leftRoute, rightRoute: rightRoute, blockerCenter: blockerCenter, frameWidth: frameWidth)
    }
    if leftIsClear && rightIsClear {
      return immediateTurnState(leftRoute: leftRoute, rightRoute: rightRoute, blockerCenter: blockerCenter, frameWidth: frameWidth)
    }
    if leftIsClear { return "MOVE LEFT" }
    if rightIsClear { return "MOVE RIGHT" }
    return "PATH BLOCKED"
  }

  private func fillsVirtualPath(_ detection: NormalizedDetection, frameWidth: Int, frameHeight: Int) -> Bool {
    let bottomRatio = Double(detection.y2) / Double(frameHeight)
    if depthBand(bottomRatio) == .far { return false }
    let fill = triangleFillRatio(detection, triangle: pathTriangle(frameWidth: frameWidth, frameHeight: frameHeight), frameHeight: frameHeight)
    return fill >= Self.triangleFillBlockedRatio ||
      (bottomRatio >= Self.nearBottomRatio && fill >= Self.triangleNearFillBlockedRatio)
  }

  private func delayedTurnState(leftRoute: Double, rightRoute: Double, blockerCenter: Double, frameWidth: Int) -> String {
    if abs(leftRoute - rightRoute) <= Self.routeBalanceMargin {
      if blockerCenter < Double(frameWidth) / 2 { return "FORWARD THEN SLIGHT RIGHT" }
      if blockerCenter > Double(frameWidth) / 2 { return "FORWARD THEN SLIGHT LEFT" }
      return "FORWARD A LITTLE"
    }
    if leftRoute < rightRoute { return "FORWARD THEN SLIGHT LEFT" }
    if rightRoute < leftRoute { return "FORWARD THEN SLIGHT RIGHT" }
    return "PATH BLOCKED"
  }

  private func immediateTurnState(leftRoute: Double, rightRoute: Double, blockerCenter: Double, frameWidth: Int) -> String {
    if abs(leftRoute - rightRoute) <= Self.routeBalanceMargin {
      if blockerCenter < Double(frameWidth) / 2 { return "MOVE RIGHT" }
      if blockerCenter > Double(frameWidth) / 2 { return "MOVE LEFT" }
      return "PATH BLOCKED"
    }
    if leftRoute < rightRoute { return "MOVE LEFT" }
    if rightRoute < leftRoute { return "MOVE RIGHT" }
    return "PATH BLOCKED"
  }

  private func buildOccupancyGrid(detections: [NormalizedDetection], frameWidth: Int, frameHeight: Int) -> [DepthBand: [Lane: Double]] {
    var grid: [DepthBand: [Lane: Double]] = [
      .far: [.left: 0, .center: 0, .right: 0],
      .mid: [.left: 0, .center: 0, .right: 0],
      .near: [.left: 0, .center: 0, .right: 0],
    ]
    let lanes: [Lane: (Double, Double)] = [
      .left: (0, Double(frameWidth) / 3),
      .center: (Double(frameWidth) / 3, Double(frameWidth) * 2 / 3),
      .right: (Double(frameWidth) * 2 / 3, Double(frameWidth)),
    ]

    for detection in detections {
      let bottomRatio = Double(detection.y2) / Double(frameHeight)
      if bottomRatio < Self.farBandStartRatio { continue }
      let width = max(0, Double(detection.x2 - detection.x1))
      let height = max(0, Double(detection.y2 - detection.y1))
      let areaRatio = (width * height) / Double(frameWidth * frameHeight)
      let band = depthBand(bottomRatio)
      let classWeight = Self.tripHazardClasses.contains(detection.label.lowercased()) ? 1.0 : 0.55
      let baseScore = Double(detection.confidence) * classWeight * (0.45 + min(areaRatio / Self.largeBoxAreaRatio, 1)) * bottomRatio
      for (lane, bounds) in lanes {
        let overlap = overlapRatio(Double(detection.x1), Double(detection.x2), bounds.0, bounds.1)
        if overlap > 0 {
          grid[band]?[lane, default: 0] += baseScore * overlap
        }
      }
    }
    return grid
  }

  private func narrowPathScore(detections: [NormalizedDetection], frameWidth: Int, frameHeight: Int) -> Double {
    let triangle = pathTriangle(frameWidth: frameWidth, frameHeight: frameHeight)
    var leftFill = 0.0
    var rightFill = 0.0
    var centerFill = 0.0

    for detection in detections {
      let bottomRatio = Double(detection.y2) / Double(frameHeight)
      if bottomRatio < Self.midBandStartRatio { continue }
      let side = triangleSideFill(detection, triangle: triangle, frameHeight: frameHeight)
      if fillsVirtualPath(detection, frameWidth: frameWidth, frameHeight: frameHeight) {
        centerFill = max(centerFill, side[.center] ?? 0)
        continue
      }
      leftFill = max(leftFill, side[.left] ?? 0)
      rightFill = max(rightFill, side[.right] ?? 0)
      centerFill = max(centerFill, side[.center] ?? 0)
    }

    let leftPresent = leftFill >= Self.narrowPathSideFillRatio
    let rightPresent = rightFill >= Self.narrowPathSideFillRatio
    let centerOpen = centerFill <= Self.narrowPathCenterFillMaxRatio
    return leftPresent && rightPresent && centerOpen ? min(leftFill, rightFill) + (1 - centerFill) * 0.25 : 0
  }

  private func triangleSideFill(_ detection: NormalizedDetection, triangle: PathTriangle, frameHeight: Int) -> [Lane: Double] {
    let y1 = max(Double(detection.y1), triangle.apexY)
    let y2 = min(Double(detection.y2), triangle.bottomY)
    if y2 <= y1 { return [.left: 0, .center: 0, .right: 0] }
    var fills: [Lane: Double] = [.left: 0, .center: 0, .right: 0]
    for index in 0..<Self.triangleSampleRows {
      let y = y1 + ((Double(index) + 0.5) / Double(Self.triangleSampleRows)) * (y2 - y1)
      let bounds = triangleBoundsAtY(triangle, y: y)
      let pathWidth = max(1, bounds.1 - bounds.0)
      let laneWidth = pathWidth / 3
      let lanes: [Lane: (Double, Double)] = [
        .left: (bounds.0, bounds.0 + laneWidth),
        .center: (bounds.0 + laneWidth, bounds.1 - laneWidth),
        .right: (bounds.1 - laneWidth, bounds.1),
      ]
      for (lane, laneBounds) in lanes {
        let overlap = max(0, min(Double(detection.x2), laneBounds.1) - max(Double(detection.x1), laneBounds.0))
        fills[lane, default: 0] += overlap / max(1, laneBounds.1 - laneBounds.0)
      }
    }
    let weight: Double
    switch depthBand(Double(detection.y2) / Double(frameHeight)) {
    case .far:
      weight = 0.65
    case .mid:
      weight = 0.85
    case .near:
      weight = 1.0
    }
    return fills.mapValues { $0 / Double(Self.triangleSampleRows) * weight }
  }

  private func pathTriangle(frameWidth: Int, frameHeight: Int) -> PathTriangle {
    let center = Double(frameWidth) / 2
    let topY = Double(frameHeight) * Self.pathTriangleTopYRatio
    let bottomY = Double(frameHeight)
    let topHalfWidth = Double(frameWidth) * Self.pathTriangleTopWidthRatio / 2
    let bottomHalfWidth = Double(frameWidth) * Self.pathTriangleBottomWidthRatio / 2
    return PathTriangle(
      apexY: topY,
      topLeftX: center - topHalfWidth,
      topRightX: center + topHalfWidth,
      bottomLeftX: center - bottomHalfWidth,
      bottomRightX: center + bottomHalfWidth,
      bottomY: bottomY
    )
  }

  private func triangleBoundsAtY(_ triangle: PathTriangle, y: Double) -> (Double, Double) {
    if y <= triangle.apexY { return (triangle.topLeftX, triangle.topRightX) }
    let progress = ((y - triangle.apexY) / (triangle.bottomY - triangle.apexY)).clamped01()
    return (
      triangle.topLeftX + (triangle.bottomLeftX - triangle.topLeftX) * progress,
      triangle.topRightX + (triangle.bottomRightX - triangle.topRightX) * progress
    )
  }

  private func triangleBoxOverlapRatio(_ detection: NormalizedDetection, triangle: PathTriangle) -> Double {
    let y1 = max(Double(detection.y1), triangle.apexY)
    let y2 = min(Double(detection.y2), triangle.bottomY)
    if y2 <= y1 { return 0 }
    var total = 0.0
    for index in 0..<Self.triangleSampleRows {
      let y = y1 + ((Double(index) + 0.5) / Double(Self.triangleSampleRows)) * (y2 - y1)
      let bounds = triangleBoundsAtY(triangle, y: y)
      total += overlapRatio(Double(detection.x1), Double(detection.x2), bounds.0, bounds.1)
    }
    return total / Double(Self.triangleSampleRows)
  }

  private func triangleFillRatio(_ detection: NormalizedDetection, triangle: PathTriangle, frameHeight: Int) -> Double {
    let y1 = max(Double(detection.y1), triangle.apexY)
    let y2 = min(Double(detection.y2), triangle.bottomY)
    if y2 <= y1 { return 0 }
    var total = 0.0
    for index in 0..<Self.triangleSampleRows {
      let y = y1 + ((Double(index) + 0.5) / Double(Self.triangleSampleRows)) * (y2 - y1)
      let bounds = triangleBoundsAtY(triangle, y: y)
      let pathWidth = max(1, bounds.1 - bounds.0)
      let overlap = max(0, min(Double(detection.x2), bounds.1) - max(Double(detection.x1), bounds.0))
      total += overlap / pathWidth
    }
    let weight: Double
    switch depthBand(Double(detection.y2) / Double(frameHeight)) {
    case .far:
      weight = 0.65
    case .mid:
      weight = 0.85
    case .near:
      weight = 1.0
    }
    return total / Double(Self.triangleSampleRows) * weight
  }

  private func routeScore(grid: [DepthBand: [Lane: Double]], lane: Lane) -> Double {
    (grid[.near]?[lane] ?? 0) + (grid[.mid]?[lane] ?? 0) * 0.7 + (grid[.far]?[lane] ?? 0) * 0.45
  }

  private func depthBand(_ bottomRatio: Double) -> DepthBand {
    if bottomRatio >= Self.nearBandStartRatio { return .near }
    if bottomRatio >= Self.midBandStartRatio { return .mid }
    return .far
  }

  private func centerLaneBounds(frameWidth: Int) -> (Double, Double) {
    let laneWidth = Double(frameWidth) * Self.centerLaneWidthRatio
    let center = Double(frameWidth) / 2
    return (center - laneWidth / 2, center + laneWidth / 2)
  }

  private func overlapRatio(_ x1: Double, _ x2: Double, _ laneX1: Double, _ laneX2: Double) -> Double {
    let overlap = max(0, min(x2, laneX2) - max(x1, laneX1))
    return overlap / max(1, x2 - x1)
  }

  static func state(_ stateText: String, score: Double = 0, objectLabel: String? = nil) -> IndoorPathState {
    IndoorPathState(
      code: code(for: stateText),
      severity: severity(for: stateText),
      score: score.clamped01(),
      stateText: stateText,
      objectLabel: objectLabel
    )
  }

  private static func priority(_ stateText: String) -> Int {
    switch stateText {
    case "CLEAR PATH":
      return 0
    case "CAUTION LEFT", "CAUTION RIGHT":
      return 1
    case "OBSTACLE AHEAD", "FORWARD A LITTLE", "KEEP LEFT", "KEEP RIGHT", "NARROW PATH":
      return 2
    case "TRIP HAZARD CENTER", "MOVE LEFT", "MOVE RIGHT", "FORWARD THEN SLIGHT LEFT", "FORWARD THEN SLIGHT RIGHT":
      return 3
    case "PATH BLOCKED":
      return 4
    default:
      return 5
    }
  }

  private static func code(for stateText: String) -> String {
    switch stateText {
    case "CLEAR PATH":
      return "clear_path"
    case "CAUTION LEFT":
      return "caution_left"
    case "CAUTION RIGHT":
      return "caution_right"
    case "OBSTACLE AHEAD":
      return "obstacle_ahead"
    case "TRIP HAZARD CENTER":
      return "trip_hazard_center"
    case "MOVE LEFT":
      return "move_left"
    case "MOVE RIGHT":
      return "move_right"
    case "FORWARD A LITTLE":
      return "forward_keep_center"
    case "FORWARD THEN SLIGHT LEFT":
      return "forward_then_slight_left"
    case "FORWARD THEN SLIGHT RIGHT":
      return "forward_then_slight_right"
    case "KEEP LEFT":
      return "keep_left"
    case "KEEP RIGHT":
      return "keep_right"
    case "NARROW PATH":
      return "narrow_path"
    case "PATH BLOCKED":
      return "path_blocked"
    default:
      return "low_light_uncertain"
    }
  }

  private static func severity(for stateText: String) -> String {
    switch stateText {
    case "CLEAR PATH":
      return "clear"
    case "OBSTACLE AHEAD", "TRIP HAZARD CENTER":
      return "obstacle"
    case "PATH BLOCKED":
      return "danger"
    case "LOW LIGHT - UNCERTAIN":
      return "uncertain"
    default:
      return "navigationCue"
    }
  }

  private enum Lane { case left, center, right }
  private enum DepthBand { case far, mid, near }
  private struct PathTriangle {
    let apexY: Double
    let topLeftX: Double
    let topRightX: Double
    let bottomLeftX: Double
    let bottomRightX: Double
    let bottomY: Double
  }

  private static let centerLaneWidthRatio = 0.42
  private static let pathTriangleTopYRatio = 0.28
  private static let pathTriangleTopWidthRatio = 0.12
  private static let pathTriangleBottomWidthRatio = 0.82
  private static let triangleSampleRows = 7
  private static let triangleCollisionOverlapRatio = 0.28
  private static let triangleWarningOverlapRatio = 0.1
  private static let triangleFillBlockedRatio = 0.46
  private static let triangleNearFillBlockedRatio = 0.32
  private static let narrowPathSideFillRatio = 0.18
  private static let narrowPathCenterFillMaxRatio = 0.28
  private static let lowerFrameStartRatio = 0.48
  private static let nearBottomRatio = 0.78
  private static let veryNearBottomRatio = 0.9
  private static let largeBoxAreaRatio = 0.13
  private static let centerOverlapRatio = 0.18
  private static let minTripAreaRatio = 0.015
  private static let farBandStartRatio = 0.48
  private static let midBandStartRatio = 0.66
  private static let nearBandStartRatio = 0.82
  private static let sideClearScoreThreshold = 0.55
  private static let centerClearScoreThreshold = 0.35
  private static let routeBalanceMargin = 0.12
  private static let smoothingWindow = 5
  private static let requiredVotes = 2
  private static let tripHazardClasses: Set<String> = [
    "chair", "couch", "bench", "dining table", "table", "person", "backpack",
    "handbag", "suitcase", "sports ball", "potted plant", "bed", "toilet",
    "tv", "refrigerator", "microwave", "oven", "sink", "laptop", "keyboard",
    "book", "box", "bottle",
  ]
}

private extension Double {
  func clamped01() -> Double {
    min(1, max(0, self))
  }
}
