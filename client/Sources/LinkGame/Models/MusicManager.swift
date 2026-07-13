import AVFoundation
import SwiftUI

class MusicManager: ObservableObject {
    static let shared = MusicManager()

    @Published var outputVolume: Float = 0.3
    @Published var outputMuted: Bool = false

    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode?
    private var isRunning = false
    private var masterGain: Float = 0.3

    private let sampleRate: Double = 44100

    private let scale: [Float] = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25]
    private let melody: [Int] = [0, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 5, 4, 3, 2, 0]
    private let chords: [Int] = [0, 0, 2, 2, 3, 3, 0, 0]
    private let bpm: Double = 72
    private var phase: Double = 0

    private init() {
        outputMuted = UserDefaults.standard.bool(forKey: "music_muted")
        let saved = UserDefaults.standard.float(forKey: "music_volume")
        if saved > 0 { outputVolume = saved }
        masterGain = outputMuted ? 0 : outputVolume
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            self.setupAudio()
            do {
                try self.engine.start()
            } catch {
                print("[MusicManager] engine start failed: \(error)")
                DispatchQueue.main.async { self.isRunning = false }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        engine.stop()
    }

    func toggleMute() {
        outputMuted.toggle()
        UserDefaults.standard.set(outputMuted, forKey: "music_muted")
        masterGain = outputMuted ? 0 : outputVolume
    }

    func setVolume(_ vol: Float) {
        outputVolume = vol
        UserDefaults.standard.set(vol, forKey: "music_volume")
        if !outputMuted {
            masterGain = vol
        }
    }

    private func setupAudio() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 25
        engine.attach(reverb)

        let srcNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            self?.renderFrames(frameCount, bufferList: audioBufferList)
            return noErr
        }
        engine.attach(srcNode)
        sourceNode = srcNode

        engine.connect(srcNode, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
    }

    private func renderFrames(_ frameCount: AVAudioFrameCount, bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let left = abl[0].mData?.assumingMemoryBound(to: Float.self),
              let right = abl[1].mData?.assumingMemoryBound(to: Float.self) else { return }

        let secondsPerBeat = 60.0 / bpm
        let secondsPerNote = secondsPerBeat * 2
        let loopSeconds = Double(melody.count) * secondsPerNote

        for frame in 0..<Int(frameCount) {
            let t = phase + Double(frame) / sampleRate
            let loopT = t.truncatingRemainder(dividingBy: loopSeconds)

            let melodyBeat = loopT / secondsPerBeat
            let ni = min(Int(melodyBeat / 2), melody.count - 1)
            let noteFreq = scale[melody[ni]]
            let noteStart = Double(ni) * secondsPerNote
            let noteT = loopT - noteStart
            let env: Float = {
                if noteT < 0.04 { return Float(noteT / 0.04) }
                if noteT > secondsPerNote - 0.15 { return Float((secondsPerNote - noteT) / 0.15) }
                return 1.0
            }()

            let melodySample = sinf(Float(2.0 * .pi) * noteFreq * Float(t)) * 0.25 * env

            let ci = min(Int((loopT / secondsPerBeat) / 4), chords.count - 1)
            let bassSample = sinf(Float(2.0 * .pi) * (scale[chords[ci]] / 2.0) * Float(t)) * 0.15

            let padFreq = scale[ci % scale.count] * 2.0
            let mod = 0.5 + 0.5 * sinf(Float(loopT) * 0.3)
            let padSample = sinf(Float(2.0 * .pi) * padFreq * Float(t)) * 0.06 * mod

            let sample = (melodySample + bassSample + padSample) * 0.7 * masterGain
            left[frame] = sample
            right[frame] = sample
        }

        phase += Double(frameCount) / sampleRate
        phase.formTruncatingRemainder(dividingBy: loopSeconds)
    }
}
