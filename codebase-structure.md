# Zhizon Codebase Document

> This document is a project overview for the HarmonyOS application.

## 1. Tech Stack

- **Language**: ArkTS
- **Runtime / Framework**: HarmonyOS Stage model with ArkUI declarative UI
- **Target SDK**: HarmonyOS 6.1.1 (API 24)
- **Build system**: DevEco Studio with hvigor
- **Package manager**: ohpm 5.0+
- **Credential Encryption**: AES-256-GCM via CryptoArchitectureKit
- **Data Storage**: RelationalStore (RDB v4) with 5 persistent tables
- **Multi-Theme**: ThemePalette interface with 6 color themes + light/dark mode + custom backgrounds + glassmorphism toggle
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
│       │   │   ├── common/    # 7 files: Theme, ThemeContracts, Constants, Navigation, CryptoHelper, Difficulty, FailureHandling
│       │   │   ├── components/# 5 files: TopBar, DifficultyOption, FixedBottomNav, GlassEffect, GlobalBackgroundLayer
│       │   │   ├── entryability/ # EntryAbility — startup, window, theme, safe-area, RDB init
│       │   │   ├── model/     # 1 file: GovernanceModels (defect tracking + preferences)
│       │   │   ├── pages/     # 9 pages: AppShell, Index, Settings, More, Games, Tetris, Game2048, Snake, GameHistory
│       │   │   └── service/   # 7 files: DatabaseHelper, DataRepository, BackgroundImporter, WindowEnvironmentProvider, DefectWorkflow, DefectClassifier, PickerAdapter
│       │   └── resources/     # Module resources, profiles, strings, colors, and media
│       └── test/              # 6 unit test files
└── hvigor/                    # Repository-local HarmonyOS build tooling
```

## 3. File Statistics

| Type | Count | Description |
|------|-------|-------------|
| ArkTS source | 31 | 1 entryability + 7 common + 1 model + 7 service + 5 components + 9 pages |
| Test files | 6 | DefectClassifier, DefectWorkflow, GameLaunchFacade, NavigationFacade, WindowEnvironmentProvider, WindowEnvironmentSnapshot |
| Config | 8 | build-profile, oh-package, module.json5, etc. |
| Resources | 3 | color.json, string.json, main_pages.json |
| Documentation | 3 | README.md, doc/DESIGN.md, codebase-structure.md |
| **Total** | **~48** | |

| Metric | Value |
|--------|-------|
| Database version | v4 (5 tables) |
| Page routes | 5 (AppShell + 4 game pages) |

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

- **3 games**: Tetris, Snake, Game2048
- **5 difficulty levels**: VERY_EASY / EASY / MEDIUM / HARD / HELL
- **GameLaunchFacade**: Parameter validation + route navigation
- **Game history**: Score persistence in `game_scores` RDB table
- **Home page (Index)**: Game entry cards + best scores + difficulty overview

### 6.2 Multi-Theme System

- **Theme.ets**: `ThemePalette` interface (30+ color fields + 8 font sizes)
- **6 color themes**: CYAN / OCEAN / SUNSET / AURORA / SAKURA / FOREST
- **Light/Dark mode**: Follow system or manual override
- **Custom backgrounds**: BackgroundImporter + GlobalBackgroundLayer component
- **Glassmorphism**: GlassEffect component with toggle switch
- **Preference persistence**: PreferenceSnapshot with rollback support

### 6.3 Navigation System

- **Navigation.ets**: `NavigationFacade` + `PageRegistration` registry
- **3 main nav keys**: Index, Toolbox, More
- **5 registered pages**: Index, Toolbox, More, Games, Settings
- **Page availability**: EMBEDDED (in AppShell) vs ROUTE (standalone page)
- **Navigation result**: `NavigationSuccess` / `NavigationFailure` with reason codes

### 6.4 Defect Tracking

- **GovernanceModels.ets**: `DefectRecord`, `DefectWorkflow`, `FixEvidence`, `FixResult`
- **State machine**: ANALYZING → NEEDS_INFO → TO_FIX → TO_VERIFY → CONFIRMED / NOT_REPRODUCED
- **Evidence types**: STATIC, CODE, DEVICE, USER_CONFIRMATION
- **4 RDB tables**: defects, defect_evidence, defect_status_history, defect_fix_results
