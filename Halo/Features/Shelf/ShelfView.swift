import SwiftUI

/// The shelf card in the expanded notch: a horizontal row of held files,
/// or a drop prompt while empty.
struct ShelfView: View {
    let viewModel: ShelfViewModel
    let isDropTargeted: Bool

    var body: some View {
        if viewModel.items.isEmpty {
            dropPrompt
        } else {
            VStack(spacing: 4) {
                header
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.items) { item in
                            ShelfTileView(item: item, viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(viewModel.items.count) file\(viewModel.items.count == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Button("Clear") { viewModel.clearUnpinned() }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
    }

    private var dropPrompt: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(.white.opacity(isDropTargeted ? 0.9 : 0.35))
            .overlay {
                VStack(spacing: 5) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 20, weight: .light))
                    Text("Drop files here")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white.opacity(isDropTargeted ? 0.9 : 0.5))
            }
            .frame(height: 96)
            .padding(.horizontal, 22)
    }
}

/// One file on the shelf. Drag it out into any app; right-click for
/// pin/AirDrop/remove; hover for a quick AirDrop button.
struct ShelfTileView: View {
    let item: ShelfItem
    let viewModel: ShelfViewModel

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 42)
                .overlay { if isHovering { quickAirDropButton } }
                .overlay(alignment: .topTrailing) {
                    if item.isPinned {
                        Image(systemName: "pin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white, .black.opacity(0.6))
                            .offset(x: 4, y: -4)
                    }
                }
            Text(item.name)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(width: 66)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.08 : 0))
        )
        .onHover { isHovering = $0 }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") { viewModel.togglePin(item) }
            Button("Send via AirDrop") { viewModel.airDrop(item) }
            Button("Show in Finder") { viewModel.revealInFinder(item) }
            Divider()
            Button("Remove from Shelf") { viewModel.remove(item) }
        }
    }

    private var quickAirDropButton: some View {
        Button {
            viewModel.airDrop(item)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(0.55))
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .help("Send via AirDrop")
    }
}
