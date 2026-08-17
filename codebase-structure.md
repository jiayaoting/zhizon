# Zhizon Codebase Document

> This document is a project overview for the HarmonyOS application.

## 1. Tech Stack

- **Language**: ArkTS
- **Runtime / Framework**: HarmonyOS Stage model with ArkUI declarative UI
- **Target SDK**: HarmonyOS 6.1.1 (API 24)
- **Build system**: DevEco Studio with hvigor
- **Package manager**: ohpm 5.0+
- **Credential Encryption**: AES-256-GCM via CryptoArchitectureKit
- **Data Storage**: RelationalStore (RDB v4) with 6 persistent tables
- **LLM integration**: HTTP(S) via @kit.NetworkKit, OpenAI-compatible / Anthropic protocol, streaming (SSE) + non-streaming, thinking-mode control
- **Multi-Theme**: ThemePalette interface with 6 color themes + light/dark mode + custom backgrounds + glassmorphism toggle + global font-size scale (palette.fs*)
- **Testing**: Hypium 1.0.21 with 6 test files (Navigation, GameLaunch, Defect, WindowEnvironment)

## 2. Project Directory Structure

```text
zhizon/
├── AppScope/                  # Application-level identity, version, and shared resources
├── doc/                       # Architecture, data model, and integration documentation
│   └── DESIGN.md              # Detailed design document
├── entry/                     # HarmonyOS Stage HAP containing the application UI and services
│   └── src/
│       ├── main/
│       │   ├── ets/
│       │   │   ├── common/    # 11 files: Theme, ThemeContracts, Constants, Navigation, Difficulty, LlmModels, MarkdownConverter, AvatarOptions, CryptoHelper, DeviceMetrics, FailureHandling
│       │   │   ├── components/# 12 files: TopBar, DifficultyOption, FixedBottomNav, GlassEffect, GlobalBackgroundLayer, GameAIPanel, ParticleBackground, LockOverlay, PrivacyDialog, FontRegistry
│       │   │   ├── entryability/ # EntryAbility — startup, window, theme, safe-area, RDB init
│       │   │   ├── model/     # 2 files: GovernanceModels, Models
│       │   │   ├── pages/     # 16 pages: AppShell, Index, Games, Chat, Profile, Settings, ChatConfig, GameHistory, LegalDoc, Tetris, Game2048, Snake, Minesweeper, Sudoku, ChineseChess, AiCallLog
│       │   │   └── service/   # 15 files: DatabaseHelper, DataRepository, ChatRepository, LlmClient, GameAIService, AiCallLogger, ChineseChessEngine, SecurityService, BiometricHelper, BackgroundImporter, SudokuSolver, PickerAdapter, WindowEnvironmentProvider
│       │   └── resources/     # Module resources, profiles, strings, colors, and media
│       └── test/              # 6 unit test files
└── hvigor/                    # Repository-local HarmonyOS build tooling
```

## 3. File Statistics

| Type | Count | Description |
|------|-------|-------------|
| ArkTS source | 57 | 1 entryability + 11 common + 2 model + 15 service + 12 components + 16 pages |
| Test files | 6 | DefectClassifier, DefectWorkflow, GameLaunchFacade, NavigationFacade, WindowEnvironmentProvider, WindowEnvironmentSnapshot |
| Config | 8 | build-profile, oh-package, module.json5, etc. |
| Resources | 3 | color.json, string.json, main_pages.json |
| Documentation | 3 | README.md, doc/DESIGN.md, codebase-structure.md |
| **Total** | **~74** | |

| Metric | Value |
|--------|-------|
| Database version | v4 (6 tables) |
| Main tabs | 4 (首页/游戏/AI对话/我的) |
| Games | 6 (Tetris, 2048, Snake, Minesweeper, Sudoku, ChineseChess) |
| Difficulty levels | 5 (超简单/简单/中等/困难/地狱) |

## 4. Dev Commands (Core)

### Build Commands

```text
No command-line build command is documented. Open the project in DevEco Studio and use its Run action.
Source: README.md > 运行
```

### Test Commands

```text
6 unit test files are present under entry/src/test/. Run via DevEco Studio test runner.
Tests cover: NavigationFacade, GameLaunchFacade, DefectClassifier, DefectWorkflow, WindowEnvironmentProvider, WindowEnvironmentSnapshot.
```

### Run / Start Commands

```text
Open the project in DevEco Studio, configure signing, connect a HarmonyOS device or emulator, and click Run.
Source: README.md > 运行
```

## 5. Dev Environment (Brief)

### Prerequisites

- DevEco Studio 6.0+
- HarmonyOS SDK 6.1+ (API 24)
- ohpm 5.0+

### Configuration Notes

- `build-profile.json5` defines the single `entry` module and HarmonyOS 6.1.1 target.
- `entry/build-profile.json5` declares a Stage-model HarmonyOS HAP.
- `entry/oh-package.json5` has no external dependencies.

## 6. Key Modules

### 6.1 Game Center

- **6 games**: Tetris, Snake, Game2048, Minesweeper, Sudoku, ChineseChess
- **5 difficulty levels**: VERY_EASY / EASY / MEDIUM / HARD / HELL
- **GameLaunchFacade**: Parameter validation + route navigation
- **Game history**: Score persistence in `game_scores` RDB table
- **AI hosting**: GameAIService drives game AI (batch action decisions, non-streaming + thinking disabled)
- **Chinese Chess**: local engine (ChineseChessEngine) + 3 modes (human vs engine / human vs AI / AI vs AI)
- **Home page (Index)**: Game entry cards + best scores (clickable to history)

### 6.2 AI Chat

- **LlmClient**: HTTP communication with multiple providers (OpenAI, Anthropic, DeepSeek, Qwen, Kimi, Zhipu, Ollama, custom)
- **Thinking control**: disable reasoning mode for faster responses
- **ChatConfig**: configure provider / model / API key
- **ChatRepository**: local persistence of sessions and messages
- **Markdown rendering**: native ArkUI components (MarkdownConverter)

### 6.3 AI Call Logs

- **AiCallLogger**: records per-call summaries (start/end time, duration, type, game, model, provider, success, chars, error)
- **Scenes**: `AiCallContext` distinguishes chat / game (with game kind) / test
- **Storage**: `ai_call_logs` RDB table (id PK, ordered by start_time desc, no limit)
- **View**: AiCallLog page (list + expandable detail + clear-all with confirm dialog)
- **Entry**: Profile → AI 调用记录; clear via top-bar action

### 6.4 Multi-Theme System

- **Theme.ets**: `ThemePalette` interface (30+ color fields + 8 font sizes fsXs~fs3xl)
- **6 color themes**: CYAN / OCEAN / SUNSET / AURORA / SAKURA / FOREST
- **Light/Dark mode**: Follow system or manual override
- **Global font scale**: all pages use `palette.fs*` series, controlled by the settings font-size level
- **Custom backgrounds**: BackgroundImporter + GlobalBackgroundLayer component
- **Glassmorphism**: GlassEffect component with toggle switch
- **Preference persistence**: PreferenceSnapshot with rollback support

### 6.4 Navigation System

- **Navigation.ets**: `NavigationFacade` + `PageRegistration` registry
- **4 main nav keys**: Index, Games, Chat, Profile
- **5 registered pages**: Index, Games, Chat, Profile, Settings
- **Page availability**: EMBEDDED (in AppShell) vs ROUTE (standalone page)
- **Navigation result**: `NavigationSuccess` / `NavigationFailure` with reason codes