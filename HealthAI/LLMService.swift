import Foundation

// access to LLM being used
class LLMService: ObservableObject {
    private let apiKey = "your-api-key-here"
    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"
    
    // function utilied throughout to send prompt to LLM
    func fetchInsight(from prompt: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: endpoint) else { completion(nil); return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Using free DeepCoder 14B model
        let body: [String: Any] = [
            "model": "agentica-org/deepcoder-14b-preview:free",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // returns response
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String
            else {
                completion(nil)
                return
            }

            completion(content)
        }.resume()
    }
}

