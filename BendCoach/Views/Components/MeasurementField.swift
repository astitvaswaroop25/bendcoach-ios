import SwiftUI
import UIKit
import BendKit

/// A row that shows a tape measurement and opens the fraction keypad when tapped.
struct MeasurementField: View {
    let title: String
    var hint: String? = nil
    @Binding var value: Double?

    @Environment(\.lengthFormat) private var format
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingKeypad = false

    var body: some View {
        Button {
            showingKeypad = true
        } label: {
            layout
                .padding(.vertical, 4)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value.map { format.string($0) } ?? "Not set")
        .accessibilityHint("Opens a keypad")
        .sheet(isPresented: $showingKeypad) {
            FractionKeypad(title: title, initialValue: value, denominator: format.denominator) { newValue in
                value = newValue
            }
            .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var layout: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                titleBlock
                valueText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .center, spacing: 12) {
                titleBlock
                Spacer(minLength: 8)
                valueText
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(Color.primary)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }

    private var valueText: some View {
        Text(value.map { format.string($0) } ?? "Enter")
            .font(.title3.monospacedDigit().weight(.semibold))
            .foregroundStyle(value == nil ? Color.accentColor : Color.primary)
    }
}

/// Big-button keypad for feet, inches and tape fractions.
struct FractionKeypad: View {
    struct FractionKey: Hashable {
        let numerator: Int
        let denominator: Int
        var label: String { "\(numerator)/\(denominator)" }
    }

    let title: String
    let onDone: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var displaySize: CGFloat = 46
    @State private var entry: MeasurementEntry
    @State private var showSixteenths: Bool

    private let eighths = [(1, 8), (1, 4), (3, 8), (1, 2), (5, 8), (3, 4), (7, 8)].map { FractionKey(numerator: $0.0, denominator: $0.1) }
    private let sixteenths = [1, 3, 5, 7, 9, 11, 13, 15].map { FractionKey(numerator: $0, denominator: 16) }
    private let fractionColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let digitColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    init(title: String, initialValue: Double?, denominator: Int, onDone: @escaping (Double?) -> Void) {
        self.title = title
        self.onDone = onDone
        let start = MeasurementEntry(inches: initialValue, denominator: max(denominator, 16))
        _entry = State(initialValue: start)
        _showSixteenths = State(initialValue: (start.fraction?.denominator ?? 8) > 8)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text(entry.display)
                        .font(.system(size: displaySize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 8)
                        .accessibilityLabel("Entered value \(entry.display)")

                    ChoicePicker(title: "Fractions", options: [false, true],
                                 label: { $0 ? "Sixteenths" : "Eighths" },
                                 selection: $showSixteenths, showsTitle: false)

                    LazyVGrid(columns: fractionColumns, spacing: 8) {
                        ForEach(showSixteenths ? sixteenths : eighths, id: \.self) { key in
                            KeyButton(label: key.label, style: .fraction,
                                      isSelected: entry.fraction == MeasurementEntry.Fraction(key.numerator, key.denominator)) {
                                entry.setFraction(key.numerator, key.denominator)
                            }
                        }
                    }

                    LazyVGrid(columns: digitColumns, spacing: 10) {
                        ForEach(1...9, id: \.self) { digit in
                            KeyButton(label: "\(digit)") { entry.appendDigit(digit) }
                        }
                        KeyButton(label: "ft", style: .secondary, accessibilityText: "Feet") { entry.commitFeet() }
                        KeyButton(label: "0") { entry.appendDigit(0) }
                        KeyButton(systemImage: "delete.left", style: .secondary, accessibilityText: "Delete") { entry.backspace() }
                    }

                    HStack(spacing: 10) {
                        KeyButton(label: ".", style: .secondary, accessibilityText: "Decimal point") { entry.appendDecimalPoint() }
                        KeyButton(label: "Clear", style: .secondary) { entry.clear() }
                    }
                }
                .padding()
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(entry.value)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

struct KeyButton: View {
    enum Style {
        case digit
        case fraction
        case secondary
    }

    var label: String? = nil
    var systemImage: String? = nil
    var style: Style = .digit
    var isSelected = false
    var accessibilityText: String? = nil
    let action: () -> Void

    // iPad shows the keypad in a shorter form sheet, so its keys are a little less tall.
    @ScaledMetric(relativeTo: .title) private var digitHeight: CGFloat = Self.isPad ? 48 : 58
    @ScaledMetric(relativeTo: .title3) private var fractionHeight: CGFloat = Self.isPad ? 40 : 46

    private static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else {
                    Text(label ?? "")
                }
            }
            .font(style == .fraction ? Font.title3.weight(.semibold) : Font.title.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, minHeight: style == .fraction ? fractionHeight : digitHeight)
            .foregroundStyle(isSelected ? Theme.onHighVis : Color.primary)
            .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText ?? label ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSelected { return Theme.highVis }
        switch style {
        case .digit: return Color(uiColor: .secondarySystemBackground)
        case .fraction, .secondary: return Color(uiColor: .tertiarySystemFill)
        }
    }
}
