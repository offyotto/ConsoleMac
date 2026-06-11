import SwiftUI

struct HoverHighlight: ViewModifier {
    let cornerRadius: CGFloat
    let hoverFill: Color
    let selectedFill: Color?
    let isSelected: Bool

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
                    .animation(Theme.Motion.hover, value: isHovering)
                    .animation(Theme.Motion.hover, value: isSelected)
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }

    private var background: Color {
        if isSelected, let selectedFill { return selectedFill }
        if isHovering { return hoverFill }
        return Color.clear
    }
}

extension View {
    func hoverHighlight(
        cornerRadius: CGFloat = Theme.Radius.sm,
        hoverFill: Color = Theme.hoverFill,
        selectedFill: Color? = Theme.subtleFill,
        isSelected: Bool = false
    ) -> some View {
        modifier(HoverHighlight(
            cornerRadius: cornerRadius,
            hoverFill: hoverFill,
            selectedFill: selectedFill,
            isSelected: isSelected
        ))
    }
}

struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var pressedOpacity: Double = 0.85

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? pressedOpacity : 1)
            .animation(Theme.Motion.snap, value: configuration.isPressed)
    }
}
