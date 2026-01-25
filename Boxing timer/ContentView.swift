//
//  ContentView.swift
//  Boxing timer
//
//  Created by Diyar on 25.01.26.
//

import SwiftUI
import Combine
import AVFoundation

// Die verschiedenen Phasen des Timers
enum WorkoutState {
    case idle, prepare, round, rest, finished
}

struct ContentView: View {
    // Einstellungen
    @State private var currentRound = 1
    @State private var totalRounds = 12
    @State private var timeRemaining = 5 // Startet mit 5 Sek Vorbereitung
    @State private var currentState: WorkoutState = .idle
    @State private var isRunning = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Hintergrundfarbe basierend auf dem Status
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Status-Anzeige
                Text(statusText)
                    .font(.system(size: 30, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("Round \(currentRound) / \(totalRounds)")
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                // Großer Timer
                Text(timeString(time: timeRemaining))
                    .font(.system(size: 100, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                // Controls
                HStack(spacing: 40) {
                    Button(action: { isRunning.toggle() }) {
                        Image(systemName: isRunning ? "pause.circle.fill" : "play.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.white)
                    }
                    
                    Button(action: resetWorkout) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            updateTimer()
        }
    }
    
    // LOGIK: Was passiert jede Sekunde?
    func updateTimer() {
        guard isRunning else { return }
        
        if timeRemaining > 0 {
            timeRemaining -= 1
        } else {
            switchState()
        }
    }
    
    func switchState() {
        switch currentState {
        case .idle:
            currentState = .prepare
            timeRemaining = 5
        case .prepare:
            currentState = .round
            timeRemaining = 180 // 3 Minuten
            playBellSound()
        case .round:
            if currentRound < totalRounds {
                currentState = .rest
                timeRemaining = 60 // 1 Minute Pause
                playBellSound()
            } else {
                currentState = .finished
                isRunning = false
            }
        case .rest:
            currentRound += 1
            currentState = .round
            timeRemaining = 180
            playBellSound()
        case .finished:
            break
        }
    }
    
    // HILFSFUNKTIONEN
    var backgroundColor: Color {
        switch currentState {
        case .idle: return .black
        case .prepare: return .gray
        case .round: return .green
        case .rest: return .red
        case .finished: return .blue
        }
    }
    
    var statusText: String {
        switch currentState {
        case .idle: return "READY"
        case .prepare: return "Warm UP"
        case .round: return "FIGHT!"
        case .rest: return "PAUSE"
        case .finished: return "FERTIG!"
        }
    }
    
    func timeString(time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func resetWorkout() {
        isRunning = false
        currentState = .idle
        currentRound = 1
        timeRemaining = 5
    }
    
    func playBellSound() {
        // Hier kommt der Sound-Code rein (Erklärung siehe unten)
        AudioServicesPlaySystemSound(1005) // Temporärer System-Sound
    }
}




#Preview {
    ContentView()
}

