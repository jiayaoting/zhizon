# Zhizon Codebase Document

> This document is a project overview for the HarmonyOS application and its companion agent.

## 1. Tech Stack

- **Language**: ArkTS for the HarmonyOS application; Go 1.21+ for the optional server agent
- **Runtime / Framework**: HarmonyOS Stage model with ArkUI declarative UI
- **Target SDK**: HarmonyOS 6.1.1 (API 24)
- **Build system**: DevEco Studio with hvigor
- **Package manager**: ohpm 5.0+
- **SSH Communication**: Dual-mode — `@ohos/libssh` direct connection + Go Agent (HTTP/WebSocket)
- **Credential Encryption**: AES-256-GCM via CryptoArchitectureKit
- **Data Storage**: RelationalStore (RDB v4) with 10 persistent tables
- **Multi-Theme**: ThemePalette interface with 6 color themes + light/dark mode + custom backgrounds
- **Terminal Rendering**: AnsiParser + TerminalBuffer + TerminalView custom components
- **Testing**: Hypium 1.0.21 with 8 test files (Navigation, GameLaunch, Defect, Remote, WindowEnvironment)

## 2. Project Directory Structure

```text
zhizon/
├── AppScope/                  # Application-level identity, version, and shared resources
├── agent/                     # Optional Go HTTP and WebSocket agent for managed Linux servers
│   ├── go.mod
│   ├── go.sum
│   └── main.go                # 1001 lines — HTTP + WebSocket service (11 endpoints)
├── doc/                       # Architecture, data model, and integration documentation
│   └── DESIGN.md              # Detailed design document (v4.0.0)
├── entry/                     # HarmonyOS Stage HAP containing the application UI and services
│   └── src/
│       ├── main/
│       │   ├── ets/
│       │   │   ├── common/    # 7 files: Theme, ThemeContracts, Constants, Navigation, CryptoHelper, Difficulty, FailureHandling
│       │   │   ├── components/# 9 files: NavSidebar, TopBar, StatusBadge, ProgressBar, MetricCard, EmptyState, DifficultyOption, FixedBottomNav, GlobalBackgroundLayer
│       │   │   ├── entryability/ # EntryAbility — startup, window, theme, safe-area, RDB init
│       │   │   ├── model/     # 2 files: Models (17 interfaces + 2 types), GovernanceModels (defect tracking + remote results + preferences)
│       │   │   ├── pages/     # 20 pages: AppShell, Index, Servers, ServerDetail, ServerForm, Terminal, Files, Pve, PveNodeDetail, VmDetail, Commands, Batch, Alerts, Settings, More, Games, Tetris, Game2048, Snake, GameHistory
│       │   │   ├── service/   # 13 files: DatabaseHelper, DataRepository, SshService, PveService, BackgroundImporter, WindowEnvironmentProvider, DefectWorkflow, DefectClassifier, PickerAdapter, PveTransportAdapter, RemoteOperation, RemoteResultAdapter, SshService_new
│       │   │   └── terminal/  # 3 files: AnsiParser, TerminalBuffer, TerminalView
│       │   └── resources/     # Module resources, profiles, strings, colors, and media
│       └── test/              # 8 unit test files
└── hvigor/                    # Repository-local HarmonyOS build tooling
```

## 3. File Statistics

| Type | Count | Description |
|------|-------|-------------|
| ArkTS source | 55 | 1 entryability + 7 common + 2 model + 13 service + 3 terminal + 9 components + 20 pages |
| Test files | 8 | DefectClassifier, DefectWorkflow, GameLaunchFacade, NavigationFacade, RemoteOperation, RemoteResultAdapter, WindowEnvironmentProvider, WindowEnvironmentSnapshot |
| Go Agent | 3 | go.mod, go.sum, main.go |
| Config | 8 | build-profile, oh-package, module.json5, etc. |
| Resources | 3 | color.json, string.json, main_pages.json |
| Documentation | 3 | README.md, doc/DESIGN.md, codebase-structure.md |
| **Total** | **~80** | |

| Metric | Value |
|--------|-------|
| Total ArkTS lines | ~16,864 |
| Largest file | SshService.ets (1138 lines) |
| Database version | v4 (10 tables) |
| Page routes | 9 (AppShell + 8 detail/game pages) |

## 4. Dev Commands (Core)

### Build Commands

```text
No command-line build command is documented. Open the project in DevEco Studio and use its Run action.
Source: README.md > 运行
```

### Test Commands

```text
8 unit test files are present under entry/src/test/. Run via DevEco Studio test runner.
Tests cover: NavigationFacade, GameLaunchFacade, DefectClassifier, DefectWorkflow, RemoteOperation, RemoteResultAdapter, WindowEnvironmentProvider, WindowEnvironmentSnapshot.
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
- Go 1.21+ only when building the optional agent

### Configuration Notes

- `build-profile.json5` defines the single `entry` module and HarmonyOS 6.1.1 target.
- `entry/build-profile.json5` declares a Stage-model HarmonyOS HAP.
- `entry/oh-package.json5` declares `@ohos/libssh` as a dependency for SSH direct connection.
- The current issue permits static ArkTS structure inspection only; build and runtime verification remain user-owned.

## 6. Key Modules

### 6.1 SSH Dual-Mode Communication

- **SshService.ets** (1138 lines): `SshEngine` interface + `AgentEngine` + `DirectEngine` + `SshService` facade
- **DirectEngine**: `@ohos/libssh` native SSH — password/key auth, exec, metrics, SFTP read
- **AgentEngine**: HTTP + WebSocket to Go Agent — terminal, exec, files, metrics
- **Credential encryption**: AES-256-GCM via CryptoHelper.ets, keys persisted in preferences

### 6.2 Game Center

- **3 games**: Tetris (794 lines), Snake (636 lines), Game2048 (592 lines)
- **5 difficulty levels**: VERY_EASY / EASY / MEDIUM / HARD / HELL
- **GameLaunchFacade**: Parameter validation + route navigation
- **Game history**: Score persistence in `game_scores` RDB table

### 6.3 Multi-Theme System

- **Theme.ets** (758 lines): `ThemePalette` interface (30+ color fields + 8 font sizes)
- **6 color themes**: CYAN / OCEAN / SUNSET / AURORA / SAKURA / FOREST
- **Light/Dark mode**: Follow system or manual override
- **Custom backgrounds**: BackgroundImporter + GlobalBackgroundLayer component
- **Preference persistence**: PreferenceSnapshot with rollback support

### 6.4 Terminal Rendering

- **AnsiParser.ets** (269 lines): ANSI escape sequence parser (colors, bold, italic, underline)
- **TerminalBuffer.ets** (121 lines): Terminal line buffer management
- **TerminalView.ets** (206 lines): Reusable terminal rendering component

### 6.5 Navigation System

- **Navigation.ets** (376 lines): `NavigationFacade` + `PageRegistration` registry
- **Typed route parameters**: 7 parameter classes (AppShell, ServerDetail, PveNodeDetail, VmDetail, Terminal, ServerForm, GameHistory)
- **Page availability**: EMBEDDED (in AppShell) vs ROUTE (standalone page)
- **Navigation result**: `NavigationSuccess` / `NavigationFailure` with reason codes

### 6.6 Defect Tracking

- **GovernanceModels.ets** (135 lines): `DefectRecord`, `DefectWorkflow`, `FixEvidence`, `FixResult`
- **State machine**: ANALYZING → NEEDS_INFO → TO_FIX → TO_VERIFY → CONFIRMED / NOT_REPRODUCED
- **Evidence types**: STATIC, CODE, DEVICE, USER_CONFIRMATION
- **4 RDB tables**: defects, defect_evidence, defect_status_history, defect_fix_results

### 6.7 Go Agent

- **main.go** (1001 lines): HTTP + WebSocket service
- **11 endpoints**: health, metrics, exec, files (list/upload/upload-base64/download/mkdir/delete), ws/terminal, ws/ssh
- **Security**: Token auth, path traversal prevention, command timeout (30s), upload limit (100MB)
