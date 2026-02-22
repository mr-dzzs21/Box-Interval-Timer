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
    
    init() {
        self.soundEnabled = UserDefaults.standard.bool(forKey: "soundEnabled")
        self.vibrationEnabled = UserDefaults.standard.bool(forKey: "vibrationEnabled")
        
        // Default to true if not set
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
    }
}
