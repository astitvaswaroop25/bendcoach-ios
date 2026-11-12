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

/// A short status label on a colored capsule: level status, and rotate or turn-around cues.
struct StatusPill: View {
    let text: String
    let systemImage: String
    let fill: Color
    let foreground: Color
    var compact = false

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(compact ? .subheadline.weight(.semibold) : .headline)
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 4 : 8)
            .background(fill, in: Capsule())
    }
}

extension StatusPill {
    /// The cue to rotate or turn the conduit before a bend. Ink-on-paper inverse, so it reads
    /// as an instruction and doesn't compete with the orange marks.
    static func prepCue(_ text: String, systemImage: String, compact: Bool = false) -> StatusPill {
        StatusPill(text: text, systemImage: systemImage, fill: Theme.cueFill, foreground: Theme.onCue, compact: compact)
    }
}

extension Font {
    /// The voice for tape measurements and angles: SF Rounded, bold, with digits of equal
    /// width so numbers don't jitter as they change.
    static func measurement(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight).monospacedDigit()
    }
}

/// Bolds the parts of a bend instruction you act on: mark letters, bender marks, angles and
/// lengths. Bold rides on the text's own size, so it works at every style.
enum InstructionText {
    private static let pattern = try? NSRegularExpression(
        pattern: #"mark [A-Z]\b|\b(?:arrow|star)\b|rim notch(?: or teardrop)?|\d+(?:\.\d+)?½?°|(?:\d+' ?)?\d+(?:[- ]\d+/\d+)?"|\d+/\d+""#
    )

    static func emphasized(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        guard let pattern else { return result }
        let whole = NSRange(text.startIndex..., in: text)
        for match in pattern.matches(in: text, range: whole) {
            guard let range = Range(match.range, in: text),
                  let styled = Range(range, in: result) else { continue }
            result[styled].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}

/// A choice between a few options. Segmented (or a menu row) at normal text sizes. At
/// accessibility sizes the title sits on its own line with the value under it, so neither
/// gets cut off.
struct ChoicePicker<Value: Hashable>: View {
    enum Style {
        case segmented
        case menu
    }

    let title: String
    let options: [Value]
    let label: (Value) -> String
    @Binding var selection: Value
    var showsTitle = true
    var style: Style = .segmented

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                if showsTitle {
                    Text(title)
                }
                Menu {
                    picker
                        .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 6) {
                        Text(label(selection))
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                    }
                    .frame(minHeight: 44)
                }
                .accessibilityLabel(title)
                .accessibilityValue(label(selection))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        } else if style == .menu {
            picker
                .pickerStyle(.menu)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if showsTitle {
                    Text(title)
                }
                picker
                    .pickerStyle(.segmented)
            }
            .padding(.vertical, 4)
        }
    }

    private var picker: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
    }
}

/// Lays a row out side by side at normal text sizes and stacks it at accessibility sizes,
/// so long titles get the full width.
struct AdaptiveRowLayout {
    static func layout(for typeSize: DynamicTypeSize, spacing: CGFloat = 14) -> AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: spacing))
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
