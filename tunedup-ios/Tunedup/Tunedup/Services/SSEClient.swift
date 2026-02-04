import Foundation

// MARK: - SSE Client
// Server-Sent Events client for build generation progress

class SSEClient: NSObject, URLSessionDataDelegate {
    private var session: URLSession!
    private var task: URLSessionDataTask?
    private var buffer = ""

    #if DEBUG
    private let baseURL = "http://localhost:3000"
    #else
    private let baseURL = "https://api.tunedup.dev"
    #endif

    var onProgress: ((PipelineProgress) -> Void)?
    var onComplete: ((String) -> Void)? // buildId
    var onError: ((PipelineError) -> Void)?

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180 // Pipeline can take time
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    // MARK: - Start Build

    func startBuild(vehicle: VehicleInput, intent: IntentInput, token: String) {
        guard let url = URL(string: "\(baseURL)/api/builds") else {
            onError?(PipelineError(step: nil, error: "Invalid URL", partial: false, buildId: nil))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body = BuildRequest(vehicle: vehicle, intent: intent)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            onError?(PipelineError(step: nil, error: "Failed to encode request", partial: false, buildId: nil))
            return
        }

        buffer = ""
        task = session.dataTask(with: request)
        task?.resume()
    }

    // MARK: - Cancel

    func cancel() {
        task?.cancel()
        task = nil
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        // Parse SSE events (separated by double newlines)
        let events = buffer.components(separatedBy: "\n\n")

        // Keep the last incomplete event in the buffer
        buffer = events.last ?? ""

        // Process all complete events
        for event in events.dropLast() {
            if !event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parseEvent(event)
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error as? URLError, error.code == .cancelled {
            // Task was cancelled, ignore
            return
        }

        if let error = error {
            onError?(PipelineError(
                step: nil,
                error: error.localizedDescription,
                partial: false,
                buildId: nil
            ))
        }
    }

    // MARK: - Event Parsing

    private func parseEvent(_ raw: String) {
        var eventType = ""
        var eventData = ""

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("event:") {
                eventType = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("data:") {
                eventData = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            }
        }

        guard !eventType.isEmpty, !eventData.isEmpty,
              let data = eventData.data(using: .utf8) else {
            return
        }

        let decoder = JSONDecoder()

        switch eventType {
        case "progress":
            if let progress = try? decoder.decode(PipelineProgress.self, from: data) {
                onProgress?(progress)
            }

        case "complete":
            if let result = try? decoder.decode(BuildComplete.self, from: data) {
                onComplete?(result.buildId)
            }

        case "error":
            if let error = try? decoder.decode(PipelineError.self, from: data) {
                onError?(error)
            }

        default:
            break
        }
    }
}
