import SwiftUI

struct AddSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dataManager = DataManager.shared
    let client: Client
    
    // Session properties
    @State private var workoutName = ""
    @State private var isCompleted = false
    @State private var completedDate = Date()
    @State private var showingAddExercise = false
    @State private var isProcessing = false
    @State private var error: String?
    @State private var showingError = false
    @State private var createdSession: Session?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Session Details Card
                    sessionDetailsCard
                    
                    // Add Session Button
                    saveButton
                }
                .padding()
            }
            .background(Colors.background)
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                if let session = createdSession {
                    AddExerciseView(session: session)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(error ?? "An unknown error occurred")
            }
        }
    }
    
    private var sessionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Session Details")
                .font(.headline)
            
            TextField("Workout Name", text: $workoutName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Toggle("Mark as Completed", isOn: $isCompleted)
            
            if isCompleted {
                DatePicker("Completion Date", selection: $completedDate, displayedComponents: [.date])
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var saveButton: some View {
        Button(action: saveSession) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 5)
                }
                Text(isProcessing ? "Saving..." : "Save Session")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(workoutName.isEmpty ? Color.gray : Colors.nasmBlue)
            .cornerRadius(12)
        }
        .disabled(workoutName.isEmpty || isProcessing)
    }
    
    private func saveSession() {
        Task {
            isProcessing = true
            do {
                let session = try await dataManager.createSession(
                    for: client._id,
                    workoutName: workoutName,
                    isCompleted: isCompleted,
                    completedDate: isCompleted ? completedDate : nil
                )
                
                await MainActor.run {
                    isProcessing = false
                    createdSession = session
                    showingAddExercise = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    self.error = handleError(error)
                    showingError = true
                }
            }
        }
    }
    
    private func handleError(_ error: Error) -> String {
        switch error {
        case APIError.unauthorized:
            return "Your session has expired. Please log in again"
        case APIError.serverError(let message):
            return "Server error: \(message)"
        case APIError.networkError:
            return "Network error. Please check your connection"
        default:
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
