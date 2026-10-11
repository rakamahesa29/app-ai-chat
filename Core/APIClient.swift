import Foundation

// MARK: - Configuration
enum APIConfig {
    /// Change this to your Laravel server URL
    static let baseURL = "http://localhost/api"
    
    static var token: String? {
        get { UserDefaults.standard.string(forKey: "api_token") }
        set { UserDefaults.standard.set(newValue, forKey: "api_token") }
    }
    
    static var isAuthenticated: Bool { token != nil }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
}

// MARK: - API Client
struct APIClient {
    static let shared = APIClient()
    private let session = URLSession.shared
    
    /// Dedicated session for SSE streaming with longer timeouts and connection reuse
    static let streamingSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        config.httpMaximumConnectionsPerHost = 4
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    // MARK: - Core request
    
    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil
    ) async throws -> T {
        let url = URL(string: APIConfig.baseURL + path)!
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = APIConfig.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
        }
        
        let (data, response) = try await session.data(for: req)
        
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if http.statusCode == 401 {
            APIConfig.token = nil
            throw APIError.unauthorized
        }
        
        guard (200...299).contains(http.statusCode) else {
            if let err = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.server(err.message ?? "Unknown error")
            }
            throw APIError.httpError(http.statusCode)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Multipart upload
    
    func upload(
        _ path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fields: [String: String]
    ) async throws -> BrainResponse {
        let url = URL(string: APIConfig.baseURL + path)!
        let boundary = UUID().uuidString
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = APIConfig.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        req.httpBody = body
        
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let wrapper = try decoder.decode(APIResponse<BrainResponse>.self, from: data)
        guard wrapper.status == "ok", let brain = wrapper.data else {
            throw APIError.server("Invalid response")
        }
        return brain
    }
}

// MARK: - Auth Endpoints

extension APIClient {
    func login(email: String, password: String) async throws -> AuthData {
        let wrapper: APIResponse<AuthData> = try await request(
            "/auth/login", method: .post,
            body: ["email": email, "password": password]
        )
        guard let data = wrapper.data else { throw APIError.server("No data") }
        APIConfig.token = data.token
        return data
    }
    
    func register(name: String, email: String, password: String) async throws -> AuthData {
        let wrapper: APIResponse<AuthData> = try await request(
            "/auth/register", method: .post,
            body: ["name": name, "email": email, "password": password]
        )
        guard let data = wrapper.data else { throw APIError.server("No data") }
        APIConfig.token = data.token
        return data
    }
    
    func logout() async throws {
        let _: APIResponse<Empty> = try await request("/auth/logout", method: .post)
        APIConfig.token = nil
    }
    
    func fetchUser() async throws -> UserData {
        let wrapper: APIResponse<UserData> = try await request("/auth/user")
        guard let data = wrapper.data else { throw APIError.server("No data") }
        return data
    }
}

// MARK: - Brain Endpoints

extension APIClient {
    func fetchBrains() async throws -> [BrainResponse] {
        let wrapper: APIResponse<[BrainResponse]> = try await request("/brains")
        return wrapper.data ?? []
    }
    
    func createBrain(title: String, tags: [String], customTags: [String], content: String) async throws -> BrainResponse {
        let wrapper: APIResponse<BrainResponse> = try await request(
            "/brains", method: .post,
            body: BrainCreateRequest(
                title: title, tag: tags, customTags: customTags,
                type: "text", content: content
            )
        )
        guard let data = wrapper.data else { throw APIError.server("No data") }
        return data
    }
    
    func updateBrain(id: String, title: String, tags: [String], customTags: [String], content: String) async throws -> BrainResponse {
        let wrapper: APIResponse<BrainResponse> = try await request(
            "/brains/\(id)", method: .put,
            body: BrainCreateRequest(
                title: title, tag: tags, customTags: customTags,
                type: "text", content: content
            )
        )
        guard let data = wrapper.data else { throw APIError.server("No data") }
        return data
    }
    
    func deleteBrain(id: String) async throws {
        let _: APIResponse<Empty> = try await request("/brains/\(id)", method: .delete)
    }
}

// MARK: - Chat Endpoints

extension APIClient {
    func fetchRooms() async throws -> [RoomResponse] {
        let wrapper: APIResponse<[RoomResponse]> = try await request("/chat/rooms")
        return wrapper.data ?? []
    }
    
    func createRoom(title: String, category: String, persona: String, model: String = "ollama") async throws -> RoomResponse {
        let wrapper: APIResponse<RoomResponse> = try await request(
            "/chat/rooms", method: .post,
            body: ["title": title, "category": category, "persona": persona, "model": model]
        )
        guard let data = wrapper.data else { throw APIError.server("No data") }
        return data
    }
    
    func fetchMessages(roomId: String) async throws -> [MessageResponse] {
        let wrapper: APIResponse<[MessageResponse]> = try await request("/chat/rooms/\(roomId)/messages")
        return wrapper.data ?? []
    }
    
    func deleteRoom(id: String) async throws {
        let _: APIResponse<Empty> = try await request("/chat/rooms/\(id)", method: .delete)
    }
    
    func rateMessage(id: String, rating: Int) async throws {
        let _: APIResponse<Empty> = try await request(
            "/chat/messages/\(id)/rate", method: .post,
            body: ["rating": rating]
        )
    }
    
    func deleteMessage(id: String) async throws {
        let _: APIResponse<Empty> = try await request("/chat/messages/\(id)", method: .delete)
    }
    
    // MARK: - Export Endpoints
    
    func exportGoogleDocs(messageId: String) async throws -> String {
        let wrapper: APIResponse<[String: String]> = try await request(
            "/chat/messages/\(messageId)/export-google-docs", method: .post
        )
        guard let data = wrapper.data, let url = data["url"] else {
            throw APIError.server("Failed to get Google Docs URL")
        }
        return url
    }
    
    func exportGoogleSheets(messageId: String) async throws -> String {
        let wrapper: APIResponse<[String: String]> = try await request(
            "/chat/messages/\(messageId)/export-google-sheets", method: .post
        )
        guard let data = wrapper.data, let url = data["url"] else {
            throw APIError.server("Failed to get Google Sheets URL")
        }
        return url
    }
    
    func exportDocx(messageId: String) async throws -> URL {
        let url = URL(string: "\(APIConfig.baseURL)/chat/messages/\(messageId)/export-docx")!
        var req = URLRequest(url: url)
        if let token = APIConfig.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        
        let (localURL, response) = try await URLSession.shared.download(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var fileName = "Export_\(messageId).docx"
        if let cd = http.value(forHTTPHeaderField: "Content-Disposition") {
            let parts = cd.components(separatedBy: "filename=")
            if parts.count > 1 {
                fileName = parts[1].replacingOccurrences(of: "\"", with: "")
            }
        }
        
        let dest = docs.appendingPathComponent(fileName)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.moveItem(at: localURL, to: dest)
        return dest
    }
    
    /// Returns a SSE event stream URL. Use with URLSession streaming or EventSource.
    func sendMessageStreamURL(roomId: String) -> URL {
        URL(string: "\(APIConfig.baseURL)/chat/rooms/\(roomId)/send")!
    }
    
    func sendMessageBody(
        message: String, model: String = "ollama",
        useWebSearch: Bool = false, deepseekPro: Bool = false,
        skripsiMode: Bool = false, workspacePath: String? = nil,
        chatMode: String = "ask", images: [String] = []
    ) -> Data {
        var dict: [String: Any] = [
            "message": message, "model": model, "chat_mode": chatMode,
            "use_web_search": useWebSearch,
            "deepseek_pro": deepseekPro,
            "skripsi_mode": skripsiMode
        ]
        if let path = workspacePath { dict["workspace_path"] = path }
        if !images.isEmpty { dict["images"] = images }
        return try! JSONSerialization.data(withJSONObject: dict)
    }
    
    func sendAgentContinueURL(roomId: String) -> URL {
        URL(string: "\(APIConfig.baseURL)/chat/rooms/\(roomId)/agent-continue")!
    }
    
    func sendAgentContinueBody(stateToken: String, results: [[String: Any]]) -> Data {
        let dict: [String: Any] = ["state_token": stateToken, "results": results]
        return try! JSONSerialization.data(withJSONObject: dict)
    }
}

// MARK: - Room Skills Endpoints

extension APIClient {
    /// List all skills for a given room.
    func fetchSkills(roomId: String) async throws -> [RoomSkillResponse] {
        let url = URL(string: "\(APIConfig.baseURL)/chat/rooms/\(roomId)/skills")!
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = APIConfig.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let wrapper = try decoder.decode(RoomSkillListResponse.self, from: data)
        return wrapper.skills ?? []
    }

    /// Create a manual (text) skill for a room.
    func createSkillManual(roomId: String, title: String, content: String) async throws -> RoomSkillResponse {
        let url = URL(string: "\(APIConfig.baseURL)/chat/rooms/\(roomId)/skills")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = APIConfig.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["title": title, "content": content])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String ?? obj["message"] as? String {
                throw APIError.server(msg)
            }
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let wrapper = try decoder.decode(RoomSkillMutateResponse.self, from: data)
        guard let skill = wrapper.skill else { throw APIError.server("Invalid response") }
        return skill
    }

    /// Upload a .md/.txt file as a skill.
    func createSkillFile(roomId: String, title: String, fileData: Data, fileName: String, mimeType: String) async throws -> RoomSkillResponse {
        let url = URL(string: "\(APIConfig.baseURL)/chat/rooms/\(roomId)/skills")!
        let boundary = UUID().uuidString

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = APIConfig.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        var body = Data()
        for (key, value) in ["title": title] {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String ?? obj["message"] as? String {
                throw APIError.server(msg)
            }
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let wrapper = try decoder.decode(RoomSkillMutateResponse.self, from: data)
        guard let skill = wrapper.skill else { throw APIError.server("Invalid response") }
        return skill
    }

    /// Toggle a skill's active state. Returns the new active flag.
    @discardableResult
    func toggleSkill(roomId: String, skillId: Int) async throws -> Bool {
        let url = URL(string: "\(APIConfig.baseURL)/chat/rooms/\(roomId)/skills/\(skillId)/toggle")!
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = APIConfig.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let wrapper = try decoder.decode(RoomSkillToggleResponse.self, from: data)
        return wrapper.isActive ?? false
    }

    /// Delete a skill.
    func deleteSkill(roomId: String, skillId: Int) async throws {
        let url = URL(string: "\(APIConfig.baseURL)/chat/rooms/\(roomId)/skills/\(skillId)")!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = APIConfig.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}

// MARK: - Dashboard Endpoints

extension APIClient {
    func fetchDashboardStats() async throws -> DashboardStats {
        let wrapper: APIResponse<DashboardStats> = try await request("/dashboard/stats")
        guard let data = wrapper.data else { throw APIError.server("No data") }
        return data
    }
    
    func fetchActivity() async throws -> [ActivityPoint] {
        let wrapper: APIResponse<[ActivityPoint]> = try await request("/dashboard/activity")
        return wrapper.data ?? []
    }
    
    func updateProviderMode(provider: String, enabled: Bool) async throws {
        let _: APIResponse<Empty> = try await request(
            "/dashboard/provider-mode", method: .post,
            body: ["provider": provider, "enabled": String(enabled)]
        )
    }
    
    func clearLocks() async throws {
        let _: APIResponse<Empty> = try await request("/admin/clear-locks", method: .post, body: ["":""] as [String:String])
    }
    
    func fetchGraphData(roomId: Int? = nil) async throws -> GraphData {
        var path = "/dashboard/graph-data"
        if let rid = roomId { path += "?room_id=\(rid)" }
        let wrapper: APIResponse<GraphData> = try await request(path)
        guard let data = wrapper.data else { throw APIError.server("No graph data") }
        return data
    }
    
    func fetchGraphRooms() async throws -> [GraphRoomData] {
        let wrapper: APIResponse<[GraphRoomData]> = try await request("/dashboard/graph-rooms")
        return wrapper.data ?? []
    }
    
    func fetchGraphStats() async throws -> GraphStatsData {
        let wrapper: APIResponse<GraphStatsData> = try await request("/dashboard/graph-stats")
        guard let data = wrapper.data else { throw APIError.server("No graph stats") }
        return data
    }
}

// MARK: - Settings Endpoints

extension APIClient {
    func fetchSettings() async throws -> SettingsData {
        let wrapper: APIResponse<SettingsData> = try await request("/settings")
        guard let data = wrapper.data else { throw APIError.server("No data") }
        return data
    }
    
    func updateSettings(_ dict: [String: String]) async throws {
        let body = try JSONSerialization.data(withJSONObject: dict)
        
        let url = URL(string: APIConfig.baseURL + "/settings")!
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = APIConfig.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }
}

// MARK: - Models

struct APIResponse<T: Decodable>: Decodable {
    let status: String
    let data: T?
    let message: String?
}

struct APIErrorResponse: Decodable {
    let message: String?
}

struct Empty: Decodable {}

// Auth
struct AuthData: Decodable {
    let user: UserData
    let token: String
}

struct UserData: Decodable {
    let id: Int?
    let name: String
    let email: String
    let role: String?
    let createdAt: String?
}

// Brain
struct BrainResponse: Decodable, Identifiable {
    let id: Int?
    let title: String
    let type: String?
    let tag: [String]?
    let content: String?
    let filePath: String?
    let isIndexed: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    var stringId: String { id.map(String.init) ?? UUID().uuidString }
    
    func toDocument() -> BrainDocument {
        BrainDocument(
            id: stringId,
            title: title,
            type: (type == "pdf") ? .pdf : .text,
            content: content ?? "",
            tags: tag ?? [],
            createdAt: ISO8601DateFormatter().date(from: createdAt ?? "") ?? Date()
        )
    }
}

struct BrainCreateRequest: Encodable {
    let title: String
    let tag: [String]
    let customTags: [String]
    let type: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case title, tag, type, content
        case customTags = "custom_tags"
    }
}

// Chat
struct RoomResponse: Decodable, Identifiable {
    let id: Int
    let title: String
    let category: String?
    let persona: String?
    let model: String?
    let createdAt: String?
    let updatedAt: String?
    let messages: [MessageResponse]?
    
    func toChatRoom() -> ChatRoom {
        ChatRoom(
            id: String(id),
            title: title,
            category: category ?? "General",
            persona: persona ?? "general",
            model: model ?? "ollama",
            createdAt: ISO8601DateFormatter().date(from: createdAt ?? "") ?? Date()
        )
    }
}

struct MessageResponse: Decodable, Identifiable {
    let id: Int
    let content: String
    let senderType: String
    let satisfactionScore: Int?
    let tokensUsed: Int?
    let createdAt: String?
}

// Room Skills
struct RoomSkillResponse: Decodable, Identifiable, Equatable {
    let id: Int
    let roomId: Int?
    let title: String
    let content: String?
    let sourceType: String?          // "manual_input" | "file_upload"
    let originalFilename: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?

    var isManual: Bool { (sourceType ?? "manual_input") == "manual_input" }
}

struct RoomSkillListResponse: Decodable {
    let status: String?
    let skills: [RoomSkillResponse]?
}

struct RoomSkillMutateResponse: Decodable {
    let status: String?
    let message: String?
    let skill: RoomSkillResponse?
}

struct RoomSkillToggleResponse: Decodable {
    let status: String?
    let isActive: Bool?
    let message: String?
}

// Dashboard
struct DashboardStats: Decodable {
    let avgMemoryKb: Double?
    let avgBotTokens: Int?
    let avgUserTokens: Int?
    let successRate: Int?
    let totalMessages: Int?
    let graphNodes: Int?
    let graphEdges: Int?
    let providers: ProvidersData?
}

struct ProvidersData: Decodable {
    let ollamaEnabled: Bool?
    let ollamaCloudEnabled: Bool?
    let deepseekEnabled: Bool?
}

struct ActivityPoint: Decodable {
    let day: String
    let count: Int
}

// Settings
struct SettingsData: Decodable {
    let ollamaEnabled: Bool?
    let ollamaLocalUrl: String?
    let ollamaLocalModel: String?
    let ollamaCloudEnabled: Bool?
    let ollamaCloudUrl: String?
    let ollamaCloudModel: String?
    let deepseekEnabled: Bool?
    let deepseekApiKey: String?
    let deepseekFlashModel: String?
    let deepseekProModel: String?
    let deepseekReasoning: String?
    let embeddingModel: String?
    let ragEnabled: Bool?
    let ragChunkSize: Int?
    let ragTopK: Int?
    let knowledgeGraphEnabled: Bool?
    let webSearchEnabled: Bool?
    let tavilyApiKey: String?
    let darkMode: Bool?
}

// Knowledge Graph
struct GraphData: Decodable {
    let nodes: [GraphNodeRaw]
    let edges: [GraphEdgeRaw]
}

struct GraphNodeRaw: Decodable {
    let id: Int
    let label: String
    let title: String?
    let value: Int?
    let color: String?
    let group: String?
    let roomId: Int?
}

struct GraphEdgeRaw: Decodable {
    let from: Int
    let to: Int
    let label: String?
    let title: String?
    let value: Double?
    let dashes: Bool?
}

struct GraphStatsData: Decodable {
    let totalNodes: Int?
    let totalEdges: Int?
    let roomsWithGraphs: Int?
    let totalTokensSaved: Int?
    let avgDegree: Double?
    let nodesByType: [String: Int]?
    let indexProgress: Double?
}

struct GraphRoomData: Decodable, Identifiable {
    let id: Int
    let title: String
    let nodeCount: Int?
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case server(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Session expired. Please log in again."
        case .httpError(let code): return "Server error (\(code))"
        case .server(let msg): return msg
        }
    }
}

// MARK: - Helpers

struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
