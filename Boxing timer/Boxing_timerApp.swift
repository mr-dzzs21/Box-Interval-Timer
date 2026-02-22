//
//  Boxing_timerApp.swift
//  Boxing timer
//

import SwiftUI
import CoreData

@main
struct Boxing_timerApp: App {
    @StateObject private var userSettings = UserSettings()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var todoManager = TodoManager()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(userSettings)
                .environmentObject(languageManager)
                .environmentObject(todoManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.layoutDirection, languageManager.current.layoutDirection)
                // Zwingt SwiftUI die komplette View neu zu erstellen wenn die Sprache wechselt
                // ohne .id() würde das RTL-Layout beim Zurückwechseln hängen bleiben
                .id(languageManager.current)
        }
    }
}

// MARK: - MainTabView
struct MainTabView: View {
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        TabView {
            FightTimerView()
                .tabItem { Label(lang.t.tabFightTimer, systemImage: "timer") }

            IntervalTimerView()
                .tabItem { Label(lang.t.tabIntervals, systemImage: "figure.run") }

            TodoView()
                .tabItem { Label(lang.t.tabTodos, systemImage: "checkmark.circle") }

            HistoryView()
                .tabItem { Label(lang.t.tabHistory, systemImage: "clock.arrow.circlepath") }

            StatsView()
                .tabItem { Label(lang.t.tabStats, systemImage: "chart.bar.fill") }
        }
    }
}
