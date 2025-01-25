import SwiftUI

struct OnboardingView: View {
    let steps: [OnboardingStep]
    let onCompletion: () -> Void
    
    @State private var currentStep = 0
    @Namespace private var animation
    
    // Constants following Apple's guidelines
    private let imageHeight: CGFloat = UIScreen.main.bounds.height * 0.4
    private let standardPadding: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "003B7E"), Color(hex: "001A3A")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: standardPadding) {
                // Progress indicators
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(currentStep >= index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .matchedGeometryEffect(id: "step_\(index)", in: animation)
                    }
                }
                .padding(.top, standardPadding * 2)
                
                // Content
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        VStack(spacing: standardPadding) {
                            // Image container with shadow and corner radius
                            Image(step.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: imageHeight)
                                .cornerRadius(16)
                                .shadow(
                                    color: Color.black.opacity(0.1),
                                    radius: 10,
                                    x: 0,
                                    y: 5
                                )
                                .padding(.horizontal, standardPadding)
                            
                            Text(step.title)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.top, standardPadding)
                            
                            Text(step.description)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, standardPadding * 1.5)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation buttons with original style
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                        withAnimation {
                            if currentStep == steps.count - 1 {
                                onCompletion()
                            } else {
                                currentStep += 1
                            }
                        }
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
} 