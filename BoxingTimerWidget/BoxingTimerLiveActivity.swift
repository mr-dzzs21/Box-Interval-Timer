//
//  BoxingTimerLiveActivity.swift
//  BoxingTimerWidget
//
//  Das ist die UI der Live Activity:
//  - Sperrbildschirm (großes Layout)
//  - Dynamic Island (kompakt + erweitert)
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget
struct BoxingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BoxingTimerAttributes.self) { context in

            // ── Sperrbildschirm / Notification Banner ──
            LockScreenView(context: context)

        } dynamicIsland: { context in

            // ── Dynamic Island ──
            DynamicIsland {

                // Erweitert (wenn man drückt)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.sportName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(context.state.phase)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isRunning {
                        Text(timerInterval: context.state.phaseEndDate...context.state.phaseEndDate,
                             countsDown: true)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .padding(.trailing, 4)
                    } else {
                        Text(context.state.displayTime)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .padding(.trailing, 4)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    // Runden-Indikatoren
                    if context.state.totalRounds > 0 {
                        HStack(spacing: 6) {
                            Text("Runde")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ForEach(1...max(1, context.state.totalRounds), id: \.self) { round in
                                Circle()
                                    .fill(round <= context.state.currentRound
                                          ? Color.white
                                          : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }

            } compactLeading: {
                // Kleines Icon links
                Text("🥊")
                    .font(.system(size: 14))

            } compactTrailing: {
                // Timer rechts (kompakt)
                if context.state.isRunning {
                    Text(timerInterval: Date.now...context.state.phaseEndDate,
                         countsDown: true)
                        .font(.system(.caption, design: .rounded).bold())
                        .monospacedDigit()
                        .frame(maxWidth: 50)
                } else {
                    Text(context.state.displayTime)
                        .font(.system(.caption, design: .rounded).bold())
                        .monospacedDigit()
                }

            } minimal: {
                // Minimales Icon (wenn 2 Activities aktiv)
                Text("🥊")
            }
            .keylineTint(phaseColor(context.state.colorName))
        }
    }

    private func phaseColor(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "red":   return .red
        case "blue":  return .blue
        default:      return .gray
        }
    }
}

// MARK: - Sperrbildschirm UI
struct LockScreenView: View {
    let context: ActivityViewContext<BoxingTimerAttributes>

    var phaseColor: Color {
        switch context.state.colorName {
        case "green": return .green
        case "red":   return .red
        case "blue":  return .blue
        default:      return .gray
        }
    }

    var body: some View {
        VStack(spacing: 12) {

            // Kopfzeile: Sport + Status
            HStack {
                Text(context.attributes.sportName)
                    .font(.headline)
                    .bold()
                Spacer()
                Image(systemName: context.state.isRunning ? "play.fill" : "pause.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Phase
            Text(context.state.phase)
                .font(.title3.bold())
                .foregroundColor(phaseColor)

            // Timer - zählt automatisch runter wenn running
            if context.state.isRunning {
                Text(timerInterval: Date.now...context.state.phaseEndDate,
                     countsDown: true)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Text(context.state.displayTime)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            // Runden-Punkte
            if context.state.totalRounds > 1 {
                HStack(spacing: 6) {
                    ForEach(1...context.state.totalRounds, id: \.self) { round in
                        Circle()
                            .fill(round <= context.state.currentRound
                                  ? phaseColor
                                  : phaseColor.opacity(0.25))
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(phaseColor.opacity(0.15))
        .activitySystemActionForegroundColor(.primary)
    }
}
