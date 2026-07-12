import SwiftUI

/// The visible notch shape: a black island pinned to the top-center of the
/// screen that springs between the exact notch size and the expanded panel.
struct NotchShellView: View {
    let viewModel: NotchViewModel
    let nowPlaying: NowPlayingViewModel
    let shelf: ShelfViewModel

    var body: some View {
        ZStack(alignment: .top) {
            notchShape
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: viewModel.isExpanded)
    }

    private var notchShape: some View {
        let expanded = viewModel.isExpanded
        let size = expanded ? NotchViewModel.expandedSize : viewModel.notchSize

        return UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: expanded ? 12 : 0,
                bottomLeading: expanded ? 24 : 9,
                bottomTrailing: expanded ? 24 : 9,
                topTrailing: expanded ? 12 : 0
            ),
            style: .continuous
        )
        .fill(.black)
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .top) {
            if expanded {
                expandedContent
                    // Keep content out of the strip hidden by the physical
                    // notch — pixels behind the camera housing don't exist.
                    .padding(.top, viewModel.notchSize.height + 8)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) { cardSwitcher }
    }

    /// Which card the open notch shows. A hovering file drag always forces
    /// the shelf; an explicit switcher choice is honored while that card
    /// still has content; otherwise: shelf if it holds files, then media,
    /// then the idle placeholder.
    private var activeCard: NotchCard? {
        if viewModel.isDropTargeted { return .shelf }
        switch viewModel.selectedCard {
        case .shelf where shelf.hasItems: return .shelf
        case .nowPlaying where nowPlaying.info != nil: return .nowPlaying
        default: break
        }
        if shelf.hasItems { return .shelf }
        if nowPlaying.info != nil { return .nowPlaying }
        return nil
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
        case nil:
            placeholder
        }
    }

    /// Tiny switcher in the top-right strip beside the notch, shown only
    /// when both cards have content to switch between.
    @ViewBuilder
    private var cardSwitcher: some View {
        if viewModel.isExpanded, shelf.hasItems, nowPlaying.info != nil {
            HStack(spacing: 5) {
                cardButton(.nowPlaying, symbol: "music.note")
                cardButton(.shelf, symbol: "tray.fill")
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

    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "circle.dashed")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.9))
            Text("Halo")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Text("Expanded and ready — widgets arrive in later phases.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
        }
    }
}
