import Foundation
import AVFoundation

// MARK: - Background Audio Manager
/// Plays a silent audio loop to prevent iOS suspension during active downloads
public final class BackgroundAudioManager {
    public static let shared = BackgroundAudioManager()
    private var player: AVAudioPlayer?
    private var isPlaying = false

    private init() {}

    public func start() {
        guard !isPlaying else { return }
        isPlaying = true

        guard let wav = generateSilentWAV() else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: wav)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            isPlaying = false
        }
    }

    public func stop() {
        guard isPlaying else { return }
        isPlaying = false
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func generateSilentWAV() -> Data? {
        let sampleRate = 8000
        let duration = 0.25
        let numSamples = Int(Double(sampleRate) * duration)
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = Int32(sampleRate) * Int32(numChannels) * Int32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = Int32(numSamples) * Int32(blockAlign)
        let fileSize = Int32(36) + dataSize

        var wav = Data()
        let write32 = { (value: Int32) in
            var v = value.littleEndian
            wav.append(Data(bytes: &v, count: MemoryLayout<Int32>.size))
        }
        let write16 = { (value: Int16) in
            var v = value.littleEndian
            wav.append(Data(bytes: &v, count: MemoryLayout<Int16>.size))
        }

        wav.append(contentsOf: "RIFF".utf8)
        write32(fileSize)
        wav.append(contentsOf: "WAVE".utf8)
        wav.append(contentsOf: "fmt ".utf8)
        write32(16)
        write16(1)         // PCM
        write16(numChannels)
        write32(Int32(sampleRate))
        write32(byteRate)
        write16(blockAlign)
        write16(bitsPerSample)
        wav.append(contentsOf: "data".utf8)
        write32(dataSize)
        wav.append(contentsOf: [UInt8](repeating: 0, count: Int(dataSize)))
        return wav
    }
}
