import UIKit
import PDFKit

class PDFGenerator {
    // Define styles as static properties
    private static let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
    private static let subtitleFont = UIFont.systemFont(ofSize: 16, weight: .regular)
    private static let sectionHeaderFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
    private static let bodyFont = UIFont.systemFont(ofSize: 14, weight: .regular)
    
    static func generateNutritionPDF(clientName: String, nutrition: Nutrition) -> Data? {
        // Remove unused sections conversion
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        
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
            
            if let logoImage = UIImage(named: "Trainer-logo") {
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
            
            // Draw meals instead of sections
            for meal in nutrition.meals {
                // Draw meal header with icon
                let mealAttr: [NSAttributedString.Key: Any] = [
                    .font: sectionHeaderFont,
                    .foregroundColor: nasmBlue
                ]
                
                // Draw meal icon
                let iconName = getMealIcon(meal.mealName)
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
                    
                    // Draw meal name after icon
                    meal.mealName.draw(at: CGPoint(x: margin + iconSize + 10, y: yPosition), 
                                    withAttributes: mealAttr)
                } else {
                    meal.mealName.draw(at: CGPoint(x: margin, y: yPosition), 
                                    withAttributes: mealAttr)
                }
                yPosition += 30
                
                // Draw underline for meal name
                let underlinePath = UIBezierPath()
                underlinePath.move(to: CGPoint(x: margin, y: yPosition))
                underlinePath.addLine(to: CGPoint(x: margin + 100, y: yPosition))
                nasmBlue.withAlphaComponent(0.3).setStroke()
                underlinePath.lineWidth = 2
                underlinePath.stroke()
                yPosition += 20
                
                // Draw meal items
                for item in meal.items {
                    let itemText = "\(item.name) - \(item.quantity)"
                    let itemAttr: [NSAttributedString.Key: Any] = [
                        .font: bodyFont,
                        .foregroundColor: UIColor.black
                    ]
                    
                    // Draw bullet point
                    "•".draw(at: CGPoint(x: margin + 10, y: yPosition), 
                            withAttributes: [.font: bodyFont, .foregroundColor: nasmBlue])
                    
                    // Draw item text
                    itemText.draw(at: CGPoint(x: margin + 30, y: yPosition), 
                                withAttributes: itemAttr)
                    
                    yPosition += 25
                }
                
                yPosition += 20
            }
            
            // Draw footer
            let footerText = "Generated by MyPTbook"
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
    
    private static func getMealIcon(_ mealName: String) -> String {
        switch mealName.lowercased() {
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
            kCGPDFContextTitle: "MyPTbook - \(clientName)'s Training Program"
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
            
            // Draw first page
            context.beginPage()
            
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
            
            if let logoImage = UIImage(named: "Trainer-logo") {
                let logoRect = CGRect(x: logoX, y: logoY, width: logoWidth, height: logoHeight)
                logoImage.draw(in: logoRect)
            }
            
            appName.draw(at: CGPoint(x: logoX + logoWidth + 10, y: 25), withAttributes: appNameAttr)
            
            let titleString = "\(clientName)'s Workout Program"
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
            
            var yPosition: CGFloat = 150
            
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
            """
            
            programSummary.draw(at: CGPoint(x: margin + 20, y: yPosition + 20),
                              withAttributes: [
                                .font: subtitleFont,
                                .foregroundColor: UIColor.black
                              ])
            
            yPosition += 120
            
            // Number the sessions
            let numberedSessions = sessions.enumerated().map { (index, session) in
                var numberedSession = session
                numberedSession.sessionNumber = index + 1
                return numberedSession
            }
            
            // Draw sessions
            for session in numberedSessions {
                // Calculate session title height
                let sessionTitle = "Session \(session.sessionNumber): \(session.workoutName)"
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: sectionHeaderFont,
                    .foregroundColor: nasmBlue
                ]
                let titleSize = (sessionTitle as NSString).boundingRect(
                    with: CGSize(width: contentWidth - 40, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: titleAttributes,
                    context: nil
                )
                
                // Calculate card height with padding (20 points total - 10 top and bottom)
                let cardHeight = ceil(titleSize.height) + 20
                
                // Draw session card with dynamic height
                let cardPath = UIBezierPath(roundedRect: CGRect(x: margin, y: yPosition, 
                                                              width: contentWidth, height: cardHeight),
                                          cornerRadius: 8)
                nasmBlue.withAlphaComponent(0.1).setFill()
                cardPath.fill()
                
                // Draw session header centered vertically in the card
                let titleY = yPosition + (cardHeight - titleSize.height) / 2
                sessionTitle.draw(
                    at: CGPoint(x: margin + 20, y: titleY),
                    withAttributes: titleAttributes
                )
                
                // Adjust yPosition to account for the dynamic card height
                yPosition += cardHeight + 10  // Add 10 points spacing after the card
                
                // Draw exercise table headers
                let tableHeaders = ["Exercise", "Sets", "Reps/Secs"]
                let columnWidths: [CGFloat] = [
                    contentWidth * 0.6,
                    contentWidth * 0.15,
                    contentWidth * 0.15
                ]
                
                for (index, header) in tableHeaders.enumerated() {
                    let headerX = if index == 0 {
                        margin + 20
                    } else if index == 1 {
                        pageWidth - margin - (columnWidths[2] + columnWidths[1]) - 20
                    } else {
                        pageWidth - margin - columnWidths[2] - 20
                    }
                    
                    header.draw(at: CGPoint(x: headerX, y: yPosition),
                              withAttributes: [
                                .font: bodyFont.bold(),
                                .foregroundColor: nasmBlue
                              ])
                }
                
                yPosition += 25
                
                // Draw separator line
                let linePath = UIBezierPath()
                linePath.move(to: CGPoint(x: margin + 20, y: yPosition))
                linePath.addLine(to: CGPoint(x: pageWidth - margin - 20, y: yPosition))
                nasmBlue.withAlphaComponent(0.2).setStroke()
                linePath.lineWidth = 1
                linePath.stroke()
                
                yPosition += 10
                
                // Draw exercises
                var currentGroupType: Exercise.GroupType?
                var currentGroupExercises: [Exercise] = []
                var exerciseNumber = 1

                for (index, exercise) in session.exercises.enumerated() {
                    // Check for new group type or end of current group
                    let isNewGroup = exercise.groupType != currentGroupType
                    let isLastExercise = index == session.exercises.count - 1
                    
                    // If we have a current group and either starting new group or last exercise
                    if !currentGroupExercises.isEmpty && (isNewGroup || isLastExercise) {
                        // Add last exercise to group if it belongs to current group
                        if !isNewGroup && isLastExercise {
                            currentGroupExercises.append(exercise)
                        }
                        
                        // Draw group header
                        let headerHeight: CGFloat = 30
                        let headerRect = CGRect(x: margin, y: yPosition, 
                                              width: contentWidth, height: headerHeight)
                        nasmBlue.withAlphaComponent(0.05).setFill()
                        UIBezierPath(roundedRect: headerRect, cornerRadius: 6).fill()
                        
                        // Draw exercise number for the group
                        "\(exerciseNumber).".draw(
                            at: CGPoint(x: margin + 5, y: yPosition + 6),
                            withAttributes: [
                                .font: bodyFont,
                                .foregroundColor: nasmBlue
                            ]
                        )
                        exerciseNumber += 1
                        
                        // Prepare header text with sets
                        let groupTypeText = currentGroupType == .circuit ? "Circuit" : "Superset"
                        let sets = currentGroupExercises.first?.sets ?? 0
                        let headerText = "\(groupTypeText) - \(sets) Sets"
                        
                        // Draw header text (adjusted x position to account for number)
                        headerText.draw(
                            at: CGPoint(x: margin + 25, y: yPosition + 6),
                            withAttributes: [
                                .font: bodyFont.bold(),
                                .foregroundColor: nasmBlue
                            ]
                        )
                        
                        yPosition += headerHeight + 10
                        
                        // Check for page break after group header
                        if yPosition > pageHeight - margin - 50 {
                            context.beginPage()
                            yPosition = margin + 50
                        }
                        
                        // Draw exercises in the group
                        for groupExercise in currentGroupExercises {
                            // Draw bullet point for grouped exercise
                            "•".draw(
                                at: CGPoint(x: margin + 25, y: yPosition),
                                withAttributes: [
                                    .font: bodyFont,
                                    .foregroundColor: nasmBlue
                                ]
                            )
                            
                            // Exercise name with indentation
                            groupExercise.exerciseName.draw(
                                at: CGPoint(x: margin + 40, y: yPosition),
                                withAttributes: [
                                    .font: bodyFont,
                                    .foregroundColor: UIColor.black
                                ]
                            )
                            
                            // Reps/Time
                            let valueText = if let time = groupExercise.time {
                                "\(time) Secs"
                            } else {
                                "\(groupExercise.reps) Reps"
                            }
                            
                            valueText.draw(
                                at: CGPoint(x: pageWidth - margin - columnWidths[2] - 20, y: yPosition),
                                withAttributes: [
                                    .font: bodyFont,
                                    .foregroundColor: UIColor.black
                                ]
                            )
                            
                            yPosition += 30
                        }
                        
                        // Add spacing after group
                        yPosition += 10
                        
                        // Clear current group
                        currentGroupExercises.removeAll()
                    }
                    
                    // Handle new group or regular exercise
                    if let groupType = exercise.groupType {
                        if isNewGroup {
                            currentGroupType = groupType
                            currentGroupExercises = [exercise]
                        } else {
                            currentGroupExercises.append(exercise)
                        }
                    } else {
                        // Regular exercise (not in a group)
                        // Draw exercise number
                        "\(exerciseNumber).".draw(
                            at: CGPoint(x: margin + 5, y: yPosition),
                            withAttributes: [
                                .font: bodyFont,
                                .foregroundColor: nasmBlue
                            ]
                        )
                        exerciseNumber += 1
                        
                        // Exercise name
                        exercise.exerciseName.draw(
                            at: CGPoint(x: margin + 20, y: yPosition),
                            withAttributes: [
                                .font: bodyFont,
                                .foregroundColor: UIColor.black
                            ]
                        )
                        
                        // Sets
                        String(exercise.sets).draw(
                            at: CGPoint(x: pageWidth - margin - (columnWidths[2] + columnWidths[1]) - 20, y: yPosition),
                            withAttributes: [
                                .font: bodyFont,
                                .foregroundColor: UIColor.black
                            ]
                        )
                        
                        // Reps/Time
                        let valueText = if let time = exercise.time {
                            "\(time) Secs"
                        } else {
                            "\(exercise.reps) Reps"
                        }
                        
                        valueText.draw(
                            at: CGPoint(x: pageWidth - margin - columnWidths[2] - 20, y: yPosition),
                            withAttributes: [
                                .font: bodyFont,
                                .foregroundColor: UIColor.black
                            ]
                        )
                        
                        yPosition += 30
                    }
                }
                
                yPosition += 40  // Space between sessions
                
                // Check if we need a new page for the next session
                if yPosition > pageHeight - margin - 150 && session.id != sessions.last?.id {
                    context.beginPage()
                    yPosition = margin + 50
                }
            }
            
            // Draw footer
            let footerText = "Generated by MyPTbook"
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

