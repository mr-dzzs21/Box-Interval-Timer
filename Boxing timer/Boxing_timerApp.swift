//
//  Boxing_timerApp.swift
//  Boxing timer
//

import SwiftUI
import CoreData
import StoreKit

@main
struct Boxing_timerApp: App {
    @StateObject private var userSettings = UserSettings()
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var todoManager = TodoManager()
    @StateObject private var promptManager = AppPromptManager()
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "onboardingCompleted")
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(userSettings)
                .environmentObject(languageManager)
                .environmentObject(todoManager)
                .environmentObject(promptManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.layoutDirection, languageManager.current.layoutDirection)
                .id(languageManager.current)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                        .environmentObject(languageManager)
                }
        }
    }
}

// MARK: - MainTabView
struct MainTabView: View {
    @EnvironmentObject var lang: LanguageManager
    @EnvironmentObject var promptManager: AppPromptManager
    @Environment(\.requestReview) private var requestReview

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
        .onAppear {
            promptManager.checkDonationPrompt()
        }
        .sheet(isPresented: $promptManager.showDonationPrompt) {
            DonationPromptView()
        }
        .onChange(of: promptManager.completedWorkoutsCount) { _, _ in
            if promptManager.shouldRequestReview() {
                requestReview()
            }
        }
    }
}
