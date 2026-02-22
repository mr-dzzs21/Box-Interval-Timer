//
//  BoxingTimerAttributes.swift
//  Boxing timer
//
//  Definiert welche Daten die Live Activity anzeigt.
//  Diese Datei muss zu BEIDEN Targets gehören:
//  - "Boxing timer" (Haupt-App)
//  - "BoxingTimerWidget" (Widget Extension)
//

import ActivityKit
import Foundation

struct BoxingTimerAttributes: ActivityAttributes {

    // MARK: - Statische Daten (ändern sich NICHT während der Live Activity)
    var sportName: String   // z.B. "🥊 Boxen"

    // MARK: - Dynamische Daten (ändern sich während der Live Activity)
    public struct ContentState: Codable, Hashable {
        var phase: String           // z.B. "Runde 2/3", "Pause", "Aufwärmen"
        var phaseEndDate: Date      // Wann die aktuelle Phase endet → iOS zählt automatisch runter
        var displayTime: String     // z.B. "01:45" → wird nur bei Pause angezeigt
        var isRunning: Bool         // true = läuft, false = pausiert
        var colorName: String       // "green", "red", "gray", "blue"
        var currentRound: Int       // Aktuelle Runde
        var totalRounds: Int        // Gesamte Runden
    }
}
