import SwiftUI
import Foundation

enum DesignSystem {
    // Screen size utilities
    static let screenWidth = UIScreen.main.bounds.width
    static let screenHeight = UIScreen.main.bounds.height
    
    // Device type check
    static var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // Orientation check
    static var isLandscape: Bool {
        return UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }
    
    // Base sizes (adaptive based on device)
    static var baseWidth: CGFloat {
        return isIPad ? 1024 : 440  // iPad vs iPhone base width
    }
    static var baseHeight: CGFloat {
        return isIPad ? 1366 : 956  // iPad vs iPhone base height
    }
    
    // Maximum sizes for elements
    static var maxCardWidth: CGFloat {
        return isIPad ? 140 : 128  // Slightly smaller card size for iPad
    }
    
    static var maxImageSize: CGFloat {
        return isIPad ? 90 : 80  // Slightly smaller image size for iPad
    }
    
    // Dynamic scaling factors with limits
    static var widthScaleFactor: CGFloat {
        let factor = screenWidth / baseWidth
        return min(factor, isIPad ? 1.2 : 1.0)  // Limit scaling factor
    }
    
    static var heightScaleFactor: CGFloat {
        let factor = screenHeight / baseHeight
        return min(factor, isIPad ? 1.2 : 1.0)  // Limit scaling factor
    }
    
    // Dynamic spacing
    static var adaptivePadding: CGFloat {
        return padding * widthScaleFactor
    }
    
    static var adaptiveSpacing: CGFloat {
        return spacing * widthScaleFactor
    }
    
    // Dynamic font sizes
    static func adaptiveFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size * widthScaleFactor, weight: weight)
    }
    
    // Dynamic sizes
    static func adaptiveSize(_ size: CGFloat) -> CGFloat {
        return size * widthScaleFactor
    }
    
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
    static var gridColumns: [GridItem] {
        let minCardWidth: CGFloat = isIPad ? 160 : 100
        let availableWidth = screenWidth - (padding * 2)
        let columns = isIPad && isLandscape ? 5 : max(3, Int(availableWidth / minCardWidth))
        return Array(repeating: GridItem(.flexible(), spacing: adaptiveSpacing), count: columns)
    }
    
    // Grid spacing
    static var gridSpacing: CGFloat {
        return isIPad ? 32 : 16
    }
    
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
    
    func adaptiveFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        let scaledWidth = width.map { DesignSystem.adaptiveSize($0) }
        let scaledHeight = height.map { DesignSystem.adaptiveSize($0) }
        return frame(width: scaledWidth, height: scaledHeight)
    }
    
    func adaptivePadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        let scaledLength = length.map { DesignSystem.adaptiveSize($0) }
        return padding(edges, scaledLength)
    }
} 