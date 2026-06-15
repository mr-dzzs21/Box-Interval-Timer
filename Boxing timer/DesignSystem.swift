//
//  DesignSystem.swift
//  Boxing timer
//
//  Zentrales "Bold / Athletic" Design-System.
//  Alle Werte sind als portable Tokens gedacht, damit die Android-/Flutter-
//  Version exakt dieselbe Optik bekommt (Farben als HEX, feste Größen, klare
//  Komponenten). KEINE iOS-Semantikfarben (.primary/.secondary/system-blau).
//

import SwiftUI

// MARK: - Color aus HEX (portabel zu Android: gleiche HEX-Werte verwenden)
extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Design Tokens (Dark, Bold / Athletic)
enum DS {
    // Flächen / Basis (für Nicht-Phasen-Screens: Config, Settings, History, …)
    static let bg        = Color(hex: 0x0E0E11)   // tiefes Fast-Schwarz
    static let surface   = Color(hex: 0x1B1C20)   // Karten
    static let surfaceHi = Color(hex: 0x26272C)   // erhöhte Karte / Control

    // Phasenfarben (voll-bleed Timer-Hintergrund). HEX für Android-Parität.
    static let phaseRound = Color(hex: 0x18A957)  // grün – Runde
    static let phaseRest  = Color(hex: 0xDC3B3B)  // rot  – Pause/Rest
    static let phaseWarm  = Color(hex: 0x3A3B40)  // grau – Warm-up/Cool-down
    static let phaseDone  = Color(hex: 0x2E6BE6)  // blau – fertig

    // Akzent
    static let accent = Color(hex: 0xFF7A1A)      // energiegeladenes Orange

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary  = Color.white.opacity(0.40)
    static let divider       = Color.white.opacity(0.10)

    // Controls auf farbigem Hintergrund
    static let controlFill   = Color.black.opacity(0.22)
    static let controlStroke = Color.white.opacity(0.25)

    enum Radius {
        static let chip: CGFloat = 12
        static let card: CGFloat = 16
        static let pill: CGFloat = 16
    }

    enum Space {
        static let xs: CGFloat = 6
        static let s: CGFloat = 10
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // Schrift – iOS: SF Rounded. Android-Parität: eine runde Schrift wie
    // "Nunito" / "Baloo 2" bündeln, damit die Optik identisch ist.
    static func timer(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func display(_ size: CGFloat = 30) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func headline(_ size: CGFloat = 18) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

// MARK: - Hintergrund (Phasenfarbe + dunkler Verlauf für Tiefe)
struct AthleticBackground: View {
    let color: Color
    let phase: TimerPhase
    var body: some View {
        ZStack {
            color.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: phase)
            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.38)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Timer-Dial (Phasen-Label + Ring + große Zeit)
struct DSTimerDial: View {
    let phaseText: String
    let timeString: String
    let progress: Double
    let diameter: CGFloat

    var body: some View {
        VStack(spacing: DS.Space.m) {
            Text(phaseText)
                .font(DS.display(28))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 14)
                Circle().trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)
                Text(timeString)
                    .font(DS.timer(min(94, diameter * 0.30)))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(.white)
                    .frame(width: diameter * 0.86)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
            .frame(width: diameter, height: diameter)
        }
    }
}

// MARK: - Controls
struct DSCircleButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 62, height: 62)
                .background(DS.controlFill)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(DS.controlStroke, lineWidth: 1.5))
        }
    }
}

struct DSPlayPauseButton: View {
    let isRunning: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 38, weight: .black))
                .foregroundColor(.black)
                .frame(width: 92, height: 92)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
    }
}

// Weißer Primär-Button (Pill, schwarzer fetter UPPERCASE-Text)
struct DSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .textCase(.uppercase)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// Toolbar-/Chip-Pill (schwarz-transparent, weiße Schrift)
struct DSChip: View {
    let content: AnyView
    init<V: View>(@ViewBuilder _ content: () -> V) { self.content = AnyView(content()) }
    var body: some View {
        content
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(DS.controlFill)
            .clipShape(Capsule())
    }
}

// Dunkle Karte (für Config/Settings/History-Sektionen)
extension View {
    func dsCard() -> some View {
        self
            .padding(DS.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
    }
}
