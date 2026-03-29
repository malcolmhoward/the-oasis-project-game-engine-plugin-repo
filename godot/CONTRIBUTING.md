# Contributing to O.A.S.I.S. Godot Plugin

Thank you for your interest in contributing! This project follows the O.A.S.I.S.
ecosystem's fork-first workflow.

## Getting Started

1. **Fork** this repository to your GitHub account
2. **Clone** your fork locally
3. **Create a branch** using the naming convention below
4. **Make your changes** and test locally
5. **Submit a Pull Request** to this repository's `main` branch

## Branch Naming Convention

```
feat/<issue-number>-<short-description>     # New features
fix/<issue-number>-<short-description>      # Bug fixes
docs/<issue-number>-<short-description>     # Documentation
refactor/<issue-number>-<short-description> # Code refactoring
```

## Development Setup

1. Install [Godot 4.5](https://godotengine.org/download) (stable)
2. Install [Mosquitto](https://mosquitto.org/) for MQTT broker
3. Clone and open the project in Godot
4. Enable the plugin: Project → Project Settings → Plugins → O.A.S.I.S. OCP

## Code Style

Follow the [GDQuest GDScript Style Guide](https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines):

- Use `snake_case` for variables and functions
- Use `PascalCase` for classes and enums
- Use `SCREAMING_SNAKE_CASE` for constants
- Prefix private members with underscore: `_my_var`, `_my_func()`
- Use type hints wherever possible
- Document public functions with `##` doc comments

## Testing

Run the demo (`F5` in Godot) with Mosquitto running. Verify:

- MQTT connection establishes (green indicator in status bar)
- Peer status panel populates when ECHO peers are active
- Message log shows OCP traffic
- E3 avatar responds to OCP commands

## License

By contributing, you agree that your contributions will be licensed under the
GPL-3.0 license, consistent with the O.A.S.I.S. ecosystem.
