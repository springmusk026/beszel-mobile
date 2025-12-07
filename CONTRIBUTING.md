# Contributing to Beszel Mobile

First off, thank you for considering contributing to Beszel Mobile! 🎉

This document provides guidelines and steps for contributing. Following these guidelines helps communicate that you respect the time of the developers managing and developing this open source project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Style Guidelines](#style-guidelines)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
   ```bash
   git clone https://github.com/YOUR_USERNAME/beszel-mobile.git
   cd beszel-mobile
   ```
3. **Add upstream remote**
   ```bash
   git remote add upstream https://github.com/springmusk026/beszel-mobile.git
   ```
4. **Create a branch** for your changes
   ```bash
   git checkout -b feature/your-feature-name
   ```

## How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates.

When creating a bug report, include:

- **Clear title** describing the issue
- **Steps to reproduce** the behavior
- **Expected behavior** vs actual behavior
- **Screenshots** if applicable
- **Environment details**:
  - Flutter version (`flutter --version`)
  - Device/OS
  - Beszel server version

### 💡 Suggesting Features

Feature requests are welcome! Please provide:

- **Clear description** of the feature
- **Use case** — why is this feature needed?
- **Possible implementation** (optional)

### 🔧 Pull Requests

1. **Small PRs** are easier to review and merge
2. **One feature/fix per PR** — don't bundle unrelated changes
3. **Update documentation** if needed
4. **Add tests** for new functionality
5. **Follow the style guide**

## Development Setup

### Prerequisites

- Flutter SDK 3.19+
- Dart SDK 3.0+
- Android Studio / VS Code with Flutter extensions
- A running Beszel instance for testing

### Setup

```bash
# Install dependencies
flutter pub get

# Run the app in debug mode
flutter run

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format .
```

### Project Structure

```
lib/
├── api/          # API client
├── animations/   # Animation utilities
├── models/       # Data models
├── navigation/   # Navigation components
├── screens/      # UI screens
├── services/     # Business logic
├── theme/        # Design tokens
├── widgets/      # Reusable widgets
└── main.dart
```

## Style Guidelines

### Dart/Flutter

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` before committing
- Run `flutter analyze` and fix all issues
- Maximum line length: 120 characters

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Classes | PascalCase | `SystemCard` |
| Variables | camelCase | `systemName` |
| Constants | camelCase | `defaultTimeout` |
| Files | snake_case | `system_card.dart` |
| Private | _prefix | `_buildContent()` |

### Widget Guidelines

```dart
// ✅ Good: Const constructors when possible
const MyWidget({super.key});

// ✅ Good: Extract complex widgets
Widget _buildHeader() => ...

// ✅ Good: Use design tokens
padding: EdgeInsets.all(AppSpacing.lg)

// ❌ Bad: Magic numbers
padding: EdgeInsets.all(16)
```

### Design Tokens

Always use design tokens from `lib/theme/`:

```dart
// Colors
AppColors.success
AppColors.getStatusColor(status)

// Spacing
AppSpacing.sm  // 8
AppSpacing.md  // 12
AppSpacing.lg  // 16

// Radius
AppRadius.small   // 8
AppRadius.medium  // 12
AppRadius.large   // 16

// Durations
AppDurations.fast    // 150ms
AppDurations.medium  // 300ms
```

## Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Code style (formatting, semicolons, etc.) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks |

### Examples

```bash
feat(dashboard): add fleet health indicator
fix(systems): resolve status color not updating
docs(readme): add installation instructions
refactor(theme): extract color tokens to separate file
```

## Pull Request Process

1. **Update your branch** with the latest upstream changes
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Ensure all checks pass**
   ```bash
   flutter test
   flutter analyze
   dart format --set-exit-if-changed .
   ```

3. **Create the Pull Request**
   - Use a clear, descriptive title
   - Reference any related issues (`Fixes #123`)
   - Describe what changes you made and why
   - Include screenshots for UI changes

4. **Code Review**
   - Address reviewer feedback
   - Keep the conversation constructive
   - Be patient — maintainers are volunteers

5. **Merge**
   - PRs are squash-merged to keep history clean
   - Your contribution will be credited in the commit

## Questions?

Feel free to open an issue with the `question` label or reach out to the maintainers.

---

Thank you for contributing! 🙌
