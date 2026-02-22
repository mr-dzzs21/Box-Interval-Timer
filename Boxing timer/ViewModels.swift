//
//  ViewModels.swift
//  Boxing timer
//
//  Created by Diyar on 27.01.26.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import UIKit
import ActivityKit


// TEIL 2: ViewModels und Views
// Diesen Code nach Teil 1 einfügen

// MARK: - ViewModels
@MainActor
class FightTimerViewModel: ObservableObject {
    @Published var currentPreset: FightPreset
    @Published var phase: TimerPhase = .warmup
    @Published var status: TimerStatus = .idle
    @Published var timeRemaining: Int = 0
    @Published var currentRound: Int = 0

    private var timer: Timer?
    private let soundManager = SoundManager.shared
    private var startTime: Date?
    private var totalElapsedSeconds: Int = 0

    // Live Activity - gespeichert als Any? weil Activity<T> generisch ist
    private var liveActivity: Activity<BoxingTimerAttributes>?

    var settings: UserSettings?
    // Sprache wird von der View gesetzt, damit phaseText übersetzt wird
    @Published var language: AppLanguage = .german

    init(preset: FightPreset = FightPreset.defaultPresets[0]) {
        self.currentPreset = preset
        self.timeRemaining = preset.warmupSeconds
    }

    func start() {
        if status == .idle {
            reset()
            startTime = Date()
        }
        status = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        startLiveActivity()
    }

    func pause() {
        status = .paused
        timer?.invalidate()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        updateLiveActivity(isRunning: false)
    }

    func resume() {
        status = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        updateLiveActivity(isRunning: true)
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        status = .idle
        phase = .warmup
        currentRound = 0
        timeRemaining = currentPreset.warmupSeconds
        totalElapsedSeconds = 0
        startTime = nil
        UIApplication.shared.isIdleTimerDisabled = false
        endLiveActivity()
    }

    // MARK: - Live Activity
    private var phaseColorName: String {
        switch phase {
        case .warmup, .cooldown: return "gray"
        case .round:             return "green"
        case .rest:              return "red"
        case .finished:          return "blue"
        }
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = BoxingTimerAttributes(sportName: currentPreset.name)
        let endDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
        let state = BoxingTimerAttributes.ContentState(
            phase: phaseText,
            phaseEndDate: endDate,
            displayTime: timeString,
            isRunning: true,
            colorName: phaseColorName,
            currentRound: currentRound,
            totalRounds: currentPreset.rounds
        )
        let content = ActivityContent(state: state, staleDate: nil)
        liveActivity = try? Activity.request(attributes: attributes, content: content)
    }

    private func updateLiveActivity(isRunning: Bool) {
        guard let activity = liveActivity else { return }
        let endDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
        let state = BoxingTimerAttributes.ContentState(
            phase: phaseText,
            phaseEndDate: endDate,
            displayTime: timeString,
            isRunning: isRunning,
            colorName: phaseColorName,
            currentRound: currentRound,
            totalRounds: currentPreset.rounds
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        Task { await activity.end(dismissalPolicy: .immediate) }
        liveActivity = nil
    }

    func skip() {
        advancePhase()
    }

    func updatePreset(_ preset: FightPreset) {
        currentPreset = preset
        reset()
    }
    
    func saveWorkoutToHistory(context: NSManagedObjectContext) {
        guard let startTime = startTime else { return }
        let workout = WorkoutHistoryEntity(context: context)
        workout.id = UUID()
        workout.date = startTime
        workout.mode = WorkoutMode.fightTimer.rawValue
        workout.sportName = currentPreset.name
        workout.totalDuration = Int32(totalElapsedSeconds)
        workout.rounds = Int16(currentPreset.rounds)
        workout.roundSeconds = Int16(currentPreset.roundSeconds)
        workout.restSeconds = Int16(currentPreset.restSeconds)
        workout.warmupSeconds = Int16(currentPreset.warmupSeconds)
        try? context.save()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func tick() {
        totalElapsedSeconds += 1
        guard timeRemaining > 0 else {
            advancePhase()
            return
        }
        timeRemaining -= 1

        // 10-Sekunden-Warnung vor Rundenende (nur wenn aktiviert)
        if phase == .round && timeRemaining == 10 && (settings?.warningEnabled ?? true) {
            let soundEnabled = settings?.soundEnabled ?? true
            let vibrationEnabled = settings?.vibrationEnabled ?? true
            soundManager.playSound(type: .roundWarning, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundWarning, vibrationEnabled: vibrationEnabled)
        }
    }

    private func advancePhase() {
        let soundEnabled = settings?.soundEnabled ?? true
        let vibrationEnabled = settings?.vibrationEnabled ?? true

        switch phase {
        case .warmup:
            phase = .round
            currentRound = 1
            timeRemaining = currentPreset.roundSeconds
            soundManager.playSound(type: .roundStart, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundStart, vibrationEnabled: vibrationEnabled)
            updateLiveActivity(isRunning: true)
        case .round:
            if currentRound < currentPreset.rounds {
                phase = .rest
                timeRemaining = currentPreset.restSeconds
                soundManager.playSound(type: .roundEnd, soundEnabled: soundEnabled)
                soundManager.playHaptic(type: .roundEnd, vibrationEnabled: vibrationEnabled)
                updateLiveActivity(isRunning: true)
            } else {
                phase = .finished
                timeRemaining = 0
                soundManager.playSound(type: .workoutEnd, soundEnabled: soundEnabled)
                soundManager.playHaptic(type: .workoutEnd, vibrationEnabled: vibrationEnabled)
                endLiveActivity()
                pause()
            }
        case .rest:
            currentRound += 1
            phase = .round
            timeRemaining = currentPreset.roundSeconds
            soundManager.playSound(type: .roundStart, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundStart, vibrationEnabled: vibrationEnabled)
            updateLiveActivity(isRunning: true)
        case .cooldown, .finished:
            endLiveActivity()
            pause()
        }
    }

    var backgroundColor: Color {
        switch phase {
        case .warmup, .cooldown: return .gray.opacity(0.3)
        case .round: return .green.opacity(1.0)
        case .rest: return .red.opacity(1.0)
        case .finished: return .blue.opacity(0.3)
        }
    }

    var phaseText: String {
        let t = Translations.all[language] ?? Translations.all[.german]!
        switch phase {
        case .warmup:  return t.phaseWarmUp
        case .round:   return "\(t.phaseRound) \(currentRound)/\(currentPreset.rounds)"
        case .rest:    return t.phaseRest
        case .cooldown: return t.phaseCoolDown
        case .finished: return t.phaseFinished
        }
    }
    
    var timeString: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }
    
    var progress: Double {
        let total: Int
        switch phase {
        case .warmup: total = currentPreset.warmupSeconds
        case .round: total = currentPreset.roundSeconds
        case .rest: total = currentPreset.restSeconds
        case .cooldown: total = 0
        case .finished: return 1.0
        }
        guard total > 0 else { return 1.0 }
        return 1.0 - Double(timeRemaining) / Double(total)
    }
}

@MainActor
class IntervalTimerViewModel: ObservableObject {
    @Published var workout: IntervalWorkout
    @Published var phase: TimerPhase = .warmup
    @Published var status: TimerStatus = .idle
    @Published var timeRemaining: Int = 0
    @Published var currentInterval: Int = 0

    private var timer: Timer?
    private let soundManager = SoundManager.shared
    private var startTime: Date?
    private var totalElapsedSeconds: Int = 0

    private var liveActivity: Activity<BoxingTimerAttributes>?

    var settings: UserSettings?
    @Published var language: AppLanguage = .german

    init(workout: IntervalWorkout) {
        self.workout = workout
        self.timeRemaining = workout.warmupSeconds
    }

    func start() {
        if status == .idle {
            reset()
            startTime = Date()
        }
        status = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        startLiveActivity()
    }

    func pause() {
        status = .paused
        timer?.invalidate()
        timer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        updateLiveActivity(isRunning: false)
    }

    func resume() {
        status = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        updateLiveActivity(isRunning: true)
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        status = .idle
        phase = .warmup
        currentInterval = 0
        timeRemaining = workout.warmupSeconds
        totalElapsedSeconds = 0
        startTime = nil
        UIApplication.shared.isIdleTimerDisabled = false
        endLiveActivity()
    }

    func skip() {
        advancePhase()
    }

    func updateWorkout(_ w: IntervalWorkout) {
        workout = w
        reset()
    }

    // MARK: - Live Activity
    private var phaseColorName: String {
        switch phase {
        case .warmup, .cooldown: return "gray"
        case .round:             return "green"
        case .rest:              return "red"
        case .finished:          return "blue"
        }
    }

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = BoxingTimerAttributes(sportName: workout.displayName)
        let endDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
        let state = BoxingTimerAttributes.ContentState(
            phase: phaseText,
            phaseEndDate: endDate,
            displayTime: timeString,
            isRunning: true,
            colorName: phaseColorName,
            currentRound: currentInterval,
            totalRounds: workout.intervals
        )
        let content = ActivityContent(state: state, staleDate: nil)
        liveActivity = try? Activity.request(attributes: attributes, content: content)
    }

    private func updateLiveActivity(isRunning: Bool) {
        guard let activity = liveActivity else { return }
        let endDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
        let state = BoxingTimerAttributes.ContentState(
            phase: phaseText,
            phaseEndDate: endDate,
            displayTime: timeString,
            isRunning: isRunning,
            colorName: phaseColorName,
            currentRound: currentInterval,
            totalRounds: workout.intervals
        )
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        Task { await activity.end(dismissalPolicy: .immediate) }
        liveActivity = nil
    }

    func saveWorkoutToHistory(context: NSManagedObjectContext) {
        guard let startTime = startTime else { return }
        let w = WorkoutHistoryEntity(context: context)
        w.id = UUID()
        w.date = startTime
        w.mode = WorkoutMode.intervals.rawValue
        w.sportName = workout.displayName
        w.totalDuration = Int32(totalElapsedSeconds)
        w.intervals = Int16(workout.intervals)
        w.workSeconds = Int16(workout.workSeconds)
        w.restSeconds = Int16(workout.restSeconds)
        w.warmupSeconds = Int16(workout.warmupSeconds)
        try? context.save()
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func tick() {
        totalElapsedSeconds += 1
        guard timeRemaining > 0 else {
            advancePhase()
            return
        }
        timeRemaining -= 1

        // 10-Sekunden-Warnung vor Intervallende (nur wenn aktiviert)
        if phase == .round && timeRemaining == 10 && (settings?.warningEnabled ?? true) {
            let soundEnabled = settings?.soundEnabled ?? true
            let vibrationEnabled = settings?.vibrationEnabled ?? true
            soundManager.playSound(type: .roundWarning, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundWarning, vibrationEnabled: vibrationEnabled)
        }
    }

    private func advancePhase() {
        let soundEnabled = settings?.soundEnabled ?? true
        let vibrationEnabled = settings?.vibrationEnabled ?? true

        switch phase {
        case .warmup:
            phase = .round
            currentInterval = 1
            timeRemaining = workout.workSeconds
            soundManager.playSound(type: .roundStart, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundStart, vibrationEnabled: vibrationEnabled)
            updateLiveActivity(isRunning: true)
        case .round:
            if currentInterval < workout.intervals {
                phase = .rest
                timeRemaining = workout.restSeconds
                soundManager.playSound(type: .roundEnd, soundEnabled: soundEnabled)
                soundManager.playHaptic(type: .roundEnd, vibrationEnabled: vibrationEnabled)
                updateLiveActivity(isRunning: true)
            } else {
                phase = .cooldown
                timeRemaining = workout.cooldownSeconds
                soundManager.playSound(type: .roundEnd, soundEnabled: soundEnabled)
                soundManager.playHaptic(type: .roundEnd, vibrationEnabled: vibrationEnabled)
                updateLiveActivity(isRunning: true)
            }
        case .rest:
            currentInterval += 1
            phase = .round
            timeRemaining = workout.workSeconds
            soundManager.playSound(type: .roundStart, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundStart, vibrationEnabled: vibrationEnabled)
            updateLiveActivity(isRunning: true)
        case .cooldown:
            phase = .finished
            timeRemaining = 0
            soundManager.playSound(type: .workoutEnd, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .workoutEnd, vibrationEnabled: vibrationEnabled)
            endLiveActivity()
            pause()
        case .finished:
            endLiveActivity()
            pause()
        }
    }

    var backgroundColor: Color {
        switch phase {
        case .warmup, .cooldown: return .gray.opacity(0.3)
        case .round: return .green.opacity(1.0)
        case .rest: return .red.opacity(1.0)
        case .finished: return .blue.opacity(0.3)
        }
    }

    var phaseText: String {
        let t = Translations.all[language] ?? Translations.all[.german]!
        switch phase {
        case .warmup:  return t.phaseWarmUp
        case .round:   return "\(t.phaseWork) \(currentInterval)/\(workout.intervals)"
        case .rest:    return t.phaseRest
        case .cooldown: return t.phaseCoolDown
        case .finished: return t.phaseFinished
        }
    }
    
    var timeString: String {
        String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60)
    }
    
    var progress: Double {
        let total: Int
        switch phase {
        case .warmup: total = workout.warmupSeconds
        case .round: total = workout.workSeconds
        case .rest: total = workout.restSeconds
        case .cooldown: total = workout.cooldownSeconds
        case .finished: return 1.0
        }
        guard total > 0 else { return 1.0 }
        return 1.0 - Double(timeRemaining) / Double(total)
    }
}

@MainActor
class HistoryViewModel: ObservableObject {
    @Published var workouts: [WorkoutHistoryEntity] = []
    
    func fetch(context: NSManagedObjectContext) {
        let request: NSFetchRequest<WorkoutHistoryEntity> = WorkoutHistoryEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutHistoryEntity.date, ascending: false)]
        do {
            workouts = try context.fetch(request)
        } catch {
            print("Failed to fetch workouts: \(error)")
            workouts = []
        }
    }
    
    func delete(_ workout: WorkoutHistoryEntity, context: NSManagedObjectContext) {
        context.delete(workout)
        try? context.save()
        fetch(context: context)
    }
    
    func deleteAll(context: NSManagedObjectContext) {
        let request: NSFetchRequest<NSFetchRequestResult> = WorkoutHistoryEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        do {
            try context.execute(deleteRequest)
            try context.save()
            fetch(context: context)
        } catch {
            print("Failed to delete all workouts: \(error)")
        }
    }
}

@MainActor
class StatsViewModel: ObservableObject {
    @Published var totalWorkouts = 0
    @Published var totalDuration = 0
    @Published var mostPopularSport = "—"
    @Published var last7Days = 0
    @Published var currentStreak = 0
    
    func calculate(context: NSManagedObjectContext) {
        let request: NSFetchRequest<WorkoutHistoryEntity> = WorkoutHistoryEntity.fetchRequest()
        do {
            let workouts = try context.fetch(request)
            
            totalWorkouts = workouts.count
            totalDuration = workouts.reduce(0) { $0 + Int($1.totalDuration) }
            
            let sportCounts = Dictionary(grouping: workouts) { $0.sportName ?? "Unknown" }.mapValues { $0.count }
            mostPopularSport = sportCounts.max(by: { $0.value < $1.value })?.key ?? "—"
            
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            last7Days = workouts.filter { ($0.date ?? Date()) >= sevenDaysAgo }.count
            
            currentStreak = calculateStreak(workouts)
        } catch {
            print("Failed to calculate stats: \(error)")
        }
    }
    
    private func calculateStreak(_ workouts: [WorkoutHistoryEntity]) -> Int {
        guard !workouts.isEmpty else { return 0 }
        let calendar = Calendar.current
        let sorted = workouts.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        for w in sorted {
            guard let wDate = w.date else { continue }
            let wDay = calendar.startOfDay(for: wDate)
            let diff = calendar.dateComponents([.day], from: wDay, to: currentDate).day ?? 0
            if diff == 0 || diff == 1 {
                if diff == 1 {
                    streak += 1
                    currentDate = wDay
                }
            } else {
                break
            }
        }
        return streak
    }
}


// MARK: - Fight Timer View
struct FightTimerView: View {
    @StateObject private var vm = FightTimerViewModel()
    @StateObject private var pm = ProfileManager()
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var lang: LanguageManager
    @State private var showPicker = false
    @State private var showEditor = false
    @State private var showSaved = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                vm.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Button { showPicker = true } label: {
                        HStack {
                            Text(vm.currentPreset.name).font(.headline)
                            Image(systemName: "chevron.down")
                        }
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                    }
                    .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(vm.phaseText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                    
                    ZStack {
                        Circle().stroke(Color.gray.opacity(0.3), lineWidth: 15).frame(width: 280, height: 280)
                        Circle().trim(from: 0, to: vm.progress).stroke(Color.primary, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                            .frame(width: 280, height: 280).rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: vm.progress)
                        Text(vm.timeString).font(.system(size: 90, weight: .bold, design: .rounded)).foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 30) {
                        Button { vm.reset() } label: {
                            Image(systemName: "arrow.counterclockwise").font(.system(size: 28))
                                .frame(width: 70, height: 70).background(Color.black.opacity(0.2)).clipShape(Circle())
                        }
                        Button {
                            if vm.status == .running { vm.pause() }
                            else {
                                if vm.status == .idle { vm.start() } else { vm.resume() }
                            }
                        } label: {
                            Image(systemName: vm.status == .running ? "pause.fill" : "play.fill").font(.system(size: 36))
                                .frame(width: 90, height: 90).background(Color.primary).foregroundColor(vm.backgroundColor).clipShape(Circle())
                        }
                        Button { vm.skip() } label: {
                            Image(systemName: "forward.fill").font(.system(size: 28))
                                .frame(width: 70, height: 70).background(Color.black.opacity(0.2)).clipShape(Circle())
                        }
                    }
                    .foregroundColor(.primary)
                    
                    if vm.phase == .finished {
                        Button(lang.t.saveWorkout) {
                            vm.saveWorkoutToHistory(context: context)
                            showSaved = true
                        }
                        .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                        .background(Color.blue).cornerRadius(12).padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(lang.t.fightTimerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { vm.settings = settings; vm.language = lang.current }
            .onChange(of: lang.current) { _, new in vm.language = new }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showEditor = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showPicker) {
                PresetPickerView(vm: vm, pm: pm)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showEditor) {
                CustomProfileEditor(pm: pm)
            }
            .alert(lang.t.saved, isPresented: $showSaved) {
                Button(lang.t.ok, role: .cancel) {}
            }
        }
    }
}

struct PresetPickerView: View {
    @ObservedObject var vm: FightTimerViewModel
    @ObservedObject var pm: ProfileManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lang: LanguageManager
    @State private var selected: FightPreset

    init(vm: FightTimerViewModel, pm: ProfileManager) {
        self.vm = vm
        self.pm = pm
        _selected = State(initialValue: vm.currentPreset)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(lang.t.standardPresets) {
                    ForEach(FightPreset.defaultPresets) { p in
                        Button { selected = p } label: {
                            HStack {
                                Text(lang.t.localizedPresetName(p.name)).foregroundColor(.primary)
                                Spacer()
                                if selected.id == p.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }

                Section(lang.t.customProfiles) {
                    ForEach(pm.customProfiles) { p in
                        Button { selected = p } label: {
                            HStack {
                                Text(p.name).foregroundColor(.primary)
                                Spacer()
                                if selected.id == p.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }

                Section(lang.t.customizations) {
                    Stepper("\(lang.t.warmUp): \(selected.warmupSeconds)s", value: $selected.warmupSeconds, in: 0...600, step: 5)
                    Stepper("\(lang.t.rounds): \(selected.rounds)", value: $selected.rounds, in: 1...20)
                    Stepper("\(lang.t.roundTime): \(selected.roundSeconds / 60) min", value: Binding(
                        get: { selected.roundSeconds / 60 },
                        set: { selected.roundSeconds = $0 * 60 }
                    ), in: 1...10)
                    Stepper("\(lang.t.rest): \(selected.restSeconds)s", value: $selected.restSeconds, in: 0...300, step: 5)
                }
            }
            .navigationTitle(lang.t.chooseTimer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.t.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t.done) {
                        vm.updatePreset(selected)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CustomProfileEditor: View {
    @ObservedObject var pm: ProfileManager
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lang: LanguageManager
    @State private var name = ""
    @State private var warmup = 5
    @State private var rounds = 3
    @State private var roundTime = 180
    @State private var rest = 60

    var body: some View {
        NavigationStack {
            Form {
                TextField(lang.t.profileNameHint, text: $name)
                Stepper("\(lang.t.warmUp): \(warmup)s", value: $warmup, in: 0...600, step: 5)
                Stepper("\(lang.t.rounds): \(rounds)", value: $rounds, in: 1...20)
                Stepper("\(lang.t.roundTime): \(roundTime / 60) min", value: Binding(
                    get: { roundTime / 60 },
                    set: { roundTime = $0 * 60 }
                ), in: 1...10)
                Stepper("\(lang.t.rest): \(rest)s", value: $rest, in: 0...300, step: 5)
            }
            .navigationTitle(lang.t.newProfile)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.t.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t.save) {
                        let profile = FightPreset(name: name.isEmpty ? "Custom" : name, warmupSeconds: warmup, rounds: rounds, roundSeconds: roundTime, restSeconds: rest, isCustom: true)
                        pm.save(profile)
                        dismiss()
                    }
                }
            }
        }
    }
}

// Fortsetzung folgt...

