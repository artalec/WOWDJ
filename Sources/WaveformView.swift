import SwiftUI

struct WaveformView: View {
    let data: [Float]
    let currentTime: TimeInterval
    let duration: TimeInterval
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                
                // Waveform bars
                HStack(spacing: 1) {
                    ForEach(0..<min(data.count, Int(geometry.size.width / 2)), id: \.self) { index in
                        let amplitude = data[index]
                        let normalizedHeight = CGFloat(amplitude) * geometry.size.height * 0.8
                        
                        Rectangle()
                            .fill(progressColor(for: index, geometry: geometry))
                            .frame(width: 2, height: max(normalizedHeight, 2))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
                // Progress indicator line
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: progressOffset(geometry: geometry))
            }
        }
        .frame(height: 80)
    }
    
    private func progressColor(for index: Int, geometry: GeometryProxy) -> Color {
        let progress = duration > 0 ? currentTime / duration : 0
        let indexProgress = Double(index) / Double(data.count)
        
        if indexProgress <= progress {
            return Color.blue
        } else {
            return Color.gray.opacity(0.6)
        }
    }
    
    private func progressOffset(geometry: GeometryProxy) -> CGFloat {
        guard duration > 0 else { return 0 }
        let progress = currentTime / duration
        return CGFloat(progress) * geometry.size.width
    }
}

// Preview
struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        WaveformView(
            data: (0..<100).map { _ in Float.random(in: 0...1) },
            currentTime: 30,
            duration: 180
        )
        .padding()
        .frame(height: 100)
    }
}
