# Omoikane AI — SwiftUI Client

A native macOS/iOS SwiftUI client for the Omoikane AI Chat backend (Laravel). Provides a rich chat interface with SSE streaming, agent mode with local file operations, knowledge base management, and a full dashboard with knowledge graph visualization.

## Tech Stack

- **UI:** SwiftUI (macOS 14+ / iOS 17+)
- **Networking:** URLSession async/await + SSE streaming
- **Auth:** Bearer token (Laravel Sanctum) via UserDefaults
- **Rendering:** WKWebView for Markdown/HTML (MarkdownWebView)
- **Voice:** Speech framework (STT) + AVSpeechSynthesizer (TTS)
- **Design System:** Hermes (custom tokens for colors, typography, spacing, components)
- **Backend:** Laravel REST API at `http://localhost/api`

## Features

### Multi-Provider Chat
- **Three LLM backends** switchable per-message: Ollama local, Ollama Cloud, and DeepSeek API.
- **DeepSeek Pro Mode:** Toggle to enable chain-of-thought reasoning with collapsible thinking blocks.
- **Real-time SSE streaming** with dedicated `URLSessionConfiguration` optimized for long-running AI responses (5-min request timeout, 10-min resource timeout, 4 concurrent connections per host).
- **Agent Mode (True Agentic Loop):** Client-side tool execution loop (read/write/delete/list files) capable of executing up to 30 continuous iterations automatically for massive file generation, complete with a real-time collapsible activity log.
- **Room Skills:** Per-room custom instructions with CRUD management via API.

### Adaptive Chat Interface
- **NavigationSplitView** on macOS/iPad, **TabView** on iPhone.
- Tabs: Dashboard, Chat, Brain (Knowledge Base), Files.
- **Rich message rendering** natively at 60fps via `swift-markdown-ui` (no heavy WebViews), delivering a buttery smooth chat scrolling experience even during intensive AI streaming.
- **Voice input** (microphone) and **voice output** (speaker) via on-device Speech framework.
- **Code paste** and **file upload** via attachment menu.
- **Message actions:** Rate (thumbs up/down), delete.

### Knowledge Base (Brain)
- Full CRUD for knowledge documents: create (text or PDF), edit, delete.
- Tag-based filtering by persona and custom tags.
- Inline rich text editing.

### Dashboard
- Stats cards: memory usage, token counts, success rate, graph stats.
- 7-day activity chart.
- Provider toggles (Ollama, Ollama Cloud, DeepSeek).
- **Knowledge Graph visualization** with room filtering and interactive node/edge display.

### Settings
- Provider configuration (URLs, models, API keys).
- RAG and Knowledge Graph toggle.
- Dark mode toggle.
- Account management.

## Architecture

```
Omoikane/
├── App/
│   └── OmoikaneApp.swift               # @main entry point
├── Core/
│   ├── APIClient.swift                  # REST + SSE networking, streaming session config
│   ├── AppState.swift                   # Global auth/session state
│   ├── Models.swift                     # Domain models
│   ├── MarkdownHTMLRenderer.swift       # Markdown-to-HTML converter
│   ├── SpeechRecognizer.swift           # On-device STT
│   ├── SpeechSynthesizer.swift          # On-device TTS
│   └── DesignSystem/
│       ├── HermesTheme.swift            # Color, typography, spacing tokens
│       └── HermesComponents.swift       # Reusable UI components
├── Features/
│   ├── AuthenticatedContainerView.swift # Main shell (sidebar + tabs)
│   ├── Chat/Views/
│   │   ├── ChatRoomView.swift           # Core chat view with SSE streaming
│   │   ├── ChatCreateView.swift         # New room form
│   │   ├── ComposerView.swift           # Input bar (text, voice, files, code)
│   │   ├── MarkdownWebView.swift        # WKWebView wrapper with height cache
│   │   └── RoomSkillsSheet.swift        # Per-room skills manager
│   ├── Dashboard/Views/
│   │   ├── DashboardView.swift          # Stats, charts, provider toggles
│   │   └── KnowledgeGraphView.swift     # Graph visualization
│   ├── KnowledgeBase/Views/
│   │   ├── BrainManagerView.swift       # Knowledge docs list
│   │   ├── BrainCreateView.swift        # Add knowledge
│   │   └── BrainEditView.swift          # Edit knowledge
│   ├── FileBrowser/Views/
│   │   └── FileBrowserView.swift        # Local file explorer (agent mode)
│   ├── Settings/Views/
│   │   └── SettingsView.swift           # Full settings
│   └── Sidebar/Views/
│       └── SidebarView.swift            # Room list
└── Resources/
    ├── Assets.xcassets/                 # Colors + app icons
    └── Fonts/                           # Inter font family
```

## Design System (Hermes)

| Token | Usage |
|-------|-------|
| `Color.hermes.accent` | Primary accent color |
| `Color.hermes.bg / .surface / .card` | Background layers |
| `Color.hermes.text / .muted` | Text hierarchy |
| `Color.hermes.success / .warning / .danger` | Status colors |
| `Font.hermes.h1 / .h2 / .h3` | Headings |
| `Font.hermes.body / .bodyMedium` | Body text |
| `Font.hermes.caption / .mono` | Small text / code |
| `HermesSpacing.xs(4) ... .xxxl(48)` | Spacing scale |
| `HermesRadius.sm(6) ... .xl(16)` | Border radius |

**Conventions:**
- All icons use **SF Symbols outline variants only** (never `.fill`). Active/toggle states change color only.
- All buttons use `.buttonStyle(PlainButtonStyle())` to avoid platform chrome.
- Cards use `HermesCard` with 1px border stroke.

## Networking

All API calls go through `APIClient.shared`. Two URLSession configurations:

| Session | Purpose | Timeouts |
|---------|---------|----------|
| `URLSession.shared` | REST API calls (auth, CRUD, settings) | System defaults |
| `APIClient.streamingSession` | SSE chat streaming + agent continuation | 300s request / 600s resource / 4 connections per host |

Auth token is stored in `UserDefaults` and automatically cleared on 401 responses.

## Setup

1. Build and run the Xcode project targeting macOS 14+ or iOS 17+.
2. Ensure the Laravel backend (`ai-chat-app`) is running at `http://localhost/api`.
3. Register or log in via the app's auth flow.

To change the backend URL, edit `APIConfig.baseURL` in `Core/APIClient.swift`.

## License

This project is proprietary software.
