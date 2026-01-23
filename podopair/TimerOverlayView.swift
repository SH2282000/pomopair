import SwiftUI
import AVFoundation
import Combine

struct TimerOverlayView: View {
    @StateObject private var viewModel = TimerViewModel()
    
    var body: some View {
        ZStack {
            // Soft Background
            ZStack {
                AnimatedBlobView(phase: viewModel.isRunning ? 360 : 0)
                    .blur(radius: 20)
                    .opacity(0.8)
                
                Color.black.opacity(0.2) // Slight dim for readability
            }
            .mask(
                Circle()
                    .frame(width: 350, height: 350)
                    .blur(radius: 10)
            )
            
            // Progress Ring (Surrounding everything)
            if viewModel.isRunning {
                Circle()
                    .trim(from: 0, to: viewModel.progress)
                    .stroke(
                        LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 330, height: 330)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: viewModel.progress)
            }
            
            // Content
            VStack(spacing: 20) {
                // Time Display
                Text(viewModel.timeString)
                    .font(.system(size: 60, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .shadow(color: .orange.opacity(0.3), radius: 10)
                    .onTapGesture {
                        // Quick add minute if tapped?
                    }

                // Controls
                HStack(spacing: 30) {
                    
                    // Time Adjustment (Only when not running)
                    if !viewModel.isRunning {
                        Button(action: { viewModel.adjustTime(by: -300) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                                .background(Circle().fill(.white).padding(2))
                        }
                        .disabled(viewModel.totalTime <= 300)
                        
                        Button(action: { viewModel.adjustTime(by: 300) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                                .background(Circle().fill(.white).padding(2))
                        }
                    } else {
                        // Reset Button
                         Button(action: { viewModel.reset() }) {
                             Image(systemName: "arrow.counterclockwise")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    Circle()
                                        .fill(.gray.opacity(0.5))
                                )
                        }
                    }
                    
                    // Start/Stop
                    Button(action: { viewModel.toggleTimer() }) {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 25))
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                     .fill(Color.orange)
                                     .shadow(color: .orange.opacity(0.5), radius: 10)
                            )
                    }
                }
            }
        }
        .frame(width: 350, height: 350)
    }
}

// MARK: - Animated Background
struct AnimatedBlobView: View {
    var phase: Double
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let angle = Angle.degrees(now * 30) // Rotation speed
                let x = cos(angle.radians) * 50
                let y = sin(angle.radians) * 50
                
                context.fill(
                    Path(ellipseIn: CGRect(x: size.width/2 + x - 100, y: size.height/2 + y - 100, width: 200, height: 200)),
                    with: .color(.cyan.opacity(0.5))
                )
                
                context.fill(
                    Path(ellipseIn: CGRect(x: size.width/2 - x - 80, y: size.height/2 - y - 80, width: 160, height: 160)),
                    with: .color(.purple.opacity(0.5))
                )
            }
            .blur(radius: 50)
        }
    }
}


// MARK: - ViewModel
class TimerViewModel: ObservableObject {
    @Published var totalTime: TimeInterval = 30 * 60 // 30 minutes
    @Published var timeRemaining: TimeInterval = 30 * 60
    @Published var isRunning = false
    
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
    var progress: Double {
        return timeRemaining / totalTime
    }
    
    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func toggleTimer() {
        if isRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.stopTimer()
                self.playCongratulationSong()
            }
        }
    }
    
    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        stopTimer()
        timeRemaining = totalTime
    }
    
    func adjustTime(by seconds: TimeInterval) {
        let newTime = totalTime + seconds
        if newTime > 0 {
            totalTime = newTime
            timeRemaining = newTime
        }
    }
    
    func playCongratulationSong() {
        // Looking for a file named "congrats.mp3" in bundle, or fallback
        guard let url = Bundle.main.url(forResource: "congrats", withExtension: "mp3") else {
            print("Audio file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Could not play audio: \(error)")
        }
    }
}

#Preview {
    TimerOverlayView()
}
