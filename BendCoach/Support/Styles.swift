import SwiftUI

/// The primary action style: high-visibility orange with black text, like job-site safety gear.
/// Black on this orange reads at roughly 8:1 in both light and dark mode.
struct HighVisButtonStyle: ButtonStyle {
    var fullWidth = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.onHighVis)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 50)
            .background(Theme.highVis.opacity(isEnabled ? 1 : 0.4),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension ButtonStyle where Self == HighVisButtonStyle {
    static var highVis: HighVisButtonStyle { HighVisButtonStyle() }
    static var highVisFullWidth: HighVisButtonStyle { HighVisButtonStyle(fullWidth: true) }
}

/// A short status label on a colored capsule, used by the level.
struct StatusPill: View {
    let text: String
    let systemImage: String
    let fill: Color
    let foreground: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(fill, in: Capsule())
    }
}

/// Segmented control at normal text sizes; a menu picker at accessibility sizes,
/// where segment labels would otherwise be cut off.
struct ChoicePicker<Value: Hashable>: View {
    let title: String
    let options: [Value]
    let label: (Value) -> String
    @Binding var selection: Value
    var showsTitle = true

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if showsTitle {
                    Text(title)
                }
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(label(option)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
        }
    }
}

/// Row colors that stay readable when a sidebar row is selected on iPad. Sidebars take the
/// high-vis tint, so a selected row sits on safety orange and its text turns black.
struct RowColors {
    let prominence: BackgroundProminence

    private var onFill: Bool { prominence == .increased }
    var title: Color { onFill ? Theme.onHighVis : .primary }
    var detail: Color { onFill ? Theme.onHighVis.opacity(0.75) : .secondary }
    var icon: Color { onFill ? Theme.onHighVis : .accentColor }
}

extension View {
    /// Selected rows in an iPad sidebar fill with high-vis orange (rows use `RowColors`).
    func highVisSelection() -> some View {
        tint(Theme.highVis)
    }
}
