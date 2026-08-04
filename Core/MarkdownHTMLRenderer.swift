import Foundation

/// Converts a subset of Markdown to HTML suitable for WKWebView rendering.
/// Supports: headings, bold, lists (ordered/unordered), tables, code blocks, inline code, hr, line breaks.
enum MarkdownHTMLRenderer {
    
    static func render(_ markdown: String) -> String {
        var html = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        
        // 1. Fenced code blocks ```lang\n...\n``` → <pre><code>
        html = html.replacingOccurrences(of: "```(\\w*)\\n([\\s\\S]*?)```",
                                          with: "<pre><code>$2</code></pre>",
                                          options: .regularExpression)
        
        // 2. Inline code `text` → <code>text</code>
        html = html.replacingOccurrences(of: "`([^`]+)`",
                                          with: "<code>$1</code>",
                                          options: .regularExpression)
        
        // 3. Bold **text** → <strong>text</strong>
        html = html.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*",
                                          with: "<strong>$1</strong>",
                                          options: .regularExpression)
        
        // 4. Headings (###, ##, #) — must be at line start
        html = html.replacingOccurrences(of: "(?m)^### (.+)$",
                                          with: "<h3>$1</h3>",
                                          options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^## (.+)$",
                                          with: "<h2>$1</h2>",
                                          options: .regularExpression)
        html = html.replacingOccurrences(of: "(?m)^# (.+)$",
                                          with: "<h1>$1</h1>",
                                          options: .regularExpression)
        
        // 5. Horizontal rules (---, ***, ___) — must be alone on a line
        html = html.replacingOccurrences(of: "(?m)^[-*_]{3,}\\s*$",
                                          with: "<hr>",
                                          options: .regularExpression)
        
        // 6. Tables: split by newlines, detect |...| rows
        html = convertTables(html)
        
        // 7. Unordered lists (- or * at line start)
        html = convertUnorderedLists(html)
        
        // 8. Ordered lists (1. at line start)
        html = convertOrderedLists(html)
        
        // 9. Paragraphs: double-newline → paragraph break, single newline → <br>
        let paragraphs = html.components(separatedBy: "\n\n")
        html = paragraphs.map { p in
            let trimmed = p.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }
            // Skip wrapping if already a block element
            if trimmed.hasPrefix("<h") || trimmed.hasPrefix("<table") || trimmed.hasPrefix("<ul") || trimmed.hasPrefix("<ol") || trimmed.hasPrefix("<pre") || trimmed.hasPrefix("<hr") || trimmed.hasPrefix("<blockquote") {
                return trimmed
            }
            // Wrap in <p>, preserve single newlines as <br>
            let withBreaks = trimmed.replacingOccurrences(of: "\n", with: "<br>")
            return "<p>\(withBreaks)</p>"
        }.joined(separator: "\n")
        
        return html
    }
    
    // MARK: - Tables
    
    private static func convertTables(_ html: String) -> String {
        let lines = html.components(separatedBy: "\n")
        var result: [String] = []
        var tableRows: [String] = []
        var inTable = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                // Check if it's a separator row (|---|...|)
                if trimmed.range(of: #"^\|[\s\-:]+\|"#, options: .regularExpression) != nil {
                    // Separator row — skip but mark as in-table
                    if !inTable && !tableRows.isEmpty {
                        // This means the previous lines were actually table rows started without a header
                        tableRows.append(trimmed)
                    }
                    inTable = true
                    continue
                }
                tableRows.append(trimmed)
                inTable = true
            } else {
                if inTable && !tableRows.isEmpty {
                    result.append(buildTable(tableRows))
                    tableRows.removeAll()
                    inTable = false
                }
                result.append(line)
            }
        }
        // Flush remaining table
        if !tableRows.isEmpty {
            result.append(buildTable(tableRows))
        }
        
        return result.joined(separator: "\n")
    }
    
    private static func buildTable(_ rows: [String]) -> String {
        guard !rows.isEmpty else { return "" }
        var html = "<table>"
        let isHeader = rows.count > 1
        
        for (i, row) in rows.enumerated() {
            let tag = (i == 0 && isHeader) ? "th" : "td"
            let cells = row
                .split(separator: "|", omittingEmptySubsequences: false)
                .dropFirst()  // drop leading empty
                .dropLast()   // drop trailing empty
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            html += "<tr>"
            for cell in cells {
                html += "<\(tag)>\(cell)</\(tag)>"
            }
            html += "</tr>"
        }
        html += "</table>"
        return html
    }
    
    // MARK: - Lists
    
    private static func convertUnorderedLists(_ html: String) -> String {
        // TODO: nested list support — current implementation flattens all
        // items into a single top-level <ul>, ignoring leading indentation.
        let lines = html.components(separatedBy: "\n")
        var result: [String] = []
        var listItems: [String] = []
        var inList = false
        
        for line in lines {
            if let match = line.firstMatch(of: try! Regex("^\\s*[-*] (.+)$")) {
                let content = String(match.output[1].substring ?? "")
                listItems.append("<li>\(content)</li>")
                inList = true
            } else {
                if inList {
                    result.append("<ul>\(listItems.joined())</ul>")
                    listItems.removeAll()
                    inList = false
                }
                result.append(line)
            }
        }
        if inList {
            result.append("<ul>\(listItems.joined())</ul>")
        }
        return result.joined(separator: "\n")
    }
    
    private static func convertOrderedLists(_ html: String) -> String {
        // TODO: nested list support — current implementation flattens all
        // items into a single top-level <ol>, ignoring leading indentation.
        let lines = html.components(separatedBy: "\n")
        var result: [String] = []
        var listItems: [String] = []
        var inList = false
        
        for line in lines {
            if let match = line.firstMatch(of: try! Regex("^\\s*\\d+\\. (.+)$")) {
                let content = String(match.output[1].substring ?? "")
                listItems.append("<li>\(content)</li>")
                inList = true
            } else {
                if inList {
                    result.append("<ol>\(listItems.joined())</ol>")
                    listItems.removeAll()
                    inList = false
                }
                result.append(line)
            }
        }
        if inList {
            result.append("<ol>\(listItems.joined())</ol>")
        }
        return result.joined(separator: "\n")
    }
}
