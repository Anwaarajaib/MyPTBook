import SwiftUI
import Foundation

enum DesignSystem {
    // Spacing
    static let padding: CGFloat = 24
    static let spacing: CGFloat = 20
    static let minimumTapTarget: CGFloat = 44
    
    // Styling
    static let cornerRadius: CGFloat = 16
    static let shadowRadius: CGFloat = 10
    
    // Typography
    static let titleFont: Font = .title2.bold()
    static let headlineFont: Font = .headline
    static let bodyFont: Font = .body
    static let captionFont: Font = .caption
    
    // Colors
    static let shadowColor = Color.black.opacity(0.05)
    static let cardBackground = Color.white
    
    // Animation
    static let defaultAnimation: Animation = .easeInOut(duration: 0.3)
    
    // Layout
    static let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // Common Modifiers
    struct CardModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(DesignSystem.padding)
                .background(DesignSystem.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cornerRadius))
                .shadow(
                    color: DesignSystem.shadowColor,
                    radius: DesignSystem.shadowRadius,
                    x: 0,
                    y: 4
                )
        }
    }
    
    static func defaultCard<Content: View>(_ content: Content) -> some View {
        content.modifier(CardModifier())
    }
}

// Extension to make the card modifier more easily accessible
extension View {
    func cardStyle() -> some View {
        modifier(DesignSystem.CardModifier())
    }
} 