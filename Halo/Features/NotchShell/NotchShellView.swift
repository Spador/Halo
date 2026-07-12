import SwiftUI

/// The visible notch shape: a black island pinned to the top-center of the
/// screen that springs between the exact notch size and the expanded panel.
struct NotchShellView: View {
    let viewModel: NotchViewModel
    let nowPlaying: NowPlayingViewModel

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
    }

    /// Chooses what fills the open notch: the media card when something is
    /// playing, otherwise the idle placeholder. Later phases add more cards.
    @ViewBuilder
    private var expandedContent: some View {
        if let info = nowPlaying.info {
            NowPlayingView(viewModel: nowPlaying, info: info)
        } else {
            placeholder
        }
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
