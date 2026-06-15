//
//  Views.swift
//  Boxing timer
//

import SwiftUI
import CoreData
import StoreKit
import UserNotifications
import Combine

// MARK: - Interval Timer View
struct IntervalTimerView: View {
    @State private var selectedDevice = IntervalDevice.running
    @State private var selectedLevel = IntervalLevel.beginner
    @StateObject private var vm: IntervalTimerViewModel
    @State private var showConfig = true
    @State private var showSaved = false
    @Environment(\.managedObjectContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var promptManager: AppPromptManager

    @State private var useCustom = false
    @State private var customWork = 30
    @State private var customRest = 30
    @State private var customIntervals = 8
    @State private var customWarmup = 60

    init() {
        let workout = IntervalWorkout.workout(for: .running, level: .beginner)
        _vm = StateObject(wrappedValue: IntervalTimerViewModel(workout: workout))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AthleticBackground(color: vm.backgroundColor, phase: vm.phase)
                if showConfig { configView } else { timerView }
            }
            .preferredColorScheme(.dark)
            .navigationTitle(lang.t.intervalTitle)
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
            .toolbar {
                if !showConfig {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            vm.reset()
                            showConfig = true
                        } label: {
                            DSChip {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                                    Text(lang.t.back).font(.system(size: 15, weight: .bold))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    var configView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DS.Space.m) {
                    Text(lang.t.chooseTraining)
                        .font(DS.display(26))
                        .textCase(.uppercase)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, DS.Space.l)

                    DSSegmentedPicker(selection: $useCustom, options: [
                        (false, lang.t.preset),
                        (true, lang.t.customSetting)
                    ])

                    if useCustom {
                        VStack(spacing: 0) {
                            stepperRow(label: lang.t.warmUp, value: $customWarmup, range: 0...600, step: 5, unit: "s")
                            Divider().overlay(DS.divider)
                            stepperRow(label: lang.t.intervals, value: $customIntervals, range: 1...50, step: 1, unit: "x")
                            Divider().overlay(DS.divider)
                            stepperRow(label: lang.t.work, value: $customWork, range: 5...600, step: 1, unit: "s")
                            Divider().overlay(DS.divider)
                            stepperRow(label: lang.t.rest, value: $customRest, range: 0...600, step: 1, unit: "s")
                        }
                        .background(DS.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))

                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            Text(lang.t.yourTraining).font(DS.headline()).foregroundColor(.white)
                            Text("\(lang.t.warmUp): \(customWarmup)s").foregroundColor(DS.textSecondary)
                            Text("\(lang.t.intervals): \(customIntervals)x (\(customWork)s \(lang.t.work) / \(customRest)s \(lang.t.rest))").foregroundColor(DS.textSecondary)
                            Text("\(lang.t.totalApprox) \(totalMinutes) min").foregroundColor(DS.textSecondary)
                        }
                        .dsCard()
                    } else {
                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            Text(lang.t.device).font(DS.headline()).foregroundColor(.white)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(IntervalDevice.allCases, id: \.self) { d in
                                    DSSelectableCard(title: d.localizedName(lang.t), isSelected: selectedDevice == d) {
                                        selectedDevice = d
                                    }
                                }
                            }
                        }
                        .dsCard()

                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            Text(lang.t.level).font(DS.headline()).foregroundColor(.white)
                            HStack(spacing: 8) {
                                ForEach(IntervalLevel.allCases, id: \.self) { l in
                                    DSSelectableCard(title: l.localizedName(lang.t), isSelected: selectedLevel == l) {
                                        selectedLevel = l
                                    }
                                }
                            }
                        }
                        .dsCard()

                        VStack(alignment: .leading, spacing: DS.Space.s) {
                            Text(lang.t.yourTraining).font(DS.headline()).foregroundColor(.white)
                            let w = IntervalWorkout.workout(for: selectedDevice, level: selectedLevel)
                            Text("\(lang.t.warmUp): \(w.warmupSeconds / 60) min").foregroundColor(DS.textSecondary)
                            Text("\(lang.t.intervals): \(w.intervals)x (\(w.workSeconds)s \(lang.t.work) / \(w.restSeconds)s \(lang.t.rest))").foregroundColor(DS.textSecondary)
                            Text("\(lang.t.coolDown): \(w.cooldownSeconds / 60) min").foregroundColor(DS.textSecondary)
                        }
                        .dsCard()
                    }
                }
                .padding()
            }

            Button {
                let w: IntervalWorkout
                if useCustom {
                    w = IntervalWorkout(device: .bagWork, level: .intermediate,
                        warmupSeconds: customWarmup, intervals: customIntervals,
                        workSeconds: customWork, restSeconds: customRest, cooldownSeconds: 0)
                } else {
                    w = IntervalWorkout.workout(for: selectedDevice, level: selectedLevel)
                }
                vm.updateWorkout(w)
                showConfig = false
            } label: {
                Text(lang.t.startTraining)
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .padding()
        }
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(label).font(DS.body()).foregroundColor(.white)
            Spacer()
            Text("\(value.wrappedValue)\(unit)").font(DS.body()).foregroundColor(DS.textSecondary).frame(width: 52, alignment: .trailing)
            Stepper("", value: value, in: range, step: step).labelsHidden().tint(DS.accent)
        }
        .padding(.horizontal).padding(.vertical, 12)
    }

    private var totalMinutes: Int {
        let total = customWarmup + (customIntervals * (customWork + customRest))
        return max(1, total / 60)
    }

    var timerView: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                // QUERFORMAT
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(vm.phaseText)
                            .font(DS.display(20)).textCase(.uppercase).tracking(2)
                            .foregroundColor(.white.opacity(0.9))
                        Text(vm.timeString)
                            .font(DS.timer(geo.size.height * 0.6))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.3)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(spacing: 20) {
                        DSCircleButton(icon: "arrow.counterclockwise") { vm.reset() }
                        DSPlayPauseButton(isRunning: vm.status == .running) {
                            if vm.status == .running { vm.pause() }
                            else { vm.status == .idle ? vm.start() : vm.resume() }
                        }
                        DSCircleButton(icon: "forward.fill") { vm.skip() }
                    }
                    .padding(.trailing, 36)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // HOCHFORMAT
                let ring = min(geo.size.width * 0.82, geo.size.height * 0.46, 330)
                VStack(spacing: DS.Space.m) {
                    Spacer(minLength: 8)
                    DSTimerDial(phaseText: vm.phaseText, timeString: vm.timeString, progress: vm.progress, diameter: ring)
                    Spacer(minLength: 8)
                    HStack(spacing: 28) {
                        DSCircleButton(icon: "arrow.counterclockwise") { vm.reset() }
                        DSPlayPauseButton(isRunning: vm.status == .running) {
                            if vm.status == .running { vm.pause() }
                            else { vm.status == .idle ? vm.start() : vm.resume() }
                        }
                        DSCircleButton(icon: "forward.fill") { vm.skip() }
                    }
                    Button(vm.hasSavedCurrentWorkout ? lang.t.saved : lang.t.saveWorkout) {
                        if vm.saveWorkoutToHistory(context: context) {
                            showSaved = true
                        }
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .opacity(vm.status == .paused ? 1 : 0)
                    .disabled(vm.status != .paused || vm.hasSavedCurrentWorkout)
                    .padding(.top, 4)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
}

// MARK: - History View
struct HistoryView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutHistoryEntity.date, ascending: false)]
    ) private var workouts: FetchedResults<WorkoutHistoryEntity>

    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var lang: LanguageManager
    @State private var showDeleteAll = false

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60)).foregroundColor(.gray)
                        Text(lang.t.noWorkouts)
                            .font(.title2).foregroundColor(.gray)
                        Text(lang.t.noWorkoutsDesc)
                            .font(.subheadline).foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(workouts, id: \.id) { w in
                            NavigationLink(destination: WorkoutDetailView(workout: w)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lang.t.localizedPresetName(w.sportName ?? "Unknown")).font(.headline)
                                        Text(w.mode ?? "").font(.subheadline).foregroundColor(.secondary)
                                        Text(formatDate(w.date ?? Date())).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(formatDuration(Int(w.totalDuration))).font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indices in
                            indices.forEach { context.delete(workouts[$0]) }
                            try? context.save()
                        }
                    }
                }
            }
            .navigationTitle(lang.t.historyTitle)
            .toolbar {
                if !workouts.isEmpty {
                    Button(lang.t.deleteAll) { showDeleteAll = true }
                        .foregroundColor(.red)
                }
            }
            .confirmationDialog(lang.t.confirmDeleteAll, isPresented: $showDeleteAll) {
                Button(lang.t.deleteAll, role: .destructive) {
                    workouts.forEach { context.delete($0) }
                    try? context.save()
                }
                Button(lang.t.cancel, role: .cancel) {}
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return "\(mins):\(String(format: "%02d", secs)) min"
    }
}

struct WorkoutDetailView: View {
    let workout: WorkoutHistoryEntity
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.managedObjectContext) private var context
    @State private var notes: String = ""

    init(workout: WorkoutHistoryEntity) {
        self.workout = workout
        _notes = State(initialValue: workout.notes ?? "")
    }

    var body: some View {
        Form {
            Section(lang.t.general) {
                LabeledContent(lang.t.sport, value: lang.t.localizedPresetName(workout.sportName ?? "—"))
                LabeledContent(lang.t.mode, value: workout.mode ?? "—")
                LabeledContent(lang.t.date, value: formatDate(workout.date ?? Date()))
                LabeledContent(lang.t.duration, value: formatDuration(Int(workout.totalDuration)))
            }

            Section(lang.t.notes) {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                Button(lang.t.saveNotes) {
                    workout.notes = notes
                    try? context.save()
                }
                .disabled(notes == (workout.notes ?? ""))
            }

            if workout.mode == "Fight Timer" {
                Section(lang.t.fightTimerDetails) {
                    LabeledContent(lang.t.rounds, value: "\(workout.rounds)")
                    LabeledContent(lang.t.roundTime, value: "\(workout.roundSeconds / 60) min")
                    LabeledContent(lang.t.rest, value: "\(workout.restSeconds)s")
                    LabeledContent(lang.t.warmUp, value: "\(workout.warmupSeconds)s")
                }
            }

            if workout.mode == "Intervals" {
                Section(lang.t.intervalDetails) {
                    LabeledContent(lang.t.intervals, value: "\(workout.intervals)")
                    LabeledContent(lang.t.work, value: "\(workout.workSeconds)s")
                    LabeledContent(lang.t.rest, value: "\(workout.restSeconds)s")
                    LabeledContent(lang.t.warmUp, value: "\(workout.warmupSeconds)s")
                }
            }
        }
        .navigationTitle(lang.t.workoutDetails)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return "\(mins):\(String(format: "%02d", secs)) min"
    }
}

// MARK: - Stats View
struct StatsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutHistoryEntity.date, ascending: false)]
    ) private var workouts: FetchedResults<WorkoutHistoryEntity>
    @StateObject private var vm = StatsViewModel()
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    // Quick Stats
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            StatCard(title: lang.t.workoutsLabel, value: "\(vm.totalWorkouts)", icon: "flame.fill", color: .orange)
                            StatCard(title: lang.t.streak, value: "\(vm.currentStreak)", icon: "calendar", color: .blue)
                        }
                        HStack(spacing: 15) {
                            StatCard(title: lang.t.thisWeek, value: "\(vm.last7Days)", icon: "chart.bar.fill", color: .green)
                            StatCard(title: lang.t.totalTime, value: formatTotalTime(vm.totalDuration), icon: "clock.fill", color: .purple)
                        }
                    }
                    .padding(.horizontal)

                    // Heatmap
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang.t.heatmapTitle).font(.headline)
                        HeatmapView(workouts: Array(workouts))
                    }
                    .padding(.horizontal)

                    // Achievements
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang.t.achievementsTitle).font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(vm.achievements) { achievement in
                                    AchievementCard(achievement: achievement)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                    .padding(.horizontal)

                    // Favorite Sport
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang.t.favoriteSport).font(.headline)
                        HStack {
                            Text(vm.mostPopularSport).font(.title).fontWeight(.bold)
                            Spacer()
                        }
                        .padding().frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1)).cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
                .padding(.top)
            }
            .navigationTitle(lang.t.statsTitle)
            .onAppear {
                vm.calculate(context: context, lang: lang.t)
            }
            .onChange(of: workouts.count) { _ in
                vm.calculate(context: context, lang: lang.t)
            }
        }
    }

    private func formatTotalTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" } else { return "\(minutes) min" }
    }
}

struct HeatmapView: View {
    let workouts: [WorkoutHistoryEntity]
    @EnvironmentObject var lang: LanguageManager

    private let weeksToShow = 18
    private let cell: CGFloat = 13
    private let spacing: CGFloat = 3
    private let weekdayColWidth: CGFloat = 18
    private let headerHeight: CGFloat = 12

    private var locale: Locale { Locale(identifier: lang.current.rawValue) }

    private var calendar: Calendar {
        var c = Calendar.current
        c.locale = locale
        return c
    }

    private var monthSymbols: [String] {
        let f = DateFormatter(); f.locale = locale; return f.shortMonthSymbols
    }

    private var weekdaySymbols: [String] {
        let f = DateFormatter(); f.locale = locale; return f.shortWeekdaySymbols
    }

    var body: some View {
        let cal = calendar
        let today = cal.startOfDay(for: Date())
        let minutes = minutesPerDay(cal: cal)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let weekStarts: [Date] = (0..<weeksToShow).map { i in
            cal.date(byAdding: .weekOfYear, value: -(weeksToShow - 1 - i), to: weekStart) ?? weekStart
        }

        VStack(alignment: .leading, spacing: 6) {
            monthHeader(weekStarts: weekStarts, cal: cal)

            HStack(alignment: .top, spacing: spacing) {
                weekdayColumn(cal: cal)
                ForEach(Array(weekStarts.enumerated()), id: \.offset) { _, ws in
                    VStack(spacing: spacing) {
                        ForEach(0..<7, id: \.self) { row in
                            let date = cal.date(byAdding: .day, value: row, to: ws) ?? ws
                            cellView(date: date, today: today, minutes: minutes[date] ?? 0)
                        }
                    }
                }
            }

            legend
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func monthHeader(weekStarts: [Date], cal: Calendar) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(maxWidth: .infinity, minHeight: headerHeight)
            ForEach(monthMarkers(weekStarts: weekStarts, cal: cal)) { marker in
                Text(marker.label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .fixedSize()
                    .offset(x: xFor(col: marker.col))
            }
        }
        .frame(height: headerHeight)
    }

    private func weekdayColumn(cal: Calendar) -> some View {
        VStack(spacing: spacing) {
            ForEach(0..<7, id: \.self) { row in
                Text(row % 2 == 0 ? weekdayLabel(row: row, cal: cal) : "")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(width: weekdayColWidth, height: cell, alignment: .trailing)
            }
        }
    }

    private func cellView(date: Date, today: Date, minutes: Int) -> some View {
        let isFuture = date > today
        let isToday = date == today
        return RoundedRectangle(cornerRadius: 3)
            .fill(isFuture ? Color.clear : color(minutes: minutes))
            .frame(width: cell, height: cell)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.primary, lineWidth: isToday ? 1.5 : 0)
            )
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text(lang.t.heatmapLess).font(.system(size: 9)).foregroundColor(.secondary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForLevel(level))
                    .frame(width: 11, height: 11)
            }
            Text(lang.t.heatmapMore).font(.system(size: 9)).foregroundColor(.secondary)
            Spacer()
            Text(lang.t.heatmapUnit).font(.system(size: 9)).foregroundColor(.secondary)
        }
        .padding(.top, 2)
    }

    // MARK: - Helpers

    private func xFor(col: Int) -> CGFloat {
        weekdayColWidth + spacing + CGFloat(col) * (cell + spacing)
    }

    private func minutesPerDay(cal: Calendar) -> [Date: Int] {
        var m: [Date: Int] = [:]
        for w in workouts {
            guard let d = w.date else { continue }
            let day = cal.startOfDay(for: d)
            m[day, default: 0] += Int(w.totalDuration) / 60
        }
        return m
    }

    private func weekdayLabel(row: Int, cal: Calendar) -> String {
        let symbols = weekdaySymbols
        let idx = (cal.firstWeekday - 1 + row) % 7
        return idx < symbols.count ? symbols[idx] : ""
    }

    private struct MonthMarker: Identifiable { let id: Int; let col: Int; let label: String }

    private func monthMarkers(weekStarts: [Date], cal: Calendar) -> [MonthMarker] {
        var markers: [MonthMarker] = []
        var lastMonth = -1
        var lastX: CGFloat = -100
        for (col, ws) in weekStarts.enumerated() {
            let m = cal.component(.month, from: ws)
            guard m != lastMonth else { continue }
            lastMonth = m
            let x = xFor(col: col)
            if x - lastX >= 24, m - 1 >= 0, m - 1 < monthSymbols.count {
                markers.append(MonthMarker(id: col, col: col, label: monthSymbols[m - 1]))
                lastX = x
            }
        }
        return markers
    }

    private func color(minutes: Int) -> Color {
        switch minutes {
        case 0:       return Color.gray.opacity(0.15)
        case 1...14:  return Color.green.opacity(0.35)
        case 15...29: return Color.green.opacity(0.6)
        case 30...44: return Color.green.opacity(0.8)
        default:      return Color.green
        }
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0:  return Color.gray.opacity(0.15)
        case 1:  return Color.green.opacity(0.35)
        case 2:  return Color.green.opacity(0.6)
        case 3:  return Color.green.opacity(0.8)
        default: return Color.green
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: achievement.icon)
                    .font(.system(size: 30))
                    .foregroundColor(achievement.isUnlocked ? .blue : .gray)
            }
            Text(achievement.title)
                .font(.caption).fontWeight(.bold)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
            Text(achievement.description)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(width: 80)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .opacity(achievement.isUnlocked ? 1.0 : 0.6)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 30)).foregroundColor(color)
            Text(value).font(.title).fontWeight(.bold)
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding()
        .background(color.opacity(0.1)).cornerRadius(12)
    }
}

// MARK: - Donation Prompt View (erscheint nach 30 Tagen)
struct DonationPromptView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lang: LanguageManager
    @State private var showDonationSheet = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🥊")
                .font(.system(size: 70))

            Text(lang.t.donationTitle)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(lang.t.donationSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showDonationSheet = true
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                    Text(lang.t.donationSupport)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(14)
            }
            .padding(.horizontal)

            Button(lang.t.cancel) {
                dismiss()
            }
            .foregroundColor(.secondary)
            .font(.subheadline)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showDonationSheet) {
            DonationView()
                .onDisappear { dismiss() }
        }
    }
}

// MARK: - Privacy Policy View
struct PrivacyPolicyView: View {
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text("🥊 Box Interval Timer")
                    .font(.title.bold())
                Text(lang.t.privacyDate)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Kurzfassung
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text(lang.t.privacySummary)
                        .font(.subheadline)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                Group {
                    PolicySection(
                        icon: "internaldrive",
                        title: lang.t.privacyS1Title,
                        text: lang.t.privacyS1Text
                    )
                    PolicySection(
                        icon: "wifi.slash",
                        title: lang.t.privacyS2Title,
                        text: lang.t.privacyS2Text
                    )
                    PolicySection(
                        icon: "creditcard",
                        title: lang.t.privacyS3Title,
                        text: lang.t.privacyS3Text
                    )
                    PolicySection(
                        icon: "bell",
                        title: lang.t.privacyS4Title,
                        text: lang.t.privacyS4Text
                    )
                    PolicySection(
                        icon: "envelope",
                        title: "Kontakt",
                        text: "box.timer.app@gmail.com"
                    )
                }

                Link(destination: URL(string: "https://mr-dzzs21.github.io/Box-Interval-Timer/privacy-policy.html")!) {
                    HStack {
                        Image(systemName: "globe")
                        Text(lang.t.privacyOpenBrowser)
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.top, 4)

                Text("© 2026 Diyar Kaymaz")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
            .padding()
        }
        .navigationTitle(lang.t.privacyNavTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PolicySection: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.orange)
                    .frame(width: 20)
                Text(title)
                    .font(.headline)
            }
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(12)
    }
}

// MARK: - Donation View
struct DonationView: View {
    @StateObject private var manager = DonationManager.shared
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    // Header
                    VStack(spacing: 12) {
                        Text("🥊")
                            .font(.system(size: 70))
                        Text(lang.t.donationTitle)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(lang.t.donationSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // Produkte
                    if manager.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text(lang.t.loading)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                    } else if manager.products.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text(lang.t.donationUnavailable)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button(lang.t.retry) {
                                Task { await manager.loadProducts() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 14) {
                            ForEach(manager.products, id: \.id) { product in
                                DonationButton(product: product, manager: manager)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle(lang.t.donationSupport)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t.done) { dismiss() }
                }
            }
            .task {
                await manager.loadProducts()
            }
            .alert(lang.t.donationThankYou, isPresented: $manager.purchaseSuccess) {
                Button(lang.t.ok, role: .cancel) { dismiss() }
            }
            .alert("Fehler", isPresented: Binding(
                get: { manager.errorMessage != nil },
                set: { if !$0 { manager.errorMessage = nil } }
            )) {
                Button(lang.t.ok, role: .cancel) { manager.errorMessage = nil }
            } message: {
                Text(manager.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Donation Button
struct DonationButton: View {
    let product: Product
    @ObservedObject var manager: DonationManager

    var emoji: String {
        switch product.id {
        case "box.tip.coffee":   return "☕"
        case "box.tip.training": return "🥊"
        case "box.tip.champion": return "🏆"
        default:                 return "💛"
        }
    }

    var body: some View {
        Button {
            Task { await manager.purchase(product) }
        } label: {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 36))
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.title3.bold())
                    .foregroundColor(.blue)
            }
            .padding(18)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(16)
        }
        .disabled(manager.isPurchasing)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var lang: LanguageManager
    @State private var showDonation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.l) {
                    section(lang.t.audioHaptic) {
                        toggleRow(lang.t.soundEnabled, $settings.soundEnabled)
                        Divider().overlay(DS.divider)
                        toggleRow(lang.t.vibrationEnabled, $settings.vibrationEnabled)
                        Divider().overlay(DS.divider)
                        toggleRow(lang.t.warningEnabled, $settings.warningEnabled)
                    }

                    section("Todos") {
                        Toggle(lang.t.todoNotifications, isOn: $settings.todoNotificationsEnabled)
                            .tint(DS.accent)
                            .font(DS.body())
                            .foregroundColor(.white)
                            .onChange(of: settings.todoNotificationsEnabled) { enabled in
                                if enabled {
                                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                                        DispatchQueue.main.async {
                                            if granted {
                                                TodoManager.shared.scheduleNotificationIfNeeded()
                                            } else {
                                                settings.todoNotificationsEnabled = false
                                            }
                                        }
                                    }
                                } else {
                                    TodoManager.shared.cancelNotifications()
                                }
                            }
                    }

                    Button { showDonation = true } label: {
                        HStack {
                            Text("🙏")
                            Text(lang.t.donationSupport).font(DS.body()).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "heart.fill").foregroundColor(DS.accent)
                        }
                        .dsCard()
                    }

                    section(lang.t.language) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { idx, language in
                            Button { lang.current = language } label: {
                                HStack {
                                    Text(language.displayName).font(DS.body()).foregroundColor(.white)
                                    Spacer()
                                    if lang.current == language {
                                        Image(systemName: "checkmark").foregroundColor(DS.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 7)
                            }
                            if idx < AppLanguage.allCases.count - 1 { Divider().overlay(DS.divider) }
                        }
                    }

                    section(lang.t.about) {
                        aboutRow(lang.t.version, value: appVersion)
                        Divider().overlay(DS.divider)
                        aboutRow(lang.t.developer, value: "Diyar Kaymaz")
                        Divider().overlay(DS.divider)
                        Link(destination: URL(string: "mailto:box.timer.app@gmail.com?subject=Feedback%20-%20Boxing%20Interval%20Timer")!) {
                            linkRow(icon: "envelope", iconColor: DS.accent, title: lang.t.feedbackButton)
                        }
                        Divider().overlay(DS.divider)
                        Link(destination: URL(string: "https://apps.apple.com/app/id6759615674?action=write-review")!) {
                            linkRow(icon: "star.fill", iconColor: .yellow, title: lang.t.rateApp)
                        }
                        Divider().overlay(DS.divider)
                        NavigationLink(destination: PrivacyPolicyView()) {
                            linkRow(icon: "lock.shield", iconColor: DS.textSecondary, title: lang.t.privacyPolicy)
                        }
                    }

                    section(lang.t.presetsInfo) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("• Boxen: 12x3min")
                            Text("• MMA: 3x5min")
                            Text("• K1: 3x3min")
                            Text("• Muay Thai: 5x3min")
                            Text("• BJJ: 1x5min")
                            Text("• Judo: 1x4min")
                            Text("• Ringen: 3x2min")
                            Text("• Taekwondo: 3x2min")
                        }
                        .font(.caption)
                        .foregroundColor(DS.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(DS.bg.ignoresSafeArea())
            .navigationTitle(lang.t.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showDonation) {
            DonationView()
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .foregroundColor(DS.textTertiary)
                .padding(.leading, 4)
            VStack(spacing: 8) { content() }
                .dsCard()
        }
    }

    private func toggleRow(_ title: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .tint(DS.accent)
            .font(DS.body())
            .foregroundColor(.white)
    }

    private func aboutRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(DS.body()).foregroundColor(.white)
            Spacer()
            Text(value).font(DS.body()).foregroundColor(DS.textSecondary)
        }
    }

    private func linkRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(iconColor).frame(width: 22)
            Text(title).font(DS.body()).foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(DS.textTertiary)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "\(version) (\(build))"
        }
        return version
    }
}

// MARK: - Stopwatch View
class StopwatchViewModel: ObservableObject {
    @Published var elapsed: TimeInterval = 0
    @Published var laps: [TimeInterval] = []
    @Published var isRunning = false

    private var timer: Timer?
    private var startTime: Date?
    private var accumulated: TimeInterval = 0
    private var lapStart: TimeInterval = 0

    func startStop() {
        if isRunning {
            accumulated = elapsed
            timer?.invalidate()
            timer = nil
        } else {
            startTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                guard let self, let start = self.startTime else { return }
                self.elapsed = self.accumulated + Date().timeIntervalSince(start)
            }
        }
        isRunning.toggle()
    }

    func lap() {
        let lapTime = elapsed - lapStart
        laps.insert(lapTime, at: 0)
        lapStart = elapsed
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        elapsed = 0
        accumulated = 0
        lapStart = 0
        laps = []
        isRunning = false
        startTime = nil
    }

    func formatted(_ t: TimeInterval) -> String {
        let min = Int(t) / 60
        let sec = Int(t) % 60
        let cs  = Int((t * 100).truncatingRemainder(dividingBy: 100))
        return String(format: "%02d:%02d.%02d", min, sec, cs)
    }
}

struct StopwatchView: View {
    @EnvironmentObject var lang: LanguageManager
    @StateObject private var vm = StopwatchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Zeit-Anzeige
                Text(vm.formatted(vm.elapsed))
                    .font(.system(size: 72, weight: .thin, design: .monospaced))
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                // Buttons
                HStack(spacing: 40) {
                    // Lap / Reset Button
                    Button {
                        if vm.isRunning { vm.lap() } else { vm.reset() }
                    } label: {
                        Text(vm.isRunning ? lang.t.stopwatchLap : lang.t.stopwatchReset)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(width: 80, height: 80)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                    .disabled(!vm.isRunning && vm.elapsed == 0)

                    // Start / Stop Button
                    Button {
                        vm.startStop()
                    } label: {
                        Text(vm.isRunning ? lang.t.stopwatchStop : lang.t.stopwatchStart)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(vm.isRunning ? Color.red : Color.green)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)

                // Runden-Liste
                if !vm.laps.isEmpty {
                    Divider()
                    List {
                        ForEach(Array(vm.laps.enumerated()), id: \.offset) { index, lap in
                            HStack {
                                Text("\(lang.t.stopwatchLap) \(vm.laps.count - index)")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(vm.formatted(lap))
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                Spacer()
            }
            .navigationTitle(lang.t.stopwatchTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
