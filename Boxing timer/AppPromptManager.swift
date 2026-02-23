//
//  AppPromptManager.swift
//  Boxing timer
//
//  Verwaltet wann Review-Anfrage und Donation-Popup erscheinen.
//

import Foundation
import SwiftUI
import Combine

class AppPromptManager: ObservableObject {

    @Published var showDonationPrompt = false

    private let firstLaunchKey       = "firstLaunchDate"
    private let donationShownKey     = "donationPromptShown"
    private let workoutCountKey      = "completedWorkoutsCount"

    init() {
        // Ersten Start-Datum speichern
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        }
    }

    // Wird aufgerufen wenn ein Workout gespeichert wird
    func recordWorkoutCompleted() {
        let count = UserDefaults.standard.integer(forKey: workoutCountKey) + 1
        UserDefaults.standard.set(count, forKey: workoutCountKey)
    }

    // Gibt aktuelle Workout-Anzahl zurück (für Review-Trigger)
    var completedWorkoutsCount: Int {
        UserDefaults.standard.integer(forKey: workoutCountKey)
    }

    // Nach 30 Tagen Donation-Popup zeigen (nur einmal)
    func checkDonationPrompt() {
        guard !UserDefaults.standard.bool(forKey: donationShownKey) else { return }
        guard let firstLaunch = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date else { return }

        let days = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        if days >= 30 {
            showDonationPrompt = true
            UserDefaults.standard.set(true, forKey: donationShownKey)
        }
    }

    // Review anfragen nach 5, 15 oder 30 Workouts
    func shouldRequestReview() -> Bool {
        let count = completedWorkoutsCount
        return count == 5 || count == 15 || count == 30
    }
}
