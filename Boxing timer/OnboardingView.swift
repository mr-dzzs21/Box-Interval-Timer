//
//  OnboardingView.swift
//  Boxing timer
//
//  Wird beim ersten App-Start angezeigt.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var lang: LanguageManager
    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private var pages: [(icon: String, color: Color, title: String, text: String)] {[
        ("🥊",    .orange, lang.t.onboarding1Title, lang.t.onboarding1Text),
        ("⏱",     .green,  lang.t.onboarding2Title, lang.t.onboarding2Text),
        ("🏃",    .blue,   lang.t.onboarding3Title, lang.t.onboarding3Text),
        ("📊",    .purple, lang.t.onboarding4Title, lang.t.onboarding4Text),
    ]}

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // Skip Button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button(lang.t.onboardingSkip) {
                            finish()
                        }
                        .foregroundColor(.gray)
                        .padding()
                    }
                }

                // Seiten
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        OnboardingPage(
                            icon: pages[i].icon,
                            color: pages[i].color,
                            title: pages[i].title,
                            text: pages[i].text
                        )
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                // Punkte-Indikatoren
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? pages[currentPage].color : Color.gray.opacity(0.4))
                            .frame(width: i == currentPage ? 10 : 7, height: i == currentPage ? 10 : 7)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Weiter / Los geht's Button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? lang.t.onboardingNext : lang.t.onboardingStart)
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pages[currentPage].color)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        isPresented = false
    }
}

// MARK: - Einzelne Seite
struct OnboardingPage: View {
    let icon: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(icon)
                .font(.system(size: 90))
                .padding(30)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(text)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()
            Spacer()
        }
    }
}
