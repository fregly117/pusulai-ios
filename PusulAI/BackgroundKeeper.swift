import AVFoundation

/// Uygulama arka plandayken iOS'un onu askıya almaması için sessiz bir ses oturumu açık tutar.
/// Böylece sitenin canlı skor yoklaması sürer; favori maçta gol olunca bildirim + gol sesi gelir.
/// Pil için en fazla `maxDuration` kadar çalışır, sonra kendini kapatır.
final class BackgroundKeeper {

    static let shared = BackgroundKeeper()
    static let maxDuration: TimeInterval = 3 * 60 * 60 // 3 saat

    private var player: AVAudioPlayer?
    private var expireWork: DispatchWorkItem?
    private(set) var isActive = false

    func configureSession() {
        // mixWithOthers: Spotify / müzik kesilmez
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }

    func start(onExpire: @escaping () -> Void) {
        guard !isActive else { return }
        isActive = true
        configureSession()
        try? AVAudioSession.sharedInstance().setActive(true)

        if player == nil {
            player = try? AVAudioPlayer(data: BackgroundKeeper.silentWAV())
            player?.numberOfLoops = -1
            player?.volume = 0.01
            player?.prepareToPlay()
        }
        player?.play()

        let work = DispatchWorkItem { [weak self] in
            self?.stop()
            onExpire()
        }
        expireWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + BackgroundKeeper.maxDuration, execute: work)
    }

    func stop() {
        expireWork?.cancel()
        expireWork = nil
        guard isActive else { return }
        isActive = false
        player?.pause()
    }

    /// 1 saniyelik sessiz 16-bit mono WAV
    static func silentWAV(sampleRate: Int = 8000) -> Data {
        let dataSize = sampleRate * 2
        var d = Data()
        func appendU32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func appendU16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); appendU32(UInt32(36 + dataSize))
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); appendU32(16)
        appendU16(1); appendU16(1)
        appendU32(UInt32(sampleRate)); appendU32(UInt32(sampleRate * 2))
        appendU16(2); appendU16(16)
        d.append(contentsOf: Array("data".utf8)); appendU32(UInt32(dataSize))
        d.append(Data(count: dataSize))
        return d
    }
}
