//
//  UserSettings.swift
//  Boxing timer
//
//  Created by Diyar on 27.01.26.
//

import Foundation
import SwiftUI
import Combine

class UserSettings: ObservableObject {
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }
    
    @Published var vibrationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(vibrationEnabled, forKey: "vibrationEnabled")
        }
    }

    @Published var warningEnabled: Bool {
        didSet {
            UserDefaults.standard.set(warningEnabled, forKey: "warningEnabled")
        }
    }

    init() {
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        self.vibrationEnabled = UserDefaults.standard.bool(forKey: "vibrationEnabled")
        self.warningEnabled = UserDefaults.standard.bool(forKey: "warningEnabled")

        if !UserDefaults.standard.bool(forKey: "soundEnabledSet") {
            self.soundEnabled = true
            UserDefaults.standard.set(true, forKey: "soundEnabled")
            UserDefaults.standard.set(true, forKey: "soundEnabledSet")
        }

        if !UserDefaults.standard.bool(forKey: "vibrationEnabledSet") {
            self.vibrationEnabled = true
            UserDefaults.standard.set(true, forKey: "vibrationEnabled")
            UserDefaults.standard.set(true, forKey: "vibrationEnabledSet")
        }

        if !UserDefaults.standard.bool(forKey: "warningEnabledSet") {
            self.warningEnabled = true
            UserDefaults.standard.set(true, forKey: "warningEnabled")
            UserDefaults.standard.set(true, forKey: "warningEnabledSet")
        }
    }
}
