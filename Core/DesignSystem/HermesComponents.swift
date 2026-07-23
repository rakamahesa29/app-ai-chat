import SwiftUI

// MARK: - Primary Button
struct HermesButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var size: ButtonSize = .medium
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary, ghost, danger
    }
    
    enum ButtonSize {
        case small, medium, large
        
        var verticalPadding: CGFloat {
            switch self {
            case .small: return HermesSpacing.sm
            case .medium: return HermesSpacing.md
            case .large: return HermesSpacing.lg
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return HermesSpacing.md
            case .medium: return HermesSpacing.lg
            case .large: return HermesSpacing.xl
            }
        }
        
        var font: Font {
            switch self {
            case .small: return .hermes.caption
            case .medium: return .hermes.bodyMedium
            case .large: return .hermes.bodyMedium
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: HermesSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: size == .small ? 12 : 14, weight: .medium))
                }
                Text(title)
                    .font(size.font)
            }
            .foregroundColor(foregroundColor)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(maxWidth: style == .primary ? .infinity : nil)
            .background(backgroundColor)
            .cornerRadius(HermesRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: HermesRadius.md)
                    .strokeBorder(borderColor, lineWidth: style == .secondary ? 1 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary: return .hermes.accent
        case .secondary: return .clear
        case .ghost: return .clear
        case .danger: return .hermes.danger
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .danger: return .white
        case .secondary: return .hermes.text
        case .ghost: return .hermes.muted
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .secondary: return .hermes.border
        default: return .clear
        }
    }
}

// MARK: - Text Input
struct HermesTextField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var icon: String? = nil
    
    init(_ placeholder: String, text: Binding<String>, label: String? = nil, isSecure: Bool = false, icon: String? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.label = label
        self.isSecure = isSecure
        self.icon = icon
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: HermesSpacing.sm) {
            if let label = label {
                Text(label.uppercased())
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.muted)
                    .kerning(0.5)
            }
            
            HStack(spacing: HermesSpacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.hermes.muted)
                }
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.hermes.body)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.hermes.body)
                }
            }
            .foregroundColor(.hermes.text)
            .padding(HermesSpacing.md)
            .background(Color.hermes.surface)
            .cornerRadius(HermesRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: HermesRadius.md)
                    .strokeBorder(Color.hermes.border, lineWidth: 1)
            )
        }
        #if os(iOS)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        #endif
    }
}

// MARK: - Card Container
struct HermesCard<Content: View>: View {
    var padding: CGFloat = HermesSpacing.lg
    var hasBorder: Bool = true
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .padding(padding)
            .background(Color.hermes.card)
            .cornerRadius(HermesRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: HermesRadius.lg)
                    .strokeBorder(Color.hermes.border, lineWidth: hasBorder ? 1 : 0)
            )
    }
}

// MARK: - Badge
struct HermesBadge: View {
    let text: String
    var color: Color = .hermes.accent
    var style: BadgeStyle = .filled
    
    enum BadgeStyle {
        case filled, outline, subtle
    }
    
    var body: some View {
        Text(text)
            .font(.hermes.badge)
            .padding(.horizontal, HermesSpacing.sm)
            .padding(.vertical, HermesSpacing.xs)
            .foregroundColor(foregroundColor)
            .background(backgroundColor)
            .cornerRadius(HermesRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: HermesRadius.sm)
                    .strokeBorder(borderColor, lineWidth: style == .outline ? 1 : 0)
            )
    }
    
    private var foregroundColor: Color {
        switch style {
        case .filled: return .white
        case .outline, .subtle: return color
        }
    }
    
    private var backgroundColor: Color {
        switch style {
        case .filled: return color
        case .outline: return .clear
        case .subtle: return color.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        style == .outline ? color.opacity(0.3) : .clear
    }
}

// MARK: - Dropdown / Picker
struct HermesPicker: View {
    let label: String?
    @Binding var selection: String
    let options: [String]
    var displayLabels: [String: String]? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: HermesSpacing.sm) {
            if let label = label {
                Text(label.uppercased())
                    .font(.hermes.badge)
                    .foregroundColor(.hermes.muted)
                    .kerning(0.5)
            }
            
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(action: { selection = option }) {
                        let display = displayLabels?[option] ?? option
                        if selection == option {
                            Label(display, systemImage: "checkmark")
                        } else {
                            Text(display)
                        }
                    }
                }
            } label: {
                HStack {
                    Text(displayLabels?[selection] ?? selection)
                        .font(.hermes.body)
                        .foregroundColor(.hermes.text)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.hermes.muted)
                }
                .padding(HermesSpacing.md)
                .background(Color.hermes.surface)
                .cornerRadius(HermesRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: HermesRadius.md)
                        .strokeBorder(Color.hermes.border, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Icon Button
struct HermesIconButton: View {
    let icon: String
    var size: CGFloat = 36
    var color: Color = .hermes.muted
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(Color.hermes.hover.opacity(0.01))
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Section Header
struct HermesSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: HermesSpacing.xs) {
                Text(title)
                    .font(.hermes.h2)
                    .foregroundColor(.hermes.text)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                }
            }
            
            Spacer()
            
            if let action = action, let label = actionLabel {
                HermesButton(title: label, style: .secondary, size: .small, action: action)
            }
        }
    }
}

// MARK: - Empty State
struct HermesEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: HermesSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.hermes.muted.opacity(0.4))
            
            VStack(spacing: HermesSpacing.sm) {
                Text(title)
                    .font(.hermes.bodyMedium)
                    .foregroundColor(.hermes.text)
                
                if let message = message {
                    Text(message)
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let actionLabel = actionLabel, let action = action {
                HermesButton(title: actionLabel, icon: "plus", size: .small, action: action)
                    .fixedSize()
            }
        }
        .padding(HermesSpacing.xxxxl)
    }
}

// MARK: - Toggle Row (for settings/providers)
struct HermesToggleRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String
    var iconColor: Color = .hermes.accent
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: HermesSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: HermesRadius.sm)
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.hermes.bodyMedium)
                    .foregroundColor(.hermes.text)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .hermes.success))
                .labelsHidden()
        }
        .padding(HermesSpacing.md)
        .background(Color.hermes.surface)
        .cornerRadius(HermesRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.md)
                .strokeBorder(Color.hermes.border, lineWidth: 1)
        )
    }
}

// MARK: - Adaptive Stack (horizontal on wide, vertical on narrow)
struct HermesAdaptiveStack<Content: View>: View {
    var threshold: CGFloat = 600
    var horizontalSpacing: CGFloat = HermesSpacing.lg
    var verticalSpacing: CGFloat = HermesSpacing.md
    @ViewBuilder let content: () -> Content
    
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var body: some View {
        GeometryReader { geo in
            if geo.size.width > threshold {
                HStack(alignment: .top, spacing: horizontalSpacing) {
                    content()
                }
            } else {
                VStack(spacing: verticalSpacing) {
                    content()
                }
            }
        }
    }
}
