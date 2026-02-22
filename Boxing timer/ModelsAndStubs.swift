import Foundation
import SwiftUI
import CoreData
import Combine
import AVFoundation
import UIKit

enum TimerPhase {
    case warmup
    case round
    case rest
    case cooldown
    case finished
}

enum TimerStatus {
    case idle
    case running
    case paused
}

struct FightPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var warmupSeconds: Int
    var rounds: Int
    var roundSeconds: Int
    var restSeconds: Int
    var isCustom: Bool
    
    init(id: UUID = UUID(), name: String, warmupSeconds: Int, rounds: Int, roundSeconds: Int, restSeconds: Int, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.warmupSeconds = warmupSeconds
        self.rounds = rounds
        self.roundSeconds = roundSeconds
        self.restSeconds = restSeconds
        self.isCustom = isCustom
    }
    
    static let defaultPresets: [FightPreset] = [
        FightPreset(name: "🥊 Boxen", warmupSeconds: 5, rounds: 12, roundSeconds: 180, restSeconds: 60),
        FightPreset(name: "🥋 MMA", warmupSeconds: 5, rounds: 3, roundSeconds: 300, restSeconds: 60),
        FightPreset(name: "🦵 K1", warmupSeconds: 5, rounds: 3, roundSeconds: 180, restSeconds: 60),
        FightPreset(name: "🇹🇭 Muay Thai", warmupSeconds: 5, rounds: 5, roundSeconds: 180, restSeconds: 120),
        FightPreset(name: "🤼 BJJ", warmupSeconds: 10, rounds: 1, roundSeconds: 300, restSeconds: 0),
        FightPreset(name: "🥋 Judo", warmupSeconds: 10, rounds: 1, roundSeconds: 240, restSeconds: 0),
        FightPreset(name: "🤼 Ringen", warmupSeconds: 10, rounds: 3, roundSeconds: 120, restSeconds: 30),
        FightPreset(name: "🥋 Taekwondo", warmupSeconds: 5, rounds: 3, roundSeconds: 120, restSeconds: 60)
    ]
}

enum IntervalDevice: String, CaseIterable, Codable {
    case running = "🏃 Draußen laufen"
    case treadmill = "🏋️ Laufband"
    case airBike = "🚴 AirBike"
    case bagWork = "🥊 Sandsack"
}

enum IntervalLevel: String, CaseIterable, Codable {
    case beginner = "Anfänger"
    case intermediate = "Fortgeschritten"
    case advanced = "Profi"
}

struct IntervalWorkout: Identifiable, Codable {
    let id: UUID
    let device: IntervalDevice
    let level: IntervalLevel
    var warmupSeconds: Int
    var intervals: Int
    var workSeconds: Int
    var restSeconds: Int
    var cooldownSeconds: Int
    
    init(id: UUID = UUID(), device: IntervalDevice, level: IntervalLevel, warmupSeconds: Int, intervals: Int, workSeconds: Int, restSeconds: Int, cooldownSeconds: Int) {
        self.id = id
        self.device = device
        self.level = level
        self.warmupSeconds = warmupSeconds
        self.intervals = intervals
        self.workSeconds = workSeconds
        self.restSeconds = restSeconds
        self.cooldownSeconds = cooldownSeconds
    }
    
    static func workout(for device: IntervalDevice, level: IntervalLevel) -> IntervalWorkout {
        switch (device, level) {
        // Running
        case (.running, .beginner):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 300, intervals: 8, workSeconds: 30, restSeconds: 60, cooldownSeconds: 180)
        case (.running, .intermediate):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 300, intervals: 10, workSeconds: 45, restSeconds: 60, cooldownSeconds: 180)
        case (.running, .advanced):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 360, intervals: 12, workSeconds: 60, restSeconds: 60, cooldownSeconds: 240)
            
        // Treadmill
        case (.treadmill, .beginner):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 300, intervals: 8, workSeconds: 30, restSeconds: 60, cooldownSeconds: 180)
        case (.treadmill, .intermediate):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 300, intervals: 10, workSeconds: 45, restSeconds: 60, cooldownSeconds: 180)
        case (.treadmill, .advanced):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 360, intervals: 15, workSeconds: 60, restSeconds: 60, cooldownSeconds: 240)
            
        // AirBike
        case (.airBike, .beginner):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 180, intervals: 6, workSeconds: 20, restSeconds: 60, cooldownSeconds: 120)
        case (.airBike, .intermediate):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 240, intervals: 10, workSeconds: 30, restSeconds: 60, cooldownSeconds: 180)
        case (.airBike, .advanced):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 300, intervals: 15, workSeconds: 40, restSeconds: 50, cooldownSeconds: 240)
            
        // Bag Work
        case (.bagWork, .beginner):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 180, intervals: 6, workSeconds: 30, restSeconds: 60, cooldownSeconds: 120)
        case (.bagWork, .intermediate):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 240, intervals: 10, workSeconds: 45, restSeconds: 50, cooldownSeconds: 180)
        case (.bagWork, .advanced):
            return IntervalWorkout(device: device, level: level, warmupSeconds: 300, intervals: 15, workSeconds: 90, restSeconds: 40, cooldownSeconds: 240)
        }
    }
    
    var displayName: String {
        "\(device.rawValue) - \(level.rawValue)"
    }
}

enum WorkoutMode: String, Codable {
    case fightTimer = "Fight Timer"
    case intervals = "Intervals"
}

class SoundManager {
    // "shared" = Singleton: es gibt nur eine Instanz in der ganzen App
    static let shared = SoundManager()

    enum SoundType {
        case roundStart
        case roundEnd
        case workoutEnd
        case roundWarning  // 10 Sekunden vor Rundenende
    }

    // Haupt-Player für Glocke (roundStart, roundEnd, workoutEnd)
    private var player: AVAudioPlayer?
    // Zweiter Player für Warning-Sound – läuft unabhängig vom Haupt-Player
    private var warningPlayer: AVAudioPlayer?

    func playHaptic(type: SoundType, vibrationEnabled: Bool) {
        guard vibrationEnabled else { return }

        switch type {
        case .roundStart:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()

        case .roundEnd:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)

        case .workoutEnd:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

        case .roundWarning:
            // Leichtes Tippen als kurze Vorwarnung
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }

    func playSound(type: SoundType, soundEnabled: Bool) {
        // Wenn Sound ausgeschaltet ist, direkt abbrechen
        guard soundEnabled else { return }

        // Bundle.main = die App selbst (alle eingebundenen Dateien)
        // wir suchen "boxClock.mp3" darin
        guard let url = Bundle.main.url(forResource: "boxClock", withExtension: "mp3") else {
            print("Sound-Datei nicht gefunden")
            return
        }

        // Warning-Sound läuft auf separatem Player
        if type == .roundWarning {
            guard let warnUrl = Bundle.main.url(forResource: "knock-sound", withExtension: "mp3") else {
                print("knock-sound.mp3 nicht gefunden")
                return
            }
            do {
                warningPlayer = try AVAudioPlayer(contentsOf: warnUrl)
                warningPlayer?.volume = 1.0
                warningPlayer?.play()
            } catch {
                print("Warning-Sound Fehler: \(error)")
            }
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)

            switch type {
            case .roundStart:
                player?.volume = 1.0
            case .roundEnd:
                player?.volume = 0.8
            case .workoutEnd:
                player?.volume = 1.0
            case .roundWarning:
                break  // wird oben bereits behandelt
            }

            player?.play()
        } catch {
            print("Sound konnte nicht abgespielt werden: \(error)")
        }
    }
}

class ProfileManager: ObservableObject {
    @Published var customProfiles: [FightPreset] = []
    
    private let userDefaultsKey = "customProfiles"
    
    init() {
        loadProfiles()
    }
    
    func save(_ preset: FightPreset) {
        var newProfile = preset
        newProfile.isCustom = true
        customProfiles.append(newProfile)
        saveProfiles()
    }
    
    private func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(customProfiles) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([FightPreset].self, from: data) {
            customProfiles = decoded
        }
    }
}

