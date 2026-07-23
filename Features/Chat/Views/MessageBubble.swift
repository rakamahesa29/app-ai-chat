import SwiftUI

struct MessageBubble: View {
    let content: String
    let isUser: Bool
    let hasWebContext: Bool
    let hasReasoning: Bool
    let reasoningContent: String?
    let isStreaming: Bool
    let isEducationEval: Bool
    let evalData: ThesisEvalData?
    
    @State private var isReasoningExpanded = false
    
    init(
        content: String,
        isUser: Bool,
        hasWebContext: Bool = false,
        hasReasoning: Bool = false,
        reasoningContent: String? = nil,
        isStreaming: Bool = false,
        isEducationEval: Bool = false,
        evalData: ThesisEvalData? = nil
    ) {
        self.content = content
        self.isUser = isUser
        self.hasWebContext = hasWebContext
        self.hasReasoning = hasReasoning
        self.reasoningContent = reasoningContent
        self.isStreaming = isStreaming
        self.isEducationEval = isEducationEval
        self.evalData = evalData
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: HermesSpacing.sm) {
                // Reasoning block (collapsible)
                if hasReasoning, let reasoning = reasoningContent, !reasoning.isEmpty {
                    reasoningBlock(reasoning)
                }
                
                // Message Content
                VStack(alignment: .leading, spacing: HermesSpacing.sm) {
                    formattedContent
                }
                .padding(HermesSpacing.md)
                .background(isUser ? Color.hermes.card : Color.clear)
                .cornerRadius(HermesRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: HermesRadius.lg)
                        .strokeBorder(isUser ? Color.hermes.border : Color.clear, lineWidth: isUser ? 1 : 0)
                )
                
                // Web context badge
                if hasWebContext && isUser {
                    webContextBadge
                }
                
                // Education evaluation
                if isEducationEval, let eval = evalData {
                    educationEvalCard(eval)
                }
                
                // Streaming indicator
                if isStreaming {
                    streamingIndicator
                }
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
    
    // MARK: - Reasoning Block
    private func reasoningBlock(_ reasoning: String) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isReasoningExpanded.toggle()
                }
            }) {
                HStack(spacing: HermesSpacing.sm) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11))
                    Text("Reasoning")
                        .font(.hermes.captionMedium)
                    Spacer()
                    Image(systemName: isReasoningExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, HermesSpacing.md)
                .padding(.vertical, HermesSpacing.sm)
                .background(Color.purple.opacity(0.08))
                .cornerRadius(HermesRadius.md)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isReasoningExpanded {
                Text(reasoning)
                    .font(.hermes.mono)
                    .foregroundColor(.hermes.muted)
                    .padding(HermesSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.04))
                    .cornerRadius(HermesRadius.sm)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.md)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Formatted Content
    @ViewBuilder
    private var formattedContent: some View {
        let blocks = parseContentBlocks(content)
        
        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
            switch block {
            case .text(let text):
                Text(.init(text))
                    .font(.hermes.body)
                    .foregroundColor(isUser ? .hermes.text : .hermes.text)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                
            case .code(let code, let language):
                codeBlock(code, language: language)
                
            case .inlineCode(let code):
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.hermes.accent)
                    .padding(.horizontal, HermesSpacing.xs)
                    .padding(.vertical, 1)
                    .background(Color.hermes.accent.opacity(0.1))
                    .cornerRadius(HermesRadius.sm)
            }
        }
    }
    
    private func codeBlock(_ code: String, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language header
            if let lang = language, !lang.isEmpty {
                HStack {
                    HStack(spacing: HermesSpacing.xs) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Circle().fill(Color.yellow).frame(width: 8, height: 8)
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                    }
                    
                    Spacer()
                    
                    Text(lang)
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.muted)
                }
                .padding(.horizontal, HermesSpacing.md)
                .padding(.vertical, HermesSpacing.sm)
                .background(Color.black.opacity(0.05))
            }
            
            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.hermes.text)
                    .padding(HermesSpacing.md)
            }
        }
        .background(Color.hermes.bg)
        .cornerRadius(HermesRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.md)
                .strokeBorder(Color.hermes.border, lineWidth: 1)
        )
    }
    
    // MARK: - Web Context Badge
    private var webContextBadge: some View {
        HStack(spacing: HermesSpacing.xs) {
            Image(systemName: "globe")
                .font(.system(size: 10))
            Text("Web Search")
        }
        .font(.hermes.badge)
        .padding(.horizontal, HermesSpacing.sm)
        .padding(.vertical, HermesSpacing.xs)
        .background(Color.hermes.success.opacity(0.15))
        .foregroundColor(.hermes.success)
        .cornerRadius(HermesRadius.sm)
    }
    
    // MARK: - Education Eval Card
    private func educationEvalCard(_ eval: ThesisEvalData) -> some View {
        VStack(alignment: .leading, spacing: HermesSpacing.md) {
            HStack(spacing: HermesSpacing.sm) {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
                Text("Thesis Evaluation")
                    .font(.hermes.bodyMedium)
                    .foregroundColor(.hermes.text)
            }
            
            // Scores grid
            if hasAnyScores(eval) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: HermesSpacing.sm
                ) {
                    if let score = eval.bab1Score { evalScoreBadge("Bab 1", score: score) }
                    if let score = eval.bab2Score { evalScoreBadge("Bab 2", score: score) }
                    if let score = eval.bab3Score { evalScoreBadge("Bab 3", score: score) }
                    if let score = eval.bab4Score { evalScoreBadge("Bab 4", score: score) }
                    if let score = eval.bab5Score { evalScoreBadge("Bab 5", score: score) }
                    if let score = eval.coherenceScore { evalScoreBadge("Coherence", score: score) }
                }
            }
            
            // Strengths
            if !eval.strengths.isEmpty {
                evalSection("Strengths", items: eval.strengths, color: .hermes.success)
            }
            
            // Weaknesses
            if !eval.weaknesses.isEmpty {
                evalSection("Weaknesses", items: eval.weaknesses, color: .hermes.danger)
            }
            
            // Recommendations
            if !eval.recommendations.isEmpty {
                evalSection("Recommendations", items: eval.recommendations, color: .hermes.accent)
            }
        }
        .padding(HermesSpacing.md)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(HermesRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: HermesRadius.md)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func hasAnyScores(_ eval: ThesisEvalData) -> Bool {
        eval.bab1Score != nil || eval.bab2Score != nil || eval.bab3Score != nil ||
        eval.bab4Score != nil || eval.bab5Score != nil || eval.coherenceScore != nil
    }
    
    private func evalScoreBadge(_ label: String, score: Double) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f", score))
                .font(.hermes.bodyMedium)
                .foregroundColor(scoreColor(score))
            Text(label)
                .font(.hermes.badge)
                .foregroundColor(.hermes.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HermesSpacing.sm)
        .background(scoreColor(score).opacity(0.1))
        .cornerRadius(HermesRadius.sm)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 { return .hermes.success }
        if score >= 60 { return .hermes.warning }
        return .hermes.danger
    }
    
    private func evalSection(_ title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: HermesSpacing.xs) {
            Text(title.uppercased())
                .font(.hermes.badge)
                .foregroundColor(color)
            
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: HermesSpacing.sm) {
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)
                    Text(item)
                        .font(.hermes.caption)
                        .foregroundColor(.hermes.text)
                }
            }
        }
    }
    
    // MARK: - Streaming Indicator
    private var streamingIndicator: some View {
        HStack(spacing: HermesSpacing.xs) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .hermes.muted))
                .scaleEffect(0.6)
        }
    }
}

// MARK: - Content Parsing

enum ContentBlock: Equatable {
    case text(String)
    case code(String, language: String?)
    case inlineCode(String)
}

/// Simple parser that splits content into text, fenced code blocks, and inline code.
func parseContentBlocks(_ content: String) -> [ContentBlock] {
    var blocks: [ContentBlock] = []
    var remaining = content
    
    while !remaining.isEmpty {
        // Check for fenced code block: ```language\n...\n```
        if let codeMatch = remaining.firstMatch(of: try! Regex("```(\\w*)\\n([\\s\\S]*?)```")) {
            // Text before code block
            let rangeBefore = remaining.startIndex..<codeMatch.range.lowerBound
            if rangeBefore.lowerBound < rangeBefore.upperBound {
                let textBefore = String(remaining[rangeBefore])
                blocks.append(.text(textBefore))
            }
            
            // Code block
            let output = codeMatch.output
            let lang = output[1].substring.map { String($0) } ?? ""
            let code = String(output[2].substring ?? "")
            blocks.append(.code(code.trimmingCharacters(in: CharacterSet.newlines), language: lang.isEmpty ? nil : lang))
            
            remaining = String(remaining[codeMatch.range.upperBound...])
        } else {
            // Check for inline code: `code`
            if let inlineMatch = remaining.firstMatch(of: try! Regex("`([^`]+)`")) {
                let rangeBefore = remaining.startIndex..<inlineMatch.range.lowerBound
                if rangeBefore.lowerBound < rangeBefore.upperBound {
                    blocks.append(.text(String(remaining[rangeBefore])))
                }
                
                let code = String(inlineMatch.output[1].substring ?? "")
                blocks.append(.inlineCode(code))
                
                remaining = String(remaining[inlineMatch.range.upperBound...])
            } else {
                // Remaining text
                blocks.append(.text(remaining))
                remaining = ""
            }
        }
    }
    
    return blocks
}

// MARK: - Helper for iOS 15 compatibility
// Regex-based parsing uses Swift 5.7+ Regex; if building for iOS 15, 
// fall back to NSRegularExpression

#if swift(<5.7)
private func parseWithNSRegularExpression(_ content: String) -> [ContentBlock] {
    // Fallback implementation using NSRegularExpression
    var blocks: [ContentBlock] = []
    let pattern = "```(\\w*)\\n([\\s\\S]*?)```|`([^`]+)`"
    
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        blocks.append(.text(content))
        return blocks
    }
    
    let nsString = content as NSString
    let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
    
    var lastEnd = 0
    for match in matches {
        // Text before match
        if match.range.lowerBound > lastEnd {
            let textRange = NSRange(location: lastEnd, length: match.range.lowerBound - lastEnd)
            blocks.append(.text(nsString.substring(with: textRange)))
        }
        
        // Fenced code block
        if match.range(at: 1).location != NSNotFound {
            let lang = match.range(at: 1).length > 0 ? nsString.substring(with: match.range(at: 1)) : nil
            let code = nsString.substring(with: match.range(at: 2))
            blocks.append(.code(code.trimmingCharacters(in: .newlines), language: lang))
        }
        // Inline code
        else if match.range(at: 3).location != NSNotFound {
            blocks.append(.inlineCode(nsString.substring(with: match.range(at: 3))))
        }
        
        lastEnd = match.range.upperBound
    }
    
    // Remaining text
    if lastEnd < nsString.length {
        let textRange = NSRange(location: lastEnd, length: nsString.length - lastEnd)
        blocks.append(.text(nsString.substring(with: textRange)))
    }
    
    return blocks
}
#endif

#Preview {
    VStack(spacing: 20) {
        MessageBubble(
            content: "Hello, how can I help you today?",
            isUser: false,
            hasReasoning: true,
            reasoningContent: "Analyzing user intent...\nDetected: greeting\nConfidence: 0.98"
        )
        
        MessageBubble(
            content: "Can you explain **SwiftUI**?\n\n```swift\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello\")\n    }\n}\n```\n\nUse `@State` for local state.",
            isUser: true,
            hasWebContext: true
        )
        
        MessageBubble(
            content: "Here is the analysis of your methodology.",
            isUser: false,
            isEducationEval: true,
            evalData: ThesisEvalData(
                bab1Score: 85,
                bab2Score: 72,
                bab3Score: 90,
                coherenceScore: 78,
                strengths: ["Clear research gap", "Good structure"],
                weaknesses: ["Needs more citations"],
                recommendations: ["Add 3-5 recent papers from 2024"]
            )
        )
    }
    .padding()
    .background(Color.hermes.bg)
}
