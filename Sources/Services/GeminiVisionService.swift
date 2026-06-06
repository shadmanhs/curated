import Foundation
import UIKit

enum GeminiVisionService {
    static func analyze(image: UIImage, prompt: String, vibeContext: String) async throws -> String {
        let apiKey = Secrets.geminiAPIKey
        guard !apiKey.isEmpty else {
            throw GeminiVisionError.missingAPIKey
        }

        // Compress image
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            throw GeminiVisionError.imageEncodingFailed
        }
        let base64Image = jpegData.base64EncodedString()

        // Build request
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let systemPrompt = """
        You are Curated, a brutally honest style advisor. The user wants to know if they should post this photo.
        Give direct, specific feedback: lighting, composition, outfit, vibe, energy.
        End with a clear YES/NO verdict on whether to post, with a brief reason.
        Keep it to 3-4 sentences max. Be warm but honest — no empty flattery.
        \(vibeContext.isEmpty ? "" : "\nUser's style profile:\n\(vibeContext)")
        """

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiVisionError.requestFailed(errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw GeminiVisionError.invalidResponse
        }

        return text
    }
}

enum GeminiVisionError: Error, LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing Gemini API Key"
        case .imageEncodingFailed: return "Failed to encode image"
        case .requestFailed(let detail): return "Request failed: \(detail)"
        case .invalidResponse: return "Invalid response from Gemini"
        }
    }
}
