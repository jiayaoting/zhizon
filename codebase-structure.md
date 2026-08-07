# Zhizon Codebase Document

> This document is a project overview for the HarmonyOS application and its companion agent.

## 1. Tech Stack

- **Language**: ArkTS for the HarmonyOS application; Go 1.21+ for the optional server agent
- **Runtime / Framework**: HarmonyOS Stage model with ArkUI declarative UI
- **Target SDK**: HarmonyOS 6.1.1 (API 24)
- **Build system**: DevEco Studio with hvigor
- **Package manager**: ohpm 5.0+
- **Testing**: Hypium 1.0.21 is declared; no repository test suite is documented

## 2. Project Directory Structure

```text
zhizon/
├── AppScope/                  # Application-level identity, version, and shared resources
├── agent/                     # Optional Go HTTP and WebSocket agent for managed Linux servers
├── doc/                       # Architecture, data model, and integration documentation
├── entry/                     # HarmonyOS Stage HAP containing the application UI and services
│   └── src/
│       └── main/
│           ├── ets/
│           │   ├── common/    # Navigation, theme, constants, and shared state contracts
│           │   ├── components/# Reusable navigation, status, metric, and option UI components
│           │   ├── entryability/# Application startup, window, theme, and safe-area integration
│           │   ├── model/     # Server, PVE, VM, alert, file, and settings data contracts
│           │   ├── pages/     # Main navigation, detail, settings, terminal, file, and game pages
│           │   ├── service/   # Persistence, SSH, PVE API, background, and repository services
│           │   └── terminal/  # Terminal session presentation and interaction support
│           └── resources/     # Module resources, profiles, strings, colors, and media
└── hvigor/                    # Repository-local HarmonyOS build tooling
```

## 3. Dev Commands (Core)

### Build Commands

```text
No command-line build command is documented. Open the project in DevEco Studio and use its Run action.
Source: README.md > 运行
Validation verdict: INCONCLUSIVE. Validation was intentionally not executed because the issue contract prohibits compilation, build, tests, and device runs; the build-command skill does not support hvigor projects.
```

### Test Commands

```text
Not provided in project documentation.
```

### Run / Start Commands

```text
Open the project in DevEco Studio, configure signing, connect a HarmonyOS device or emulator, and click Run.
Source: README.md > 运行
```

## 4. Dev Environment (Brief)

### Prerequisites

- DevEco Studio 6.0+
- HarmonyOS SDK 6.1+ (API 24)
- ohpm 5.0+
- Go 1.21+ only when building the optional agent

### Configuration Notes

- `build-profile.json5` defines the single `entry` module and HarmonyOS 6.1.1 target.
- `entry/build-profile.json5` declares a Stage-model HarmonyOS HAP.
- The current issue permits static ArkTS structure inspection only; build and runtime verification remain user-owned.
