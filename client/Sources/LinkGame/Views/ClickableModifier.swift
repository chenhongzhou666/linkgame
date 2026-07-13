import SwiftUI
import AppKit

struct ClickableCursor: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pointingHand.pop()
                }
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pointingHand.pop()
                    isHovering = false
                }
            }
    }
}

extension View {
    func clickable() -> some View {
        modifier(ClickableCursor())
    }
}
