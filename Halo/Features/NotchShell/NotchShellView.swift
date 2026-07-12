import SwiftUI

/// The visible notch shape: a black island pinned to the top-center of the
/// screen that springs between the exact notch size and the expanded panel.
struct NotchShellView: View {
    let viewModel: NotchViewModel
    let nowPlaying: NowPlayingViewModel
    let shelf: ShelfViewModel
    let stats: StatsViewModel
    let calendar: CalendarService
    let quickTimer: QuickTimerEngine
    let pomodoro: PomodoroEngine

    var body: some View {
        ZStack(alignment: .top) {
            notchShape
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: viewModel.isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.hud)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.liveActivity)
    }

    /// The island has three sizes: the exact notch (idle), notch plus slim
    /// wings (HUD flash or live activity), and the full panel (hovered).
    private var shapeSize: CGSize {
        if viewModel.isExpanded { return NotchViewModel.expandedSize }
        if viewModel.hud != nil || viewModel.liveActivity != nil {
            return CGSize(
                width: viewModel.notchSize.width + 2 * NotchViewModel.hudWingWidth,
                height: viewModel.notchSize.height + NotchViewModel.hudExtraHeight
            )
        }
        return viewModel.notchSize
    }

    private var notchShape: some View {
        let expanded = viewModel.isExpanded
        let showingHUD = !expanded && (viewModel.hud != nil || viewModel.liveActivity != nil)
        let size = shapeSize

        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: expanded ? 12 : showingHUD ? 8 : 0,
                bottomLeading: expanded ? 24 : showingHUD ? 14 : 9,
                bottomTrailing: expanded ? 24 : showingHUD ? 14 : 9,
                topTrailing: expanded ? 12 : showingHUD ? 8 : 0
            ),
            style: .continuous
        )
        .fill(.black)
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .top) {
            // A HUD flash takes the wings; the live activity holds them
            // otherwise and returns when the flash fades.
            if !expanded {
                if let hud = viewModel.hud {
                    HUDView(state: hud, notchSize: viewModel.notchSize)
                        .transition(.opacity)
                } else if let activity = viewModel.liveActivity {
                    LiveActivityView(activity: activity, notchSize: viewModel.notchSize)
                        .transition(.opacity)
                }
            }
        }
        .overlay(alignment: .top) {
            if expanded {
                VStack(spacing: 0) { expandedContent }
                    .frame(
                        width: size.width,
                        height: size.height - viewModel.notchSize.height - 10
                    )
                    // Keep content out of the strip hidden by the physical
                    // notch — pixels behind the camera housing don't exist.
                    .padding(.top, viewModel.notchSize.height)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) { cardSwitcher }
    }

    /// Which card the open notch shows. A hovering file drag always forces
    /// the shelf; an explicit switcher choice is honored while that card
    /// still has content; otherwise: shelf if it holds files, then media,
    /// then stats — the always-available default.
    private var activeCard: NotchCard {
        if viewModel.isDropTargeted { return .shelf }
        if let selected = viewModel.selectedCard {
            switch selected {
            // Content-dependent cards fall through when empty.
            case .shelf: if shelf.hasItems { return .shelf }
            case .nowPlaying: if nowPlaying.info != nil { return .nowPlaying }
            // Always-available pages honor the choice unconditionally.
            case .calendar, .timer, .pomodoro, .stats: return selected
            }
        }
        if shelf.hasItems { return .shelf }
        if nowPlaying.info != nil { return .nowPlaying }
        if quickTimer.countdown != nil { return .timer }
        if pomodoro.session != nil { return .pomodoro }
        return .stats
    }

    /// Cards worth offering in the switcher (the four pages always are).
    private var availableCards: [(card: NotchCard, symbol: String)] {
        var cards: [(NotchCard, String)] = []
        if nowPlaying.info != nil { cards.append((.nowPlaying, "music.note")) }
        if shelf.hasItems { cards.append((.shelf, "tray.fill")) }
        cards.append((.calendar, "calendar"))
        cards.append((.timer, "timer"))
        cards.append((.pomodoro, "brain.head.profile"))
        cards.append((.stats, "chart.bar.fill"))
        return cards
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch activeCard {
        case .shelf:
            ShelfView(viewModel: shelf, isDropTargeted: viewModel.isDropTargeted)
        case .nowPlaying:
            if let info = nowPlaying.info {
                NowPlayingView(viewModel: nowPlaying, info: info)
            }
        case .calendar:
            CalendarPageView(calendar: calendar)
        case .timer:
            TimerPageView(engine: quickTimer)
        case .pomodoro:
            PomodoroPageView(engine: pomodoro)
        case .stats:
            StatsView(viewModel: stats)
        }
    }

    /// Tiny switcher in the top-right strip beside the notch, shown only
    /// when there's more than one card to switch between.
    @ViewBuilder
    private var cardSwitcher: some View {
        if viewModel.isExpanded, availableCards.count > 1 {
            HStack(spacing: 5) {
                ForEach(availableCards, id: \.card) { entry in
                    cardButton(entry.card, symbol: entry.symbol)
                }
            }
            .padding(.top, 7)
            .padding(.trailing, 14)
            .transition(.opacity)
        }
    }

    private func cardButton(_ card: NotchCard, symbol: String) -> some View {
        Button {
            viewModel.selectedCard = card
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(activeCard == card ? 0.95 : 0.4))
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}
