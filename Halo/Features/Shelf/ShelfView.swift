import SwiftUI

/// The shelf card in the expanded notch: a horizontal row of held files,
/// or a drop prompt while empty.
struct ShelfView: View {
    let viewModel: ShelfViewModel
    let settings: SettingsStore
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
                            ShelfTileView(
                                item: item,
                                viewModel: viewModel,
                                settings: settings
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            if viewModel.selectedIDs.count >= 2 {
                Text("\(viewModel.selectedIDs.count) selected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                groupDragChip
                Button("Deselect") { viewModel.clearSelection() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text("\(viewModel.items.count) file\(viewModel.items.count == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Button("Clear") { viewModel.clearUnpinned() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 20)
    }

    /// Grab this chip and drag: all selected files travel as one group.
    /// The invisible overlay is the AppKit drag source.
    private var groupDragChip: some View {
        Label("Drag \(viewModel.selectedIDs.count) files", systemImage: "square.stack.3d.up.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(settings.accent.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(.white.opacity(0.12)))
            .overlay {
                GroupDragHandle(urls: viewModel.selectedURLs) {
                    viewModel.clearSelection()
                }
            }
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
    let settings: SettingsStore

    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var draftName = ""

    private var isSelected: Bool {
        viewModel.selectedIDs.contains(item.id)
    }

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
            if isRenaming {
                TextField("", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.15))
                    )
                    .onSubmit {
                        viewModel.rename(item, to: draftName)
                        isRenaming = false
                    }
                    .onExitCommand { isRenaming = false }
            } else {
                Text(item.name)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(width: 66)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.08 : isSelected ? 0.05 : 0))
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(settings.accent.color.opacity(0.8), lineWidth: 1.5)
            }
        }
        .onHover { isHovering = $0 }
        .onTapGesture { viewModel.toggleSelection(item) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button(item.isPinned ? "Unpin" : "Pin") { viewModel.togglePin(item) }
            Button("Send via AirDrop") { viewModel.airDrop(item) }
            Button("Show in Finder") { viewModel.revealInFinder(item) }
            Divider()
            if viewModel.selectedIDs.count >= 2, isSelected {
                Button("Compress \(viewModel.selectedIDs.count) Files to Zip") {
                    viewModel.compress(viewModel.selectedURLs)
                }
            } else {
                Button("Compress to Zip") { viewModel.compress([item.url]) }
            }
            if item.isImage {
                Menu("Convert Image") {
                    Button("To PNG") { viewModel.convertImage(item, to: .png) }
                    Button("To JPEG") { viewModel.convertImage(item, to: .jpeg) }
                }
            }
            Button("Rename") {
                draftName = item.name
                isRenaming = true
            }
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
