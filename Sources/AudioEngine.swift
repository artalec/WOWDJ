import Foundation
import AVFoundation
import Combine

class AudioEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrack: Track?
    @Published var currentTime: TimeInterval = 0
    @Published var waveformData: [Float] = []
    
    private let engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var mainMixerNode: AVAudioMixerNode
    
    // Crossfade support
    private var nextPlayerNode: AVAudioPlayerNode?
    private var nextAudioFile: AVAudioFile?
    private var crossfadeTimer: Timer?
    
    // High-cut filter effect
    private var filterTimer: Timer?
    private var isFilterActive = false
    
    // Current audio file
    private var audioFile: AVAudioFile?
    private var displayLink: Timer?
    
    // Settings
    var settings: AppSettings = .default
    
    init() {
        mainMixerNode = engine.mainMixerNode
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        // Attach nodes
        engine.attach(playerNode)
        engine.attach(eqNode)
        
        // Configure EQ for high-cut filter effect
        for i in 0..<eqNode.bands.count {
            let band = eqNode.bands[i]
            band.filterType = .parametric
            band.bypass = false
        }
        
        // Connect nodes: player -> EQ -> mixer -> output
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        engine.connect(playerNode, to: eqNode, format: format)
        engine.connect(eqNode, to: mainMixerNode, format: format)
        
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    // MARK: - Playback Control
    
    func play(track: Track) {
        // Stop current track if high-cut filter is enabled
        if settings.highCutFilterEnabled && isPlaying {
            startHighCutFilterTransition(toTrack: track)
            return
        }
        
        // Standard play (with optional crossfade)
        if settings.crossfadeEnabled && isPlaying {
            startCrossfade(toTrack: track)
        } else {
            stop()
            playTrack(track)
        }
    }
    
    private func playTrack(_ track: Track) {
        do {
            // Load audio file
            audioFile = try AVAudioFile(forReading: track.url)
            guard let audioFile = audioFile else { return }
            
            let format = audioFile.processingFormat
            
            // Reconnect with correct format
            engine.disconnectNodeOutput(playerNode)
            engine.connect(playerNode, to: eqNode, format: format)
            
            // Schedule file
            playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.handleTrackFinished()
                }
            }
            
            // Start playback
            playerNode.play()
            
            DispatchQueue.main.async {
                self.currentTrack = track
                self.isPlaying = true
                self.generateWaveform(for: track)
                self.startTimeTracking()
            }
            
        } catch {
            print("Failed to play track: \(error)")
        }
    }
    
    func stop() {
        playerNode.stop()
        stopTimeTracking()
        crossfadeTimer?.invalidate()
        filterTimer?.invalidate()
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.isFilterActive = false
            self.resetEQ()
        }
    }
    
    func pause() {
        if isPlaying {
            playerNode.pause()
            stopTimeTracking()
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
    }
    
    func resume() {
        if !isPlaying && currentTrack != nil {
            playerNode.play()
            startTimeTracking()
            DispatchQueue.main.async {
                self.isPlaying = true
            }
        }
    }
    
    // MARK: - Crossfade
    
    private func startCrossfade(toTrack nextTrack: Track) {
        guard let audioFile = try? AVAudioFile(forReading: nextTrack.url) else { return }
        
        let fadeDuration = settings.crossfadeDuration
        let steps = 20
        let stepDuration = fadeDuration / Double(steps)
        var currentStep = 0
        
        // Create new player for next track
        let newPlayerNode = AVAudioPlayerNode()
        engine.attach(newPlayerNode)
        
        let format = audioFile.processingFormat
        engine.connect(newPlayerNode, to: mainMixerNode, format: format)
        
        // Schedule next track
        newPlayerNode.scheduleFile(audioFile, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.handleTrackFinished()
            }
        }
        
        // Start next track at volume 0
        newPlayerNode.volume = 0.0
        newPlayerNode.play()
        
        // Crossfade timer
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            
            // Fade out current, fade in next
            self.playerNode.volume = 1.0 - progress
            newPlayerNode.volume = progress
            
            if currentStep >= steps {
                timer.invalidate()
                
                // Switch to new player
                self.playerNode.stop()
                self.engine.detach(self.playerNode)
                self.playerNode = newPlayerNode
                
                DispatchQueue.main.async {
                    self.currentTrack = nextTrack
                    self.audioFile = audioFile
                    self.currentTime = 0
                    self.generateWaveform(for: nextTrack)
                }
            }
        }
    }
    
    // MARK: - High-Cut Filter Effect
    
    private func startHighCutFilterTransition(toTrack nextTrack: Track) {
        isFilterActive = true
        let filterDuration = settings.highCutFilterDuration
        let steps = 30
        let stepDuration = filterDuration / Double(steps)
        var currentStep = 0
        
        // Gradually reduce high frequencies
        filterTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            
            // Apply high-cut filter by reducing high frequency bands
            self.applyHighCutFilter(intensity: progress)
            
            if currentStep >= steps {
                timer.invalidate()
                
                // Stop current track and play next
                self.stop()
                self.playTrack(nextTrack)
            }
        }
    }
    
    private func applyHighCutFilter(intensity: Float) {
        // Reduce gain on higher frequency bands (simulating DJ high-cut filter)
        for i in 0..<eqNode.bands.count {
            let band = eqNode.bands[i]
            
            // Set frequency ranges
            let frequencies: [Float] = [60, 230, 910, 3600, 14000, 14000, 14000, 14000, 14000, 14000]
            band.frequency = frequencies[i]
            
            // Higher bands get more attenuation
            if i >= 5 {
                band.gain = -24 * intensity // Up to -24dB reduction
            } else if i >= 3 {
                band.gain = -12 * intensity
            }
        }
    }
    
    private func resetEQ() {
        for band in eqNode.bands {
            band.gain = 0
        }
    }
    
    // MARK: - Time Tracking
    
    private func startTimeTracking() {
        displayLink = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
    }
    
    private func stopTimeTracking() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func updateCurrentTime() {
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime),
              let audioFile = audioFile else {
            return
        }
        
        let currentPosition = Double(playerTime.sampleTime) / audioFile.processingFormat.sampleRate
        
        DispatchQueue.main.async {
            self.currentTime = currentPosition
        }
    }
    
    private func handleTrackFinished() {
        stop()
    }
    
    // MARK: - Waveform Generation
    
    func generateWaveform(for track: Track) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let audioFile = try? AVAudioFile(forReading: track.url) else {
                return
            }
            
            let samplesPerPixel = 1000
            let totalSamples = Int(audioFile.length)
            let numberOfPoints = totalSamples / samplesPerPixel
            
            var waveform: [Float] = []
            
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFile.processingFormat,
                frameCapacity: AVAudioFrameCount(audioFile.length)
            ) else { return }
            
            do {
                try audioFile.read(into: buffer)
                
                guard let floatData = buffer.floatChannelData?[0] else { return }
                
                for i in 0..<numberOfPoints {
                    let startIndex = i * samplesPerPixel
                    let endIndex = min(startIndex + samplesPerPixel, Int(buffer.frameLength))
                    
                    var maxAmplitude: Float = 0
                    for j in startIndex..<endIndex {
                        let amplitude = abs(floatData[j])
                        maxAmplitude = max(maxAmplitude, amplitude)
                    }
                    
                    waveform.append(maxAmplitude)
                }
                
                DispatchQueue.main.async {
                    self?.waveformData = waveform
                }
                
            } catch {
                print("Failed to generate waveform: \(error)")
            }
        }
    }
}
