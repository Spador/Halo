import SwiftUI

/// The clipboard history card: search, click to copy, pin to keep.
struct ClipboardPageView: View {
    let history: ClipboardHistory
    let settings: SettingsStore

    @State private var searchText = ""

    private var filtered: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return history.items }
        return history.items.filter {
            $0.text.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            searchField

            if filtered.isEmpty {
                Text(history.items.isEmpty
                    ? String(localized: "Copy some text and it shows up here")
                    : String(localized: "No matches"))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 1) {
                        ForEach(filtered) { item in
                            row(item)
                        }
                    }
                }
            }

            footer
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(.white.opacity(0.1)))
    }

    private func row(_ item: ClipboardItem) -> some View {
        Button {
            history.copyToPasteboard(item)
        } label: {
            HStack(spacing: 8) {
                Text(item.preview)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 8)
                Text(item.capturedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                Button {
                    history.togglePin(item)
                } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundStyle(
                            item.isPinned
                                ? AnyShapeStyle(settings.accent.color)
                                : AnyShapeStyle(.white.opacity(0.35))
                        )
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(item.isPinned ? 0.06 : 0))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(item.isPinned ? String(localized: "Unpin") : String(localized: "Pin")) {
                history.togglePin(item)
            }
            Button("Delete", role: .destructive) {
                history.remove(item)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(history.items.count) items")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.3))
            Spacer()
            if history.items.contains(where: { !$0.isPinned }) {
                Button("Clear") {
                    history.clearUnpinned()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
