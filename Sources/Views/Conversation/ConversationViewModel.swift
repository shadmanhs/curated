import Foundation
import Combine
import ElevenLabs

@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var conversation: Conversation?
    @Published var connectionStatus: String = "Ready"
    @Published var isConnected = false
    @Published var isMuted = false
    @Published var agentIsSpeaking = false
    @Published var messages: [ConversationMessage] = []
    @Published var latestEmotion: EmotionEvent?

    private var cancellables = Set<AnyCancellable>()
    private let audioTap = AudioTapService()
    private var toolObserverTask: Task<Void, Never>?
    private var lastSyncedVibeHash: Int = 0

    var vibeStore: VibeStore?

    init() {
        audioTap.$latestEmotion
            .receive(on: DispatchQueue.main)
            .assign(to: &$latestEmotion)
    }

    func startConversation() async {
        let agentId = Secrets.elevenLabsAgentId
        guard !agentId.isEmpty else {
            connectionStatus = "Missing Agent ID"
            return
        }

        connectionStatus = "Connecting..."

        do {
            // Update agent system prompt only if vibe context changed
            let vibeMd = vibeStore?.rawMarkdown ?? ""
            let vibeHash = vibeMd.hashValue
            if vibeHash != lastSyncedVibeHash {
                await updateAgentPrompt(agentId: agentId, vibeContext: vibeMd)
                lastSyncedVibeHash = vibeHash
            }

            let voiceId = Secrets.elevenLabsVoiceId.isEmpty ? nil : Secrets.elevenLabsVoiceId
            let config = ConversationConfig(
                ttsOverrides: voiceId.map { TTSOverrides(voiceId: $0) },
                conversationOverrides: ConversationOverrides(textOnly: false)
            )

            let conv = try await ElevenLabs.startConversation(
                agentId: agentId,
                config: config
            )

            conversation = conv
            setupObservers()
            audioTap.startTap()
            connectionStatus = "Connected"
            isConnected = true
        } catch {
            connectionStatus = "Failed: \(error.localizedDescription)"
        }
    }

    func endConversation() async {
        guard let conversation else { return }
        await conversation.endConversation()
        toolObserverTask?.cancel()
        audioTap.stopTap()
        self.conversation = nil
        isConnected = false
        connectionStatus = "Ended"
    }

    func toggleMute() async {
        guard let conversation else { return }
        try? await conversation.toggleMute()
    }

    func sendTextMessage(_ text: String) async {
        guard let conversation else { return }
        try? await conversation.sendMessage(text)
    }

    private func setupObservers() {
        guard let conversation else { return }

        conversation.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .idle:
                    self?.connectionStatus = "Idle"
                    self?.isConnected = false
                case .connecting:
                    self?.connectionStatus = "Connecting..."
                case .active:
                    self?.connectionStatus = "Active"
                    self?.isConnected = true
                case .ended:
                    self?.connectionStatus = "Ended"
                    self?.isConnected = false
                case .error(let error):
                    self?.connectionStatus = "Error: \(error.localizedDescription)"
                    self?.isConnected = false
                }
            }
            .store(in: &cancellables)

        conversation.$agentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .speaking:
                    self?.agentIsSpeaking = true
                case .listening:
                    self?.agentIsSpeaking = false
                default:
                    break
                }
            }
            .store(in: &cancellables)

        conversation.$isMuted
            .receive(on: DispatchQueue.main)
            .assign(to: &$isMuted)

        conversation.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                self?.messages = msgs.compactMap { msg in
                    let cleaned = msg.content
                        .replacingOccurrences(of: "\\[.*?\\]\\s*", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleaned.isEmpty else { return nil }
                    return ConversationMessage(
                        role: msg.role == .user ? .user : .agent,
                        content: cleaned
                    )
                }
            }
            .store(in: &cancellables)

        // Handle client tool calls (fit_check, etc.)
        toolObserverTask = Task {
            for await toolCalls in conversation.$pendingToolCalls.values {
                for toolCall in toolCalls {
                    await handleToolCall(toolCall)
                }
            }
        }
    }

    private func handleToolCall(_ toolCall: ClientToolCallEvent) async {
        let params = (try? toolCall.getParameters()) ?? [:]
        var result: [String: Any] = [:]

        switch toolCall.toolName {
        case "fit_check":
            // The agent triggers a fit check — app captures camera frame
            result = ["status": "fit_check_triggered", "message": "Camera frame requested"]

        case "find_similar":
            let query = params["query"] as? String ?? ""
            result = ["status": "searching", "query": query]

        default:
            result = ["error": "Unknown tool: \(toolCall.toolName)"]
        }

        try? await conversation?.sendToolResult(
            for: toolCall.toolCallId,
            result: result
        )
    }

    private func updateAgentPrompt(agentId: String, vibeContext: String) async {
        let apiKey = Secrets.elevenLabsAPIKey
        guard !apiKey.isEmpty else { return }

        let prompt = """
        You are Curated, a personal style advisor and talking mirror. You are a calm, direct, tasteful voice that reflects the user's aesthetic back to them.
        Speak like a confident, warm friend with excellent taste. Never be sycophantic. Be brief and specific.
        Do not use stage directions like [Warmly] or [Gently] in your responses.
        Keep responses conversational — 2-3 sentences max unless asked for more detail.
        \(vibeContext.isEmpty ? "" : "\nThe user's personal style profile:\n\(vibeContext)")
        """

        guard let url = URL(string: "https://api.elevenlabs.io/v1/convai/agents/\(agentId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "conversation_config": [
                "agent": [
                    "prompt": [
                        "prompt": prompt
                    ]
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: request)
    }
}

struct ConversationMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user, agent
    }
}
