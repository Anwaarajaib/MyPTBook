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
                // Calculate total height needed for this session
                let estimatedExerciseHeight: CGFloat = 30  // Height per exercise
                let estimatedHeaderHeight: CGFloat = 100   // Height for session header, title, etc.
                let totalEstimatedHeight = estimatedHeaderHeight + 
                    (CGFloat(session.exercises.count) * estimatedExerciseHeight)
                
                // Check if we need a page break
                if yPosition + totalEstimatedHeight > pageHeight - margin - 100 {
                    context.beginPage()
                    yPosition = margin + 50
                }
                
                // Calculate session title height
                let sessionTitle = "Session \(session.sessionNumber): \(session.workoutName)"
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: sectionHeaderFont,
                    .foregroundColor: nasmBlue
                ]
                
                // Draw session title
                sessionTitle.draw(
                    at: CGPoint(x: margin + 20, y: yPosition),
                    withAttributes: titleAttributes
                )
                
                yPosition += 40  // Add space after title
                
                // Draw exercise table headers
                let tableHeaders = ["Exercise", "Sets", "Reps/Time"]
                let columnWidths: [CGFloat] = [
                    contentWidth * 0.6,
                    contentWidth * 0.15,
                    contentWidth * 0.15
                ]
                
                // Draw headers
                for (index, header) in tableHeaders.enumerated() {
                    let headerX = if index == 0 {
                        margin + 20
                    } else if index == 1 {
                        pageWidth - margin - (columnWidths[2] + columnWidths[1]) - 20
                    } else {
                        pageWidth - margin - columnWidths[2] - 20
                    }
                    
                    header.draw(
                        at: CGPoint(x: headerX, y: yPosition),
                        withAttributes: [
                            .font: bodyFont.bold(),
                            .foregroundColor: nasmBlue
                        ]
                    )
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
                var exerciseNumber = 1
                var currentGroupId: String?
                var currentGroupExercises: [Exercise] = []
                
                for (index, exercise) in session.exercises.enumerated() {
                    // Check for page break
                    if yPosition > pageHeight - margin - 100 {
                        context.beginPage()
                        yPosition = margin + 50
                    }
                    
                    if let groupType = exercise.groupType {
                        // Handle grouped exercises
                        if exercise.groupId != currentGroupId {
                            // Draw previous group if exists
                            if !currentGroupExercises.isEmpty {
                                drawExerciseGroup(
                                    exercises: currentGroupExercises,
                                    type: currentGroupExercises[0].groupType!,
                                    at: &yPosition,
                                    number: &exerciseNumber,
                                    pageWidth: pageWidth,
                                    margin: margin,
                                    columnWidths: columnWidths,
                                    bodyFont: bodyFont,
                                    nasmBlue: nasmBlue
                                )
                            }
                            // Start new group
                            currentGroupId = exercise.groupId
                            currentGroupExercises = [exercise]
                        } else {
                            // Add to current group
                            currentGroupExercises.append(exercise)
                        }
                        
                        // Draw final group if it's the last exercise
                        if index == session.exercises.count - 1 && !currentGroupExercises.isEmpty {
                            drawExerciseGroup(
                                exercises: currentGroupExercises,
                                type: groupType,
                                at: &yPosition,
                                number: &exerciseNumber,
                                pageWidth: pageWidth,
                                margin: margin,
                                columnWidths: columnWidths,
                                bodyFont: bodyFont,
                                nasmBlue: nasmBlue
                            )
                        }
                    } else {
                        // Draw any pending group before drawing single exercise
                        if !currentGroupExercises.isEmpty {
                            drawExerciseGroup(
                                exercises: currentGroupExercises,
                                type: currentGroupExercises[0].groupType!,
                                at: &yPosition,
                                number: &exerciseNumber,
                                pageWidth: pageWidth,
                                margin: margin,
                                columnWidths: columnWidths,
                                bodyFont: bodyFont,
                                nasmBlue: nasmBlue
                            )
                            currentGroupExercises = []
                            currentGroupId = nil
                        }
                        
                        // Draw single exercise
                        drawSingleExercise(
                            exercise,
                            number: exerciseNumber,
                            at: &yPosition,
                            pageWidth: pageWidth,
                            margin: margin,
                            columnWidths: columnWidths,
                            bodyFont: bodyFont,
                            nasmBlue: nasmBlue
                        )
                        exerciseNumber += 1
                    }
                }
                
                // Add extra space between sessions
                yPosition += 40
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
    
    private static func drawExerciseGroup(
        exercises: [Exercise],
        type: Exercise.GroupType,
        at yPosition: inout CGFloat,
        number: inout Int,
        pageWidth: CGFloat,
        margin: CGFloat,
        columnWidths: [CGFloat],
        bodyFont: UIFont,
        nasmBlue: UIColor
    ) {
        // Draw group number
        "\(number).".draw(
            at: CGPoint(x: margin + 20, y: yPosition),
            withAttributes: [.font: bodyFont.bold(), .foregroundColor: nasmBlue]
        )

        // Draw icon and title
        let groupIcon = type == .circuit ? "arrow.3.trianglepath" : "arrow.triangle.2.circlepath"
        if let iconImage = UIImage(systemName: groupIcon) {
            let iconSize: CGFloat = 20
            let iconRect = CGRect(x: margin + 45, y: yPosition, width: iconSize, height: iconSize)
            
            // Create a tinted version of the icon
            let renderer = UIGraphicsImageRenderer(size: iconImage.size)
            let tintedIcon = renderer.image { context in
                nasmBlue.setFill()
                iconImage.draw(in: CGRect(origin: .zero, size: iconImage.size))
            }
            
            tintedIcon.draw(in: iconRect)
            
            // Draw group type title after icon
            let typeTitle = type == .circuit ? "Circuit" : "Superset"
            typeTitle.draw(
                at: CGPoint(x: margin + 45 + iconSize + 8, y: yPosition),
                withAttributes: [.font: bodyFont.bold(), .foregroundColor: nasmBlue]
            )
        }
        
        // Draw sets count in the sets column
        let setsText = "\(exercises.first?.sets ?? 0)"
        setsText.draw(
            at: CGPoint(x: pageWidth - margin - (columnWidths[2] + columnWidths[1]) - 20, y: yPosition),
            withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
        )
        
        yPosition += 25
        
        // Draw exercises in group
        for exercise in exercises {
            // Draw bullet point
            "•".draw(
                at: CGPoint(x: margin + 45, y: yPosition),
                withAttributes: [.font: bodyFont.bold(), .foregroundColor: nasmBlue]
            )
            
            // Draw exercise name
            exercise.exerciseName.draw(
                at: CGPoint(x: margin + 65, y: yPosition),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
            )
            
            // Draw reps/time
            let valueText = if let time = exercise.time {
                "\(time) Secs"
            } else {
                "\(exercise.reps) Reps"
            }
            
            valueText.draw(
                at: CGPoint(x: pageWidth - margin - columnWidths[2] - 20, y: yPosition),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
            )
            
            yPosition += 25
        }
        
        yPosition += 10
        number += 1
    }
    
    private static func drawSingleExercise(
        _ exercise: Exercise,
        number: Int,
        at yPosition: inout CGFloat,
        pageWidth: CGFloat,
        margin: CGFloat,
        columnWidths: [CGFloat],
        bodyFont: UIFont,
        nasmBlue: UIColor
    ) {
        // Draw exercise number
        "\(number).".draw(
            at: CGPoint(x: margin + 20, y: yPosition),
            withAttributes: [.font: bodyFont.bold(), .foregroundColor: nasmBlue]
        )
        
        // Draw exercise name
        exercise.exerciseName.draw(
            at: CGPoint(x: margin + 40, y: yPosition),
            withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
        )
        
        // Draw sets
        String(exercise.sets).draw(
            at: CGPoint(x: pageWidth - margin - (columnWidths[2] + columnWidths[1]) - 20, y: yPosition),
            withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
        )
        
        // Draw reps/time
        let valueText = if let time = exercise.time {
            "\(time) Secs"
        } else {
            "\(exercise.reps) Reps"
        }
        
        valueText.draw(
            at: CGPoint(x: pageWidth - margin - columnWidths[2] - 20, y: yPosition),
            withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
        )
        
        yPosition += 30
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

