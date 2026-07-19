import SwiftUI

/// The visible notch shape: a black island pinned to the top-center of the
/// screen that springs between the exact notch size and the expanded panel.
struct NotchShellView: View {
    let viewModel: NotchViewModel
    let settings: SettingsStore
    let nowPlaying: NowPlayingViewModel
    let shelf: ShelfViewModel
    let controls: ControlsViewModel
    let clipboard: ClipboardHistory
    let meetings: MeetingCountdown
    let colorPicker: ColorPickerStore
    let worldClock: WorldClockStore
    let mirror: CameraMirror
    let todos: RemindersService
    let weather: WeatherService
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
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.liveActivities)
    }

    /// The island has three sizes: the exact notch (idle), notch plus slim
    /// wings (HUD flash or live activity), and the full panel (hovered).
    private var shapeSize: CGSize {
        if viewModel.isExpanded { return NotchViewModel.expandedSize }
        if viewModel.hud != nil || !viewModel.liveActivities.isEmpty {
            return CGSize(
                width: viewModel.notchSize.width + 2 * NotchViewModel.hudWingWidth,
                height: viewModel.notchSize.height + NotchViewModel.hudExtraHeight
            )
        }
        return viewModel.notchSize
    }

    /// Collapsed stays pure black to blend into the physical notch; the
    /// expanded panel picks up the theme's accent wash at the bottom.
    private var shapeFill: AnyShapeStyle {
        guard viewModel.isExpanded else { return AnyShapeStyle(Color.black) }
        return AnyShapeStyle(
            LinearGradient(
                colors: Theme.panelColors(
                    accent: settings.accent,
                    tintStrength: settings.tintStrength,
                    opacity: settings.panelOpacity
                ),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var notchShape: some View {
        let expanded = viewModel.isExpanded
        let showingHUD = !expanded && (viewModel.hud != nil || !viewModel.liveActivities.isEmpty)
        let size = shapeSize
        let radii = RectangleCornerRadii(
            topLeading: expanded ? 12 : showingHUD ? 8 : 0,
            bottomLeading: expanded ? 24 : showingHUD ? 14 : 9,
            bottomTrailing: expanded ? 24 : showingHUD ? 14 : 9,
            topTrailing: expanded ? 12 : showingHUD ? 8 : 0
        )

        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
        .fill(shapeFill)
        .frame(width: size.width, height: size.height)
        .overlay {
            // The media card sits on a heavily blurred, darkened copy of
            // the album artwork instead of the plain panel.
            if expanded, activeCard == .nowPlaying,
               let artwork = nowPlaying.info?.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .blur(radius: 45)
                    .overlay(Color.black.opacity(0.55))
                    .clipShape(UnevenRoundedRectangle(cornerRadii: radii, style: .continuous))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            // A HUD flash takes the wings; the live activity holds them
            // otherwise and returns when the flash fades.
            if !expanded {
                if let hud = viewModel.hud {
                    HUDView(state: hud, notchSize: viewModel.notchSize)
                        .transition(.opacity)
                } else if !viewModel.liveActivities.isEmpty {
                    LiveActivityView(
                        items: viewModel.liveActivities,
                        notchSize: viewModel.notchSize,
                        accent: settings.accent.color
                    )
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
        .overlay(alignment: .topLeading) { cardSwitcher(leadingCards, edge: .leading) }
        .overlay(alignment: .topTrailing) { cardSwitcher(trailingCards, edge: .trailing) }
    }

    private func enabled(_ feature: FeatureID) -> Bool {
        settings.isEnabled(feature)
    }

    /// Which card the open notch shows. A hovering file drag always forces
    /// the shelf; an explicit switcher choice is honored while that card
    /// still has content; otherwise: shelf if it holds files, then media,
    /// then stats — the usual default. Disabled features are skipped
    /// everywhere; nil means every card is switched off.
    private var activeCard: NotchCard? {
        if viewModel.isDropTargeted, enabled(.shelf) { return .shelf }
        if let selected = viewModel.selectedCard, enabled(selected.feature) {
            switch selected {
            // Content-dependent cards fall through when empty.
            case .shelf: if shelf.hasItems { return .shelf }
            case .nowPlaying: if nowPlaying.info != nil { return .nowPlaying }
            // Always-available pages honor the choice unconditionally.
            case .controls, .clipboard, .colorPicker, .mirror, .calendar,
                .worldClock, .todos, .weather, .timer, .pomodoro, .stats:
                return selected
            }
        }
        if enabled(.shelf), shelf.hasItems { return .shelf }
        if enabled(.nowPlaying), nowPlaying.info != nil { return .nowPlaying }
        if enabled(.timer), quickTimer.countdown != nil { return .timer }
        if enabled(.pomodoro), pomodoro.session != nil { return .pomodoro }
        if enabled(.stats) { return .stats }
        // Stats is off too: fall back to any page that is still on.
        return [NotchCard.controls, .clipboard, .calendar, .timer, .pomodoro]
            .first { enabled($0.feature) }
    }

    /// The switcher lives on both edges because the strip between them is
    /// hidden behind the physical notch: content cards (media, shelf,
    /// sliders, clipboard) gather on the left edge, the four fixed pages
    /// keep the right. Each side holds at most four icons, so none can
    /// slide under the housing.
    private var leadingCards: [(card: NotchCard, symbol: String)] {
        var cards: [(NotchCard, String)] = []
        if enabled(.nowPlaying), nowPlaying.info != nil {
            cards.append((.nowPlaying, "music.note"))
        }
        if enabled(.shelf), shelf.hasItems {
            cards.append((.shelf, "tray.fill"))
        }
        if enabled(.controls) { cards.append((.controls, "slider.horizontal.3")) }
        if enabled(.clipboard) { cards.append((.clipboard, "doc.on.clipboard")) }
        if enabled(.colorPicker) { cards.append((.colorPicker, "eyedropper")) }
        if enabled(.mirror) { cards.append((.mirror, "web.camera")) }
        return cards
    }

    private var trailingCards: [(card: NotchCard, symbol: String)] {
        var cards: [(NotchCard, String)] = []
        if enabled(.calendar) { cards.append((.calendar, "calendar")) }
        if enabled(.worldClock) { cards.append((.worldClock, "globe")) }
        if enabled(.todos) { cards.append((.todos, "checklist")) }
        if enabled(.weather) { cards.append((.weather, "cloud.sun.fill")) }
        if enabled(.timer) { cards.append((.timer, "timer")) }
        if enabled(.pomodoro) { cards.append((.pomodoro, "brain.head.profile")) }
        if enabled(.stats) { cards.append((.stats, "chart.bar.fill")) }
        return cards
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch activeCard {
        case .shelf:
            ShelfView(
                viewModel: shelf,
                settings: settings,
                isDropTargeted: viewModel.isDropTargeted
            )
        case .controls:
            ControlsPageView(viewModel: controls, settings: settings)
        case .clipboard:
            ClipboardPageView(history: clipboard, settings: settings)
        case .colorPicker:
            ColorPickerPageView(store: colorPicker, settings: settings)
        case .mirror:
            MirrorPageView(mirror: mirror, settings: settings)
        case .nowPlaying:
            if let info = nowPlaying.info {
                NowPlayingView(viewModel: nowPlaying, info: info, settings: settings)
            }
        case .calendar:
            CalendarPageView(calendar: calendar, meetings: meetings)
        case .worldClock:
            WorldClockPageView(store: worldClock, settings: settings)
        case .todos:
            TodoPageView(todos: todos, settings: settings)
        case .weather:
            WeatherPageView(weather: weather, settings: settings)
        case .timer:
            TimerPageView(engine: quickTimer)
        case .pomodoro:
            PomodoroPageView(engine: pomodoro, settings: settings)
        case .stats:
            StatsView(viewModel: stats)
        case nil:
            Text("Everything is switched off in Settings")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// One edge's half of the switcher, shown only when there is more than
    /// one card overall to switch between.
    @ViewBuilder
    private func cardSwitcher(
        _ cards: [(card: NotchCard, symbol: String)],
        edge: HorizontalEdge
    ) -> some View {
        if viewModel.isExpanded,
           leadingCards.count + trailingCards.count > 1,
           !cards.isEmpty {
            HStack(spacing: 3) {
                ForEach(cards, id: \.card) { entry in
                    cardButton(entry.card, symbol: entry.symbol)
                }
            }
            .padding(.top, 7)
            .padding(edge == .leading ? .leading : .trailing, 14)
            .transition(.opacity)
        }
    }

    private func cardButton(_ card: NotchCard, symbol: String) -> some View {
        Button {
            viewModel.selectedCard = card
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(
                    activeCard == card
                        ? settings.accent.color
                        : Color.white.opacity(0.4)
                )
                .frame(width: 19, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}
