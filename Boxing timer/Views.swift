//
//  Views.swift
//  Boxing timer
//

import SwiftUI
import CoreData
import StoreKit

// MARK: - Interval Timer View
struct IntervalTimerView: View {
    @State private var selectedDevice = IntervalDevice.running
    @State private var selectedLevel = IntervalLevel.beginner
    @StateObject private var vm: IntervalTimerViewModel
    @State private var showConfig = true
    @State private var showSaved = false
    @Environment(\.managedObjectContext) private var context
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
                vm.backgroundColor.ignoresSafeArea()
                if showConfig { configView } else { timerView }
            }
            .navigationTitle(lang.t.intervalTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { vm.settings = settings; vm.language = lang.current }
            .onChange(of: lang.current) { _, new in vm.language = new }
        }
    }

    var configView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(lang.t.chooseTraining)
                    .font(.title2).fontWeight(.bold).padding(.top, 40)

                Picker("Modus", selection: $useCustom) {
                    Text(lang.t.preset).tag(false)
                    Text(lang.t.customSetting).tag(true)
                }
                .pickerStyle(.segmented)

                if useCustom {
                    VStack(spacing: 0) {
                        stepperRow(label: lang.t.warmUp, value: $customWarmup, range: 0...600, step: 5, unit: "s")
                        Divider()
                        stepperRow(label: lang.t.intervals, value: $customIntervals, range: 1...50, step: 1, unit: "x")
                        Divider()
                        stepperRow(label: lang.t.work, value: $customWork, range: 5...600, step: 1, unit: "s")
                        Divider()
                        stepperRow(label: lang.t.rest, value: $customRest, range: 0...600, step: 1, unit: "s")
                    }
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(lang.t.yourTraining).font(.headline)
                        Text("\(lang.t.warmUp): \(customWarmup)s")
                        Text("\(lang.t.intervals): \(customIntervals)x (\(customWork)s \(lang.t.work) / \(customRest)s \(lang.t.rest))")
                        Text("\(lang.t.totalApprox) \(totalMinutes) min")
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.1)).cornerRadius(12)

                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(lang.t.device).font(.headline)
                        Picker(lang.t.device, selection: $selectedDevice) {
                            ForEach(IntervalDevice.allCases, id: \.self) { d in
                                Text(d.localizedName(lang.t)).tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding().background(Color.black.opacity(0.1)).cornerRadius(12)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(lang.t.level).font(.headline)
                        Picker(lang.t.level, selection: $selectedLevel) {
                            ForEach(IntervalLevel.allCases, id: \.self) { l in
                                Text(l.localizedName(lang.t)).tag(l)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding().background(Color.black.opacity(0.1)).cornerRadius(12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.t.yourTraining).font(.headline)
                        let w = IntervalWorkout.workout(for: selectedDevice, level: selectedLevel)
                        Text("\(lang.t.warmUp): \(w.warmupSeconds / 60) min")
                        Text("\(lang.t.intervals): \(w.intervals)x (\(w.workSeconds)s \(lang.t.work) / \(w.restSeconds)s \(lang.t.rest))")
                        Text("\(lang.t.coolDown): \(w.cooldownSeconds / 60) min")
                    }
                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.1)).cornerRadius(12)
                }

                Button(lang.t.startTraining) {
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
                }
                .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                .background(Color.blue).cornerRadius(12)

                Spacer()
            }
            .padding()
        }
    }

    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(label).font(.body)
            Spacer()
            Text("\(value.wrappedValue)\(unit)").foregroundColor(.secondary).frame(width: 50, alignment: .trailing)
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
        .padding(.horizontal).padding(.vertical, 12)
    }

    private var totalMinutes: Int {
        let total = customWarmup + (customIntervals * (customWork + customRest))
        return max(1, total / 60)
    }

    var timerView: some View {
        VStack(spacing: 30) {
            HStack {
                Button {
                    vm.reset()
                    showConfig = true
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text(lang.t.back)
                    }
                    .padding().background(Color.black.opacity(0.2)).cornerRadius(10)
                }
                .foregroundColor(.primary)
                Spacer()
            }

            Spacer()

            Text(vm.phaseText)
                .font(.system(size: 32, weight: .bold)).foregroundColor(.primary)

            ZStack {
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 15).frame(width: 320, height: 320)
                Circle().trim(from: 0, to: vm.progress).stroke(Color.primary, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                    .frame(width: 320, height: 320).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: vm.progress)
                Text(vm.timeString).font(.system(size: 110, weight: .bold, design: .rounded)).foregroundColor(.primary)
            }

            Spacer()

            HStack(spacing: 30) {
                Button { vm.reset() } label: {
                    Image(systemName: "arrow.counterclockwise").font(.system(size: 28))
                        .frame(width: 70, height: 70).background(Color.black.opacity(0.2)).clipShape(Circle())
                }
                Button {
                    if vm.status == .running { vm.pause() }
                    else { vm.status == .idle ? vm.start() : vm.resume() }
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

            Button(lang.t.saveWorkout) {
                vm.saveWorkoutToHistory(context: context)
                showSaved = true
                promptManager.recordWorkoutCompleted()
            }
            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
            .background(Color.blue).cornerRadius(12).padding(.horizontal)
            .opacity(vm.phase == .finished ? 1 : 0)
            .disabled(vm.phase != .finished)
        }
        .padding()
        .alert(lang.t.saved, isPresented: $showSaved) {
            Button(lang.t.ok, role: .cancel) {}
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
                                        Text(w.sportName ?? "Unknown").font(.headline)
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

    var body: some View {
        Form {
            Section(lang.t.general) {
                LabeledContent(lang.t.sport, value: workout.sportName ?? "—")
                LabeledContent(lang.t.mode, value: workout.mode ?? "—")
                LabeledContent(lang.t.date, value: formatDate(workout.date ?? Date()))
                LabeledContent(lang.t.duration, value: formatDuration(Int(workout.totalDuration)))
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
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        StatCard(title: lang.t.workoutsLabel, value: "\(workouts.count)", icon: "flame.fill", color: .orange)
                        StatCard(title: lang.t.streak, value: "\(currentStreak)", icon: "calendar", color: .blue)
                    }
                    HStack(spacing: 15) {
                        StatCard(title: lang.t.thisWeek, value: "\(last7Days)", icon: "chart.bar.fill", color: .green)
                        StatCard(title: lang.t.totalTime, value: formatTotalTime(totalDuration), icon: "clock.fill", color: .purple)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lang.t.favoriteSport).font(.headline)
                        HStack {
                            Text(mostPopularSport).font(.title).fontWeight(.bold)
                            Spacer()
                        }
                        .padding().frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1)).cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .navigationTitle(lang.t.statsTitle)
        }
    }

    private var totalDuration: Int {
        workouts.reduce(0) { $0 + Int($1.totalDuration) }
    }

    private var last7Days: Int {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return workouts.filter { ($0.date ?? Date()) >= sevenDaysAgo }.count
    }

    private var mostPopularSport: String {
        let counts = Dictionary(grouping: workouts) { $0.sportName ?? "Unknown" }.mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "—"
    }

    private var currentStreak: Int {
        guard !workouts.isEmpty else { return 0 }
        let calendar = Calendar.current
        let trainingDays = Set(workouts.compactMap { w -> Date? in
            guard let date = w.date else { return nil }
            return calendar.startOfDay(for: date)
        }).sorted(by: >)

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        guard let mostRecent = trainingDays.first,
              mostRecent == today || mostRecent == yesterday else { return 0 }

        var streak = 1
        var checkDate = mostRecent
        for day in trainingDays.dropFirst() {
            let expectedPrevious = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            if day == expectedPrevious { streak += 1; checkDate = day } else { break }
        }
        return streak
    }

    private func formatTotalTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" } else { return "\(minutes) min" }
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

            Text("Du trainierst jetzt seit einem Monat!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Falls Boxing Interval Timer dir bei deinem Training hilft, freue ich mich sehr über eine kleine Unterstützung. Das hilft mir die App weiterzuentwickeln 🙏")
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

            Button("Vielleicht später") {
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                Text("🥊 Boxing Interval Timer")
                    .font(.title.bold())
                Text("Datenschutzerklärung · Februar 2026")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Kurzfassung
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    Text("Diese App speichert keine persönlichen Daten, sendet keine Daten an Server und verwendet keine Tracker oder Werbung.")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                Group {
                    PolicySection(
                        icon: "internaldrive",
                        title: "Welche Daten werden gespeichert?",
                        text: "Nur lokal auf deinem Gerät:\n• Trainingshistorie (Datum, Dauer, Sportart)\n• App-Einstellungen (Sprache, Sound, Vibration)\n\nDiese Daten verlassen dein Gerät niemals."
                    )
                    PolicySection(
                        icon: "wifi.slash",
                        title: "Werden Daten übertragen?",
                        text: "Nein. Die App sendet keine Daten an Server, verwendet keine Analyse-Tools und benötigt keine Internetverbindung."
                    )
                    PolicySection(
                        icon: "creditcard",
                        title: "In-App Käufe",
                        text: "Optionale Donations werden vollständig über Apple In-App Purchase abgewickelt. Wir haben keinen Zugriff auf Zahlungsdaten."
                    )
                    PolicySection(
                        icon: "bell",
                        title: "Berechtigungen",
                        text: "Nur Live Activity (Timer auf dem Sperrbildschirm, optional). Keine anderen Berechtigungen."
                    )
                    PolicySection(
                        icon: "envelope",
                        title: "Kontakt",
                        text: "box.timer.app@gmail.com"
                    )
                }

                Link(destination: URL(string: "https://mr-dzzs21.github.io/Boxing-Timer-App/privacy-policy.html")!) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Vollständige Version im Browser öffnen")
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
        .navigationTitle("Datenschutzerklärung")
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
                    if manager.products.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Lädt...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
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
        case "tip.coffee":   return "☕"
        case "tip.training": return "🥊"
        case "tip.champion": return "🏆"
        default:             return "💛"
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
            Form {
                Section(lang.t.audioHaptic) {
                    Toggle(lang.t.soundEnabled, isOn: $settings.soundEnabled)
                    Toggle(lang.t.vibrationEnabled, isOn: $settings.vibrationEnabled)
                    Toggle(lang.t.warningEnabled, isOn: $settings.warningEnabled)
                }

                Section {
                    Button {
                        showDonation = true
                    } label: {
                        HStack {
                            Text("🙏")
                            Text(lang.t.donationSupport)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                    }
                }

                // Sprachauswahl
                Section(lang.t.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button {
                            lang.current = language
                        } label: {
                            HStack {
                                Text(language.displayName).foregroundColor(.primary)
                                Spacer()
                                if lang.current == language {
                                    Image(systemName: "checkmark").foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                Section(lang.t.about) {
                    HStack {
                        Text(lang.t.version)
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    HStack {
                        Text(lang.t.developer)
                        Spacer()
                        Text("Diyar Kaymaz").foregroundColor(.secondary)
                    }
                    Link(destination: URL(string: "mailto:box.timer.app@gmail.com?subject=Feedback%20-%20Boxing%20Interval%20Timer")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            Text("Feedback senden")
                                .foregroundColor(.primary)
                        }
                    }
                    // ⚠️ App Store ID hier eintragen nach Veröffentlichung: z.B. "1234567890"
                    Link(destination: URL(string: "https://apps.apple.com/app/id0000000000?action=write-review")!) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("App bewerten")
                                .foregroundColor(.primary)
                        }
                    }
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Text("Datenschutzerklärung")
                    }
                }

                Section(lang.t.presetsInfo) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fight Timer Presets:").font(.headline)
                        Text("• Boxen: 12x3min")
                        Text("• MMA: 3x5min")
                        Text("• K1: 3x3min")
                        Text("• Muay Thai: 5x3min")
                        Text("• BJJ: 1x5min")
                        Text("• Judo: 1x4min")
                        Text("• Ringen: 3x2min")
                        Text("• Taekwondo: 3x2min")
                    }
                    .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle(lang.t.settingsTitle)
        }
        .sheet(isPresented: $showDonation) {
            DonationView()
        }
    }
}
