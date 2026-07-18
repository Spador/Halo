import SwiftUI

/// One page of the welcome tour. New features add themselves to `pages`
/// and the tour picks them up — no view changes needed.
struct OnboardingPage: Identifiable {
    let icon: String
    let title: String
    let body: String

    var id: String { icon }

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "circle.dashed",
            title: String(localized: "Welcome to Halo"),
            body: String(localized: "Your notch is now a hub for media, files, timers, and more. This short tour shows you around.")
        ),
        OnboardingPage(
            icon: "cursorarrow.rays",
            title: String(localized: "Open the notch"),
            body: String(localized: "Move the pointer onto the notch and the panel opens. Prefer a click, a delay, or a keyboard shortcut? All of that lives in Settings.")
        ),
        OnboardingPage(
            icon: "tray.and.arrow.down.fill",
            title: String(localized: "The file shelf"),
            body: String(localized: "Drag files onto the notch to keep them handy. Drag them back out anywhere, send them over AirDrop, or pin the ones you use often.")
        ),
        OnboardingPage(
            icon: "speaker.wave.2.fill",
            title: String(localized: "Your volume and brightness"),
            body: String(localized: "Halo replaces the system pop ups with its own HUD in the notch. This needs the Accessibility permission. macOS asks once, and your keys keep working normally until you grant it.")
        ),
        OnboardingPage(
            icon: "timer",
            title: String(localized: "Timers and calendar"),
            body: String(localized: "Quick timers, Pomodoro focus rounds, and your month at a glance. Running timers stay visible in the collapsed notch.")
        ),
        OnboardingPage(
            icon: "gearshape.fill",
            title: String(localized: "Make it yours"),
            body: String(localized: "Every feature can be switched off, recolored, or given a global shortcut. Open Settings any time from the Halo icon in the menu bar.")
        ),
    ]
}

/// The welcome tour shown on first launch (and replayable from Settings).
struct OnboardingView: View {
    let settings: SettingsStore
    let onFinished: () -> Void

    @State private var pageIndex = 0
    private let pages = OnboardingPage.pages

    private var page: OnboardingPage { pages[pageIndex] }
    private var isLastPage: Bool { pageIndex == pages.count - 1 }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 8)

            Image(systemName: page.icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(settings.accent.color)
                .frame(height: 60)

            Text(page.title)
                .font(.title2.bold())

            Text(page.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 350)
                .frame(minHeight: 70, alignment: .top)

            Spacer()

            pageDots

            HStack {
                Button("Skip") { onFinished() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                if pageIndex > 0 {
                    Button("Back") { pageIndex -= 1 }
                }
                Button(isLastPage ? String(localized: "Get Started") : String(localized: "Continue")) {
                    if isLastPage {
                        onFinished()
                    } else {
                        pageIndex += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 470, height: 330)
        .animation(.easeInOut(duration: 0.18), value: pageIndex)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(
                        index == pageIndex
                            ? AnyShapeStyle(settings.accent.color)
                            : AnyShapeStyle(.quaternary)
                    )
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.bottom, 4)
    }
}
