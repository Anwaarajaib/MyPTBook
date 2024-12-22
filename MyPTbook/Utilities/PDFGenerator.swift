import UIKit
import PDFKit

class PDFGenerator {
    // Define styles as static properties
    private static let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
    private static let subtitleFont = UIFont.systemFont(ofSize: 16, weight: .regular)
    private static let sectionHeaderFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
    private static let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    
    static func generateNutritionPDF(clientName: String, sections: [NutritionSectionModel]) -> Data? {
        let pageWidth: CGFloat = 612  // US Letter width
        let pageHeight: CGFloat = 792  // US Letter height
        let margin: CGFloat = 50
        _ = pageWidth - (margin * 2)
        
        let pdfMetaData = [
            kCGPDFContextCreator: "MyPTbook",
            kCGPDFContextAuthor: "MyPTbook",
            kCGPDFContextTitle: "MyPTbook - \(clientName)'s Nutrition Plan"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        return renderer.pdfData { context in
            context.beginPage()
            
            // Define styles
            let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 16, weight: .regular)
            let sectionHeaderFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            _ = UIFont.systemFont(ofSize: 12, weight: .medium)
            
            let nasmBlue = UIColor(Colors.nasmBlue)
            
            // Draw header background
            let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 120)
            nasmBlue.withAlphaComponent(0.1).setFill()
            UIBezierPath(rect: headerRect).fill()
            
            // Draw logo and app name
            let appName = "MyPTbook / \(DataManager.shared.getUserName())"
            let appNameAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: nasmBlue
            ]
            
            // Draw app logo with adjusted dimensions
            let logoWidth: CGFloat = 60  // Keep width
            let logoHeight: CGFloat = 110  // Reduce height
            let logoX: CGFloat = margin - 40  // Move slightly left
            let logoY: CGFloat = 20  // Adjust vertical position
            
            if let logoImage = UIImage(named: "trainer-silhouette") {
                let logoRect = CGRect(x: logoX, y: logoY, width: logoWidth, height: logoHeight)
                logoImage.draw(in: logoRect)
            }
            
            // Draw app name closer to logo
            appName.draw(at: CGPoint(x: logoX + logoWidth + 10, y: 25), withAttributes: appNameAttr)
            
            // Draw title closer to logo
            let titleString = "\(clientName)'s Nutrition Plan"
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            titleString.draw(at: CGPoint(x: logoX + logoWidth + 10, y: 60), withAttributes: titleAttr)
            
            // Draw date closer to logo
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let dateString = dateFormatter.string(from: Date())
            let dateAttr: [NSAttributedString.Key: Any] = [
                .font: subtitleFont,
                .foregroundColor: UIColor.gray
            ]
            dateString.draw(at: CGPoint(x: logoX + logoWidth + 10, y: 90), withAttributes: dateAttr)
            
            // Adjust starting position for content
            var yPosition: CGFloat = 150
            
            // Draw sections
            for section in sections {
                // Draw section header with icon
                let sectionAttr: [NSAttributedString.Key: Any] = [
                    .font: sectionHeaderFont,
                    .foregroundColor: nasmBlue
                ]
                
                // Draw section icon
                let iconName = getSectionIcon(section.title)
                let configuration = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
                if let iconImage = UIImage(systemName: iconName, withConfiguration: configuration) {
                    let iconSize: CGFloat = 24
                    let iconRect = CGRect(x: margin, y: yPosition - 5, width: iconSize, height: iconSize)
                    
                    // Create a tinted version of the icon
                    let renderer = UIGraphicsImageRenderer(size: iconImage.size)
                    let tintedIcon = renderer.image { context in
                        nasmBlue.setFill()
                        iconImage.draw(in: CGRect(origin: .zero, size: iconImage.size))
                    }
                    
                    tintedIcon.draw(in: iconRect)
                    
                    // Draw section title after icon
                    section.title.draw(at: CGPoint(x: margin + iconSize + 10, y: yPosition), 
                                      withAttributes: sectionAttr)
                } else {
                    section.title.draw(at: CGPoint(x: margin, y: yPosition), 
                                      withAttributes: sectionAttr)
                }
                yPosition += 30
                
                // Draw section underline
                let underlinePath = UIBezierPath()
                underlinePath.move(to: CGPoint(x: margin, y: yPosition))
                underlinePath.addLine(to: CGPoint(x: margin + 100, y: yPosition))
                nasmBlue.withAlphaComponent(0.3).setStroke()
                underlinePath.lineWidth = 2
                underlinePath.stroke()
                yPosition += 20
                
                // Draw items
                for item in section.items {
                    // Check if we need a new page
                    if yPosition > pageHeight - margin {
                        context.beginPage()
                        yPosition = margin
                    }
                    
                    // Draw single bullet point
                    let bulletAttr: [NSAttributedString.Key: Any] = [
                        .font: bodyFont,
                        .foregroundColor: nasmBlue
                    ]
                    "•".draw(at: CGPoint(x: margin + 10, y: yPosition), withAttributes: bulletAttr)
                    
                    // Draw original item text without any bullet points
                    let itemAttr: [NSAttributedString.Key: Any] = [
                        .font: bodyFont,
                        .foregroundColor: UIColor.black
                    ]
                    
                    // Remove any existing bullet points from the item text
                    let cleanedItem = item.trimmingCharacters(in: .whitespaces)
                        .replacingOccurrences(of: "^[•\\-\\*]\\s*", with: "", options: .regularExpression)
                    
                    cleanedItem.draw(at: CGPoint(x: margin + 30, y: yPosition), withAttributes: itemAttr)
                    
                    yPosition += 25
                }
                
                yPosition += 20
            }
            
            // Draw footer
            let footerText = "Generated by \(DataManager.shared.getUserName())"
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            let footerSize = footerText.size(withAttributes: footerAttr)
            footerText.draw(
                at: CGPoint(x: pageWidth - margin - footerSize.width,
                           y: pageHeight - margin),
                withAttributes: footerAttr
            )
        }
    }
    
    private static func extractQuantity(from item: String) -> (food: String, quantity: String)? {
        let patterns = [
            "([\\d.]+)\\s*(scoop|cup|g|gram|ml|oz|tbsp|tsp|piece|slice)s?\\s+of\\s+(.+)",
            "([\\d.]+)\\s*(scoop|cup|g|gram|ml|oz|tbsp|tsp|piece|slice)s?\\s*(.+)",
            "(.+?)\\s*[-–]\\s*(\\d+[\\d.]*\\s*(?:g|gram|ml|oz|cal|kcal|calories))\\s*$",
            "(.+?)\\s*\\((\\d+[\\d.]*\\s*(?:g|gram|ml|oz|cal|kcal|calories))\\s*\\)\\s*$"
        ]
        
        for pattern in patterns {
            if let match = item.range(of: pattern, options: .regularExpression) {
                let matchedString = String(item[match])
                let components = matchedString.components(separatedBy: CharacterSet(charactersIn: " -–()"))
                    .filter { !$0.isEmpty }
                
                if components.count >= 2 {
                    let quantity = components.first { $0.first?.isNumber == true } ?? ""
                    let food = components.filter { $0.first?.isNumber != true }.joined(separator: " ")
                    return (food.trimmingCharacters(in: .whitespaces),
                           quantity.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        
        return nil
    }
    
    private static func getSectionIcon(_ title: String) -> String {
        switch title.lowercased() {
        case "breakfast": return "sun.rise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.stars.fill"
        case "snacks": return "leaf.fill"
        case "supplements": return "pills.fill"
        case "pre-workout": return "figure.run"
        case "post-workout": return "figure.cooldown"
        default: return "fork.knife"
        }
    }
    
    // Add this function to generate PDF for sessions
    static func generateSessionsPDF(clientName: String, sessions: [Session]) -> Data? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (margin * 2)
        
        let pdfMetaData = [
            kCGPDFContextCreator: "MyPTbook",
            kCGPDFContextAuthor: "MyPTbook",
            kCGPDFContextTitle: "MyPTbook - \(clientName)'s Workout Program"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        return renderer.pdfData { context in
            // Define styles
            let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 16, weight: .regular)
            let sectionHeaderFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
            let nasmBlue = UIColor(Colors.nasmBlue)
            
            // Helper function to draw first page header
            func drawFirstPageHeader() {
                // Draw header background
                let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 120)
                nasmBlue.withAlphaComponent(0.1).setFill()
                UIBezierPath(rect: headerRect).fill()
                
                // Draw logo and app name
                let appName = "MyPTbook / \(DataManager.shared.getUserName())"
                let appNameAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                    .foregroundColor: nasmBlue
                ]
                
                // Draw app logo
                let logoWidth: CGFloat = 60
                let logoHeight: CGFloat = 110
                let logoX: CGFloat = margin - 40
                let logoY: CGFloat = 20
                
                if let logoImage = UIImage(named: "trainer-silhouette") {
                    let logoRect = CGRect(x: logoX, y: logoY, width: logoWidth, height: logoHeight)
                    logoImage.draw(in: logoRect)
                }
                
                appName.draw(at: CGPoint(x: logoX + logoWidth + 10, y: 25), withAttributes: appNameAttr)
                
                let titleString = "\(clientName)'s Training Sessions"
                let titleAttr: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: UIColor.black
                ]
                titleString.draw(at: CGPoint(x: logoX + logoWidth + 10, y: 60), withAttributes: titleAttr)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .long
                let dateString = dateFormatter.string(from: Date())
                let dateAttr: [NSAttributedString.Key: Any] = [
                    .font: subtitleFont,
                    .foregroundColor: UIColor.gray
                ]
                dateString.draw(at: CGPoint(x: logoX + logoWidth + 10, y: 90), withAttributes: dateAttr)
            }
            
            // Draw first page
            context.beginPage()
            drawFirstPageHeader()
            var yPosition: CGFloat = 180
            
            // Draw program overview
            let summaryBox = UIBezierPath(roundedRect: CGRect(x: margin, y: yPosition, 
                                                             width: contentWidth, height: 100),
                                         cornerRadius: 12)
            nasmBlue.withAlphaComponent(0.05).setFill()
            summaryBox.fill()
            
            // Draw program details
            let totalSessions = sessions.count
            let programSummary = """
            Program Overview
            Total Sessions: \(totalSessions)
            Focus: Strength & Conditioning
            """
            
            programSummary.draw(at: CGPoint(x: margin + 20, y: yPosition + 20),
                              withAttributes: [
                                .font: subtitleFont,
                                .foregroundColor: UIColor.black
                              ])
            
            yPosition += 120
            
            // Draw sessions
            for session in sessions.sorted(by: { 
                // Sort by completedDate if available, otherwise keep original order
                if let date1 = $0.completedDate, let date2 = $1.completedDate {
                    return date1 < date2
                }
                return false
            }) {
                // Calculate height needed for this session
                let sessionHeight: CGFloat = 90  // Basic session header height + exercises list
                
                // Check if we need a new page
                if yPosition + sessionHeight > pageHeight - margin {
                    context.beginPage()
                    yPosition = margin + 50
                }
                
                // Draw session card
                let cardPath = UIBezierPath(roundedRect: CGRect(x: margin, y: yPosition, 
                                                              width: contentWidth, height: sessionHeight),
                                          cornerRadius: 8)
                nasmBlue.withAlphaComponent(0.1).setFill()
                cardPath.fill()
                
                // Draw workout name
                session.workoutName.draw(at: CGPoint(x: margin + 20, y: yPosition + 10),
                                      withAttributes: [
                                          .font: sectionHeaderFont,
                                          .foregroundColor: nasmBlue
                                      ])
                
                // Draw completion date if available
                if let completedDate = session.completedDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    let dateString = dateFormatter.string(from: completedDate)
                    dateString.draw(at: CGPoint(x: margin + 20, y: yPosition + 40),
                                   withAttributes: [
                                       .font: bodyFont,
                                       .foregroundColor: UIColor.gray
                                   ])
                }
                
                // Draw exercise count
                let exerciseCount = "\(session.exercises.count) exercises"
                exerciseCount.draw(at: CGPoint(x: margin + 20, y: yPosition + 65),
                                  withAttributes: [
                                      .font: bodyFont,
                                      .foregroundColor: UIColor.darkGray
                                  ])
                
                yPosition += sessionHeight + 20  // Add spacing between sessions
            }
        }
    }
    
    private static func getTextWidth(_ text: String, with attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let size = (text as NSString).size(withAttributes: attributes)
        return size.width
    }
}

private extension UIFont {
    func bold() -> UIFont {
        return UIFont.systemFont(ofSize: self.pointSize, weight: .semibold)
    }
    
    func italic() -> UIFont {
        return UIFont.italicSystemFont(ofSize: self.pointSize)
    }
}

