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
    @Published var hasSavedCurrentWorkout = false
    @Published var saveErrorMessage: String?

    private var engine: TimerSessionEngine
    private var timer: Timer?
    private let soundManager = SoundManager.shared
    private var workoutStartTime: Date?
    private var totalElapsedSeconds: Int = 0
    private var lastSnapshot: TimerSessionSnapshot?
    private var warnedSegmentIndex: Int?
    private var savedWorkoutObjectID: NSManagedObjectID?

    // Live Activity - gespeichert als Any? weil Activity<T> generisch ist
    private var liveActivity: Activity<BoxingTimerAttributes>?

    var settings: UserSettings?
    var historyContext: NSManagedObjectContext?
    var onWorkoutSaved: (() -> Void)?
    // Sprache wird von der View gesetzt, damit phaseText übersetzt wird
    @Published var language: AppLanguage = .german

    init(preset: FightPreset? = nil) {
        let resolved = preset ?? FightPreset.defaultPresets[0]
        self.currentPreset = resolved
        self.engine = TimerSessionEngine.fight(preset: resolved)
        let snapshot = engine.snapshot(at: Date())
        self.phase = snapshot.phase
        self.timeRemaining = snapshot.timeRemaining
        self.currentRound = snapshot.currentStep
        self.lastSnapshot = snapshot
    }

    func start() {
        let now = Date()
        if status == .paused && phase != .finished {
            resume()
            return
        }
        
        prepareNewSession(at: now)
        engine.start(at: now)
        status = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: false)
        // Bei Warm-up = 0 beginnt sofort Runde 1; das Start-Snapshot läuft ohne
        // Effekte, daher hier die Eröffnungsglocke + Ansage nachholen.
        if phase == .round {
            let soundEnabled = settings?.soundEnabled ?? true
            let vibrationEnabled = settings?.vibrationEnabled ?? true
            soundManager.playSound(type: .roundStart, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundStart, vibrationEnabled: vibrationEnabled)
            soundManager.speakRound(lastSnapshot?.currentStep ?? 1, soundEnabled: soundEnabled)
        }
        startLiveActivity()
    }

    func pause() {
        guard status == .running else { return }
        let now = Date()
        engine.pause(at: now)
        status = .paused
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: false)
        updateLiveActivity(isRunning: false)
    }

    func resume() {
        if phase == .finished {
            start()
            return
        }
        guard status == .paused else { return }
        let now = Date()
        engine.start(at: now)
        status = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: false)
        updateLiveActivity(isRunning: true)
    }

    func reset() {
        stopTimer()
        status = .idle
        UIApplication.shared.isIdleTimerDisabled = false
        engine = TimerSessionEngine.fight(preset: currentPreset)
        engine.reset()
        workoutStartTime = nil
        totalElapsedSeconds = 0
        warnedSegmentIndex = nil
        savedWorkoutObjectID = nil
        hasSavedCurrentWorkout = false
        saveErrorMessage = nil
        applySnapshot(engine.snapshot(at: Date()), now: Date(), allowEffects: false)
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
        if liveActivity != nil {
            updateLiveActivity(isRunning: status == .running)
            return
        }
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
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        liveActivity = nil
    }

    func skip() {
        guard status != .idle else { return }
        let now = Date()
        let previous = lastSnapshot ?? engine.snapshot(at: now)
        engine.skip(at: now)
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: true, previousSnapshot: previous)
    }

    func refreshFromClock() {
        guard status == .running else { return }
        let now = Date()
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: true)
    }

    func updatePreset(_ preset: FightPreset) {
        currentPreset = preset
        reset()
    }
    
    @discardableResult
    func saveWorkoutToHistory(context: NSManagedObjectContext, allowUpdate: Bool = false) -> Bool {
        guard let startTime = workoutStartTime, totalElapsedSeconds > 0 else { return false }
        if hasSavedCurrentWorkout && !allowUpdate { return false }

        let isFirstSave = savedWorkoutObjectID == nil
        let workout: WorkoutHistoryEntity
        if let objectID = savedWorkoutObjectID,
           let existing = try? context.existingObject(with: objectID) as? WorkoutHistoryEntity {
            workout = existing
        } else {
            workout = WorkoutHistoryEntity(context: context)
            workout.id = UUID()
            workout.date = startTime
        }
        workout.mode = WorkoutMode.fightTimer.rawValue
        workout.sportName = currentPreset.name
        workout.totalDuration = Int32(totalElapsedSeconds)
        workout.rounds = Int16(currentPreset.rounds)
        workout.roundSeconds = Int16(currentPreset.roundSeconds)
        workout.restSeconds = Int16(currentPreset.restSeconds)
        workout.warmupSeconds = Int16(currentPreset.warmupSeconds)
        do {
            try context.save()
            savedWorkoutObjectID = workout.objectID
            hasSavedCurrentWorkout = true
            saveErrorMessage = nil
            if isFirstSave { onWorkoutSaved?() }
            return true
        } catch {
            context.rollback()
            saveErrorMessage = error.localizedDescription
#if DEBUG
            print("Workout konnte nicht gespeichert werden: \(error)")
#endif
            return false
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        let now = Date()
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: true)
    }

    private func prepareNewSession(at date: Date) {
        stopTimer()
        endLiveActivity()
        engine = TimerSessionEngine.fight(preset: currentPreset)
        engine.reset()
        workoutStartTime = date
        totalElapsedSeconds = 0
        warnedSegmentIndex = nil
        savedWorkoutObjectID = nil
        hasSavedCurrentWorkout = false
        saveErrorMessage = nil
        lastSnapshot = engine.snapshot(at: date)
    }

    private func applySnapshot(_ snapshot: TimerSessionSnapshot, now: Date, allowEffects: Bool, previousSnapshot: TimerSessionSnapshot? = nil) {
        let previous = previousSnapshot ?? lastSnapshot
        let segmentChanged = previous?.segmentIndex != snapshot.segmentIndex

        phase = snapshot.phase
        currentRound = snapshot.currentStep
        timeRemaining = snapshot.timeRemaining
        totalElapsedSeconds = snapshot.elapsedSeconds

        if allowEffects {
            playTransitionEffects(from: previous, to: snapshot)
            playWarningIfNeeded(from: previous, to: snapshot)
        }

        lastSnapshot = snapshot

        if snapshot.isFinished {
            completeWorkout(now: now)
        } else if segmentChanged && liveActivity != nil {
            updateLiveActivity(isRunning: status == .running)
        }
    }

    private func playTransitionEffects(from previous: TimerSessionSnapshot?, to snapshot: TimerSessionSnapshot) {
        guard let previous, previous.segmentIndex != snapshot.segmentIndex else { return }
        let soundEnabled = settings?.soundEnabled ?? true
        let vibrationEnabled = settings?.vibrationEnabled ?? true

        switch snapshot.phase {
        case .round:
            soundManager.playSound(type: .roundStart, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundStart, vibrationEnabled: vibrationEnabled)
            // Sprachansage für die neue Runde
            soundManager.speakRound(snapshot.currentStep, soundEnabled: soundEnabled)
        case .rest, .cooldown:
            soundManager.playSound(type: .roundEnd, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundEnd, vibrationEnabled: vibrationEnabled)
        case .finished:
            soundManager.playSound(type: .workoutEnd, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .workoutEnd, vibrationEnabled: vibrationEnabled)
        case .warmup:
            break
        }
    }

    private func playWarningIfNeeded(from previous: TimerSessionSnapshot?, to snapshot: TimerSessionSnapshot) {
        guard snapshot.phase == .round, settings?.warningEnabled ?? true else { return }
        guard warnedSegmentIndex != snapshot.segmentIndex else { return }
        guard let previous, previous.segmentIndex == snapshot.segmentIndex else { return }
        guard previous.timeRemaining > 10, snapshot.timeRemaining <= 10 else { return }

        // Diese Warnsegment-Grenze gilt jetzt als behandelt – auch wenn wir gleich
        // nicht abspielen, damit sie in einem späteren Tick nicht erneut auslöst.
        warnedSegmentIndex = snapshot.segmentIndex

        // Nur abspielen, wenn die 10-Sekunden-Grenze in Echtzeit überschritten wurde
        // (~1s pro Tick). Nach einem großen Sprung – App war im Hintergrund oder es
        // wurde geskippt – käme die Warnung viel zu spät und wird unterdrückt.
        guard previous.timeRemaining - snapshot.timeRemaining <= 2 else { return }

        let soundEnabled = settings?.soundEnabled ?? true
        let vibrationEnabled = settings?.vibrationEnabled ?? true
        soundManager.playSound(type: .roundWarning, soundEnabled: soundEnabled)
        soundManager.playHaptic(type: .roundWarning, vibrationEnabled: vibrationEnabled)
    }

    private func completeWorkout(now: Date) {
        guard status == .running else { return }
        engine.pause(at: now)
        status = .paused
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        endLiveActivity()
        if let historyContext {
            saveWorkoutToHistory(context: historyContext, allowUpdate: true)
        }
    }

    var backgroundColor: Color {
        // Farbe nach Phase: Runde = grün, Pause/Rest = rot. Bleibt beim Stoppen
        // erhalten (Stopp in der Runde = grün, Stopp in der Pause = rot).
        switch phase {
        case .warmup, .cooldown: return .gray.opacity(0.3)
        case .round:             return .green.opacity(1.0)
        case .rest:              return .red.opacity(1.0)
        case .finished:          return .blue.opacity(0.3)
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
        lastSnapshot?.progress ?? 0
    }
}

@MainActor
class IntervalTimerViewModel: ObservableObject {
    @Published var workout: IntervalWorkout
    @Published var phase: TimerPhase = .warmup
    @Published var status: TimerStatus = .idle
    @Published var timeRemaining: Int = 0
    @Published var currentInterval: Int = 0
    @Published var hasSavedCurrentWorkout = false
    @Published var saveErrorMessage: String?

    private var engine: TimerSessionEngine
    private var timer: Timer?
    private let soundManager = SoundManager.shared
    private var workoutStartTime: Date?
    private var totalElapsedSeconds: Int = 0
    private var lastSnapshot: TimerSessionSnapshot?
    private var warnedSegmentIndex: Int?
    private var savedWorkoutObjectID: NSManagedObjectID?

    private var liveActivity: Activity<BoxingTimerAttributes>?

    var settings: UserSettings?
    var historyContext: NSManagedObjectContext?
    var onWorkoutSaved: (() -> Void)?
    @Published var language: AppLanguage = .german

    init(workout: IntervalWorkout) {
        self.workout = workout
        self.engine = TimerSessionEngine.interval(workout: workout)
        let snapshot = engine.snapshot(at: Date())
        self.phase = snapshot.phase
        self.timeRemaining = snapshot.timeRemaining
        self.currentInterval = snapshot.currentStep
        self.lastSnapshot = snapshot
    }

    func start() {
        let now = Date()
        if status == .paused && phase != .finished {
            resume()
            return
        }
        
        prepareNewSession(at: now)
        engine.start(at: now)
        status = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: false)
        // Bei Warm-up = 0 beginnt sofort Runde 1; das Start-Snapshot läuft ohne
        // Effekte, daher hier die Eröffnungsglocke + Ansage nachholen.
        if phase == .round {
            let soundEnabled = settings?.soundEnabled ?? true
            let vibrationEnabled = settings?.vibrationEnabled ?? true
            soundManager.playSound(type: .roundStart, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundStart, vibrationEnabled: vibrationEnabled)
            soundManager.speakRound(lastSnapshot?.currentStep ?? 1, soundEnabled: soundEnabled)
        }
        startLiveActivity()
    }

    func pause() {
        guard status == .running else { return }
        let now = Date()
        engine.pause(at: now)
        status = .paused
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: false)
        updateLiveActivity(isRunning: false)
    }

    func resume() {
        if phase == .finished {
            start()
            return
        }
        guard status == .paused else { return }
        let now = Date()
        engine.start(at: now)
        status = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startTimer()
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: false)
        updateLiveActivity(isRunning: true)
    }

    func reset() {
        stopTimer()
        status = .idle
        UIApplication.shared.isIdleTimerDisabled = false
        engine = TimerSessionEngine.interval(workout: workout)
        engine.reset()
        workoutStartTime = nil
        totalElapsedSeconds = 0
        warnedSegmentIndex = nil
        savedWorkoutObjectID = nil
        hasSavedCurrentWorkout = false
        saveErrorMessage = nil
        applySnapshot(engine.snapshot(at: Date()), now: Date(), allowEffects: false)
        endLiveActivity()
    }

    func skip() {
        guard status != .idle else { return }
        let now = Date()
        let previous = lastSnapshot ?? engine.snapshot(at: now)
        engine.skip(at: now)
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: true, previousSnapshot: previous)
    }

    func refreshFromClock() {
        guard status == .running else { return }
        let now = Date()
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: true)
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
        if liveActivity != nil {
            updateLiveActivity(isRunning: status == .running)
            return
        }
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
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        liveActivity = nil
    }

    @discardableResult
    func saveWorkoutToHistory(context: NSManagedObjectContext, allowUpdate: Bool = false) -> Bool {
        guard let startTime = workoutStartTime, totalElapsedSeconds > 0 else { return false }
        if hasSavedCurrentWorkout && !allowUpdate { return false }

        let isFirstSave = savedWorkoutObjectID == nil
        let w: WorkoutHistoryEntity
        if let objectID = savedWorkoutObjectID,
           let existing = try? context.existingObject(with: objectID) as? WorkoutHistoryEntity {
            w = existing
        } else {
            w = WorkoutHistoryEntity(context: context)
            w.id = UUID()
            w.date = startTime
        }
        w.mode = WorkoutMode.intervals.rawValue
        w.sportName = workout.displayName
        w.totalDuration = Int32(totalElapsedSeconds)
        w.intervals = Int16(workout.intervals)
        w.workSeconds = Int16(workout.workSeconds)
        w.restSeconds = Int16(workout.restSeconds)
        w.warmupSeconds = Int16(workout.warmupSeconds)
        do {
            try context.save()
            savedWorkoutObjectID = w.objectID
            hasSavedCurrentWorkout = true
            saveErrorMessage = nil
            if isFirstSave { onWorkoutSaved?() }
            return true
        } catch {
            context.rollback()
            saveErrorMessage = error.localizedDescription
#if DEBUG
            print("Intervall-Workout konnte nicht gespeichert werden: \(error)")
#endif
            return false
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        let now = Date()
        applySnapshot(engine.snapshot(at: now), now: now, allowEffects: true)
    }

    private func prepareNewSession(at date: Date) {
        stopTimer()
        endLiveActivity()
        engine = TimerSessionEngine.interval(workout: workout)
        engine.reset()
        workoutStartTime = date
        totalElapsedSeconds = 0
        warnedSegmentIndex = nil
        savedWorkoutObjectID = nil
        hasSavedCurrentWorkout = false
        saveErrorMessage = nil
        lastSnapshot = engine.snapshot(at: date)
    }

    private func applySnapshot(_ snapshot: TimerSessionSnapshot, now: Date, allowEffects: Bool, previousSnapshot: TimerSessionSnapshot? = nil) {
        let previous = previousSnapshot ?? lastSnapshot
        let segmentChanged = previous?.segmentIndex != snapshot.segmentIndex

        phase = snapshot.phase
        currentInterval = snapshot.currentStep
        timeRemaining = snapshot.timeRemaining
        totalElapsedSeconds = snapshot.elapsedSeconds

        if allowEffects {
            playTransitionEffects(from: previous, to: snapshot)
            playWarningIfNeeded(from: previous, to: snapshot)
        }

        lastSnapshot = snapshot

        if snapshot.isFinished {
            completeWorkout(now: now)
        } else if segmentChanged && liveActivity != nil {
            updateLiveActivity(isRunning: status == .running)
        }
    }

    private func playTransitionEffects(from previous: TimerSessionSnapshot?, to snapshot: TimerSessionSnapshot) {
        guard let previous, previous.segmentIndex != snapshot.segmentIndex else { return }
        let soundEnabled = settings?.soundEnabled ?? true
        let vibrationEnabled = settings?.vibrationEnabled ?? true

        switch snapshot.phase {
        case .round:
            soundManager.playSound(type: .roundStart, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundStart, vibrationEnabled: vibrationEnabled)
            // Sprachansage für die neue Runde
            soundManager.speakRound(snapshot.currentStep, soundEnabled: soundEnabled)
        case .rest, .cooldown:
            soundManager.playSound(type: .roundEnd, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .roundEnd, vibrationEnabled: vibrationEnabled)
        case .finished:
            soundManager.playSound(type: .workoutEnd, soundEnabled: soundEnabled)
            soundManager.playHaptic(type: .workoutEnd, vibrationEnabled: vibrationEnabled)
        case .warmup:
            break
        }
    }

    private func playWarningIfNeeded(from previous: TimerSessionSnapshot?, to snapshot: TimerSessionSnapshot) {
        guard snapshot.phase == .round, settings?.warningEnabled ?? true else { return }
        guard warnedSegmentIndex != snapshot.segmentIndex else { return }
        guard let previous, previous.segmentIndex == snapshot.segmentIndex else { return }
        guard previous.timeRemaining > 10, snapshot.timeRemaining <= 10 else { return }

        // Diese Warnsegment-Grenze gilt jetzt als behandelt – auch wenn wir gleich
        // nicht abspielen, damit sie in einem späteren Tick nicht erneut auslöst.
        warnedSegmentIndex = snapshot.segmentIndex

        // Nur abspielen, wenn die 10-Sekunden-Grenze in Echtzeit überschritten wurde
        // (~1s pro Tick). Nach einem großen Sprung – App war im Hintergrund oder es
        // wurde geskippt – käme die Warnung viel zu spät und wird unterdrückt.
        guard previous.timeRemaining - snapshot.timeRemaining <= 2 else { return }

        let soundEnabled = settings?.soundEnabled ?? true
        let vibrationEnabled = settings?.vibrationEnabled ?? true
        soundManager.playSound(type: .roundWarning, soundEnabled: soundEnabled)
        soundManager.playHaptic(type: .roundWarning, vibrationEnabled: vibrationEnabled)
    }

    private func completeWorkout(now: Date) {
        guard status == .running else { return }
        engine.pause(at: now)
        status = .paused
        stopTimer()
        UIApplication.shared.isIdleTimerDisabled = false
        endLiveActivity()
        if let historyContext {
            saveWorkoutToHistory(context: historyContext, allowUpdate: true)
        }
    }

    var backgroundColor: Color {
        // Farbe nach Phase: Runde = grün, Pause/Rest = rot. Bleibt beim Stoppen
        // erhalten (Stopp in der Runde = grün, Stopp in der Pause = rot).
        switch phase {
        case .warmup, .cooldown: return .gray.opacity(0.3)
        case .round:             return .green.opacity(1.0)
        case .rest:              return .red.opacity(1.0)
        case .finished:          return .blue.opacity(0.3)
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
        lastSnapshot?.progress ?? 0
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

struct Achievement: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let isUnlocked: Bool
    let description: String
}

@MainActor
class StatsViewModel: ObservableObject {
    @Published var totalWorkouts = 0
    @Published var totalDuration = 0
    @Published var mostPopularSport = "—"
    @Published var last7Days = 0
    @Published var currentStreak = 0
    @Published var achievements: [Achievement] = []
    
    func calculate(context: NSManagedObjectContext, lang: Translations) {
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
            
            // Achievements berechnen
            calculateAchievements(workouts, lang: lang)
        } catch {
            print("Failed to calculate stats: \(error)")
        }
    }
    
    private func calculateAchievements(_ workouts: [WorkoutHistoryEntity], lang: Translations) {
        var list: [Achievement] = []
        
        // 1. 10 Tage Streak
        list.append(Achievement(
            title: lang.achievementWarriorTitle,
            icon: "flame.fill",
            isUnlocked: currentStreak >= 10,
            description: lang.achievementWarriorDesc
        ))
        
        // 2. 8 Stunden Gesamt (28.800 Sekunden)
        list.append(Achievement(
            title: lang.achievementHardWorkerTitle,
            icon: "timer",
            isUnlocked: totalDuration >= 28800,
            description: lang.achievementHardWorkerDesc
        ))
        
        // 3. 12-Runden Sparring (mindestens ein Workout mit 12 Runden)
        let has12Rounds = workouts.contains { $0.rounds >= 12 && $0.mode == WorkoutMode.fightTimer.rawValue }
        list.append(Achievement(
            title: lang.achievementProFighterTitle,
            icon: "medal.fill",
            isUnlocked: has12Rounds,
            description: lang.achievementProFighterDesc
        ))
        
        self.achievements = list
    }
    
    private func calculateStreak(_ workouts: [WorkoutHistoryEntity]) -> Int {
        guard !workouts.isEmpty else { return 0 }
        let calendar = Calendar.current
        // Distinct training days.
        let days = Set(workouts.compactMap { $0.date.map { calendar.startOfDay(for: $0) } })
        let today = calendar.startOfDay(for: Date())
        // Count consecutive training days ending today. Today counts toward the
        // streak; if there is no workout today yet but there was one yesterday,
        // the streak is still alive, so start counting from yesterday.
        var cursor = today
        if !days.contains(cursor),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           days.contains(yesterday) {
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
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
    @EnvironmentObject var promptManager: AppPromptManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPicker = false
    @State private var showEditor = false
    @State private var showSaved = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                vm.backgroundColor.ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: vm.phase)
                LinearGradient(
                    colors: [Color.black.opacity(0.05), Color.black.opacity(0.38)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                GeometryReader { geo in
                    if geo.size.width > geo.size.height {
                        landscapeLayout(geo: geo)
                    } else {
                        portraitLayout(geo: geo)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                vm.settings = settings
                vm.language = lang.current
                vm.historyContext = context
                vm.onWorkoutSaved = { promptManager.recordWorkoutCompleted() }
            }
            .onChange(of: lang.current) { new in vm.language = new }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    vm.refreshFromClock()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Button { showPicker = true } label: {
                        HStack(spacing: 6) {
                            Text(lang.t.localizedPresetName(vm.currentPreset.name))
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.black.opacity(0.25))
                        .clipShape(Capsule())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showEditor = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.white)
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
            .alert(lang.t.saveError, isPresented: Binding(
                get: { vm.saveErrorMessage != nil },
                set: { if !$0 { vm.saveErrorMessage = nil } }
            )) {
                Button(lang.t.ok, role: .cancel) { vm.saveErrorMessage = nil }
            } message: {
                Text(vm.saveErrorMessage ?? "")
            }
        }
    }

    // MARK: - Layouts (Bold / Athletic)

    private func portraitLayout(geo: GeometryProxy) -> some View {
        let ring = min(geo.size.width * 0.82, geo.size.height * 0.46, 330)
        return VStack(spacing: 16) {
            Spacer(minLength: 8)
            Text(vm.phaseText)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 14)
                Circle().trim(from: 0, to: vm.progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: vm.progress)
                Text(vm.timeString)
                    .font(.system(size: min(94, ring * 0.30), weight: .black, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
                    .frame(width: ring * 0.86)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
            .frame(width: ring, height: ring)
            Spacer(minLength: 8)
            HStack(spacing: 28) {
                resetButton
                playPauseButton
                skipButton
            }
            saveButton
        }
        .padding(.horizontal)
        .padding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func landscapeLayout(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(vm.phaseText)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.9))
                Text(vm.timeString)
                    .font(.system(size: geo.size.height * 0.6, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 20) {
                resetButton
                playPauseButton
                skipButton
            }
            .padding(.trailing, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls

    private var resetButton: some View {
        secondaryButton(icon: "arrow.counterclockwise") { vm.reset() }
    }

    private var skipButton: some View {
        secondaryButton(icon: "forward.fill") { vm.skip() }
    }

    private func secondaryButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 62, height: 62)
                .background(Color.black.opacity(0.22))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5))
        }
    }

    private var playPauseButton: some View {
        Button {
            if vm.status == .running { vm.pause() }
            else { vm.status == .idle ? vm.start() : vm.resume() }
        } label: {
            Image(systemName: vm.status == .running ? "pause.fill" : "play.fill")
                .font(.system(size: 38, weight: .black))
                .foregroundColor(.black)
                .frame(width: 92, height: 92)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
    }

    private var saveButton: some View {
        Button(vm.hasSavedCurrentWorkout ? lang.t.saved : lang.t.saveWorkout) {
            if vm.saveWorkoutToHistory(context: context) {
                showSaved = true
            }
        }
        .font(.system(size: 17, weight: .bold))
        .textCase(.uppercase)
        .foregroundColor(.black)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(vm.status == .paused ? 1 : 0)
        .disabled(vm.status != .paused || vm.hasSavedCurrentWorkout)
        .padding(.top, 4)
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
                    .onDelete { offsets in
                        pm.delete(at: offsets)
                        if !pm.customProfiles.contains(where: { $0.id == selected.id }) {
                            selected = FightPreset.defaultPresets[0]
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
