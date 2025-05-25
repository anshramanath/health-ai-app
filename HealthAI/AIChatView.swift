import SwiftUI

struct AIChatView: View {
    @StateObject private var healthManager = HealthManager()
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    private let llmService = LLMService()
    
    // ai chat bot ui
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Text("🤖 AI Assistant")
                    .font(.title)
                    .bold()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .foregroundColor(.black)
                
                // message formatting & alignment
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                HStack(alignment: .bottom, spacing: 10) {
                                    if message.isUser {
                                        Spacer()
                                        Text(message.text)
                                            .padding(10)
                                            .background(Color.blue.opacity(0.2))
                                            .cornerRadius(12)
                                            .foregroundColor(.black)
                                            .frame(maxWidth: 250, alignment: .trailing)
                                            .fixedSize(horizontal: false, vertical: true)
                                    } else {
                                        Image(systemName: "waveform.path.ecg")
                                            .foregroundColor(.gray)
                                            .padding(.top, 4)
                                        Text(message.text)
                                            .padding(10)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(12)
                                            .foregroundColor(.black)
                                            .frame(maxWidth: 250, alignment: .leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal)
                                .id(message.id) // used to scroll to the latest message
                            }
                        }
                        .padding(.top)
                        .frame(minHeight: geometry.size.height * 0.75, alignment: .top)
                    }
                    .onChange(of: messages.count) {
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    TextField("Ask the AI about your health...", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.vertical, 8)

                    Button("Send") {
                        sendInput()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
            }
        }
        // useEffect() vibes
        .onAppear {
            healthManager.fetchAllData()
            // show summary message if starting fresh
            if messages.isEmpty {
                let summary = healthManager.weeklySummary
                messages.append(Message(isUser: false, text: summary))
            }
        }
    }
    
    // sending text to LLM
    private func sendInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        inputText = ""
        messages.append(Message(isUser: true, text: trimmed))

        isLoading = true
        messages.append(Message(isUser: false, text: "...")) // temporary loading message

        // system prompt defines how the LLM should behave
        let systemPrompt = """
        You are a concise, no-fluff health assistant. Use the provided health data to respond clearly and directly. Always reference actual numbers (e.g., 'You've walked 0 steps today'). Keep responses under 2 sentences. Avoid general advice unless directly asked. Do not use markdown, emojis, or filler phrases. Do not repeat motivational language unless necessary.
        """

        let healthContext = "User's Health Summary:\n\(healthManager.weeklySummary)"

        // compile message history in text format for context
        let messageHistory = messages
            .filter { $0.text != "..." }
            .map { $0.isUser ? "User: \($0.text)" : "Assistant: \($0.text)" }
            .joined(separator: "\n")

        let prompt = """
        \(systemPrompt)

        \(healthContext)

        \(messageHistory)
        Assistant:
        """

        // send to LLM and wait for response
        llmService.fetchInsight(from: prompt) { result in
            DispatchQueue.main.async {
                if let index = messages.firstIndex(where: { $0.text == "..." && !$0.isUser }) {
                    messages.remove(at: index)
                }

                let response = result ?? "Sorry, I couldn't generate a response."
                messages.append(Message(isUser: false, text: response))
                isLoading = false
            }
        }
    }
}

#Preview {
    AIChatView()
}
