//
//  VoiceRecorder.swift
//  Unfin
//

import Foundation
import AVFoundation

/// Records audio to a temporary file. Request permission before use; call start() then stop() to get the file URL.
final class VoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published var permissionDenied = false
    
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    
    override init() {
        super.init()
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionDenied = !granted
                completion(granted)
            }
        }
    }
    
    func start() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        
        let fileName = "voice_\(UUID().uuidString).m4a"
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(fileName)
        outputURL = url
        
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        isRecording = true
        return url
    }
    
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        isRecording = false
        let url = outputURL
        outputURL = nil
        return url
    }
    
    func cancel() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        if let url = outputURL {
            try? FileManager.default.removeItem(at: url)
        }
        outputURL = nil
    }
}
