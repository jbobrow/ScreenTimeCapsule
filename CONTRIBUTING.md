# Contributing to ScreenTimeCapsule

Thank you for your interest in contributing to ScreenTimeCapsule! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to:

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates.

When filing a bug report, include:

- **Clear title and description**
- **Steps to reproduce**
- **Expected vs actual behavior**
- **macOS version and app version**
- **Screenshots** (if applicable)
- **Console logs** (if available)

**Example:**

```markdown
**Description:**
App crashes when selecting "Last 30 Days" time period

**Steps to Reproduce:**
1. Launch ScreenTimeCapsule
2. Grant Full Disk Access
3. Select "Last 30 Days" from time period dropdown
4. App crashes

**Expected Behavior:**
Data should load for the last 30 days

**Environment:**
- macOS: 14.2
- App Version: 1.0.0
- Device: MacBook Pro (M1)

**Logs:**
[Attach crash log from Console.app]
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear, descriptive title**
- **Provide detailed description** of the proposed feature
- **Explain why this enhancement would be useful**
- **Include mockups or examples** if applicable

### Pull Requests

1. **Fork the repository**
   ```bash
   gh repo fork yourusername/ScreenTimeCapsule --clone
   cd ScreenTimeCapsule
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

3. **Make your changes**
   - Follow the coding style guidelines
   - Add tests if applicable
   - Update documentation

4. **Commit your changes**
   ```bash
   git commit -m "Add amazing feature"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/amazing-feature
   ```

6. **Create a Pull Request**
   - Provide a clear description
   - Reference related issues
   - Add screenshots for UI changes

## Development Setup

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Setup

```bash
# Clone your fork
git clone https://github.com/your-username/ScreenTimeCapsule.git
cd ScreenTimeCapsule

# Install dependencies
swift package resolve

# Open in Xcode
open Package.swift
```

### Running Tests

```bash
swift test
```

### Code Style

We follow Swift's standard coding conventions:

#### Naming

- **Types**: Use UpperCamelCase
  ```swift
  struct AppUsage { }
  class BackupManager { }
  ```

- **Functions/Variables**: Use lowerCamelCase
  ```swift
  func fetchAppUsage() { }
  let totalTime: TimeInterval
  ```

- **Constants**: Use lowerCamelCase
  ```swift
  let maximumRetentionDays = 365
  ```

#### Organization

- One type per file (with related nested types)
- Group related functionality with `// MARK: -` comments
- Organize imports alphabetically

```swift
import Foundation
import SwiftUI

// MARK: - Main Type

class BackupManager {
    // MARK: - Properties

    private let fileManager = FileManager.default

    // MARK: - Initialization

    init() { }

    // MARK: - Public Methods

    func performBackup() { }

    // MARK: - Private Methods

    private func cleanOldBackups() { }
}
```

#### SwiftUI

- Keep views small and focused
- Extract complex views into separate components
- Use environment objects for shared state
- Prefer computed properties for simple transformations

```swift
struct ContentView: View {
    @EnvironmentObject var dataManager: ScreenTimeDataManager

    var body: some View {
        VStack {
            HeaderView()
            UsageListView(apps: filteredApps)
        }
    }

    private var filteredApps: [AppUsage] {
        dataManager.currentUsage.filter { $0.totalTime > 0 }
    }
}
```

#### Documentation

Document public APIs with Swift documentation comments:

```swift
/// Fetches app usage data for the specified date range.
///
/// - Parameters:
///   - startDate: The beginning of the date range
///   - endDate: The end of the date range
/// - Returns: An array of `AppUsage` objects
/// - Throws: `DatabaseError` if the database cannot be accessed
func fetchAppUsage(from startDate: Date, to endDate: Date) throws -> [AppUsage]
```

### Testing Guidelines

- Write unit tests for business logic
- Test edge cases and error conditions
- Mock external dependencies
- Keep tests focused and independent

```swift
import XCTest
@testable import ScreenTimeCapsule

final class BackupManagerTests: XCTestCase {
    var sut: BackupManager!

    override func setUp() {
        super.setUp()
        sut = BackupManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testPerformBackup_CreatesBackupDirectory() throws {
        // Given
        let expectation = expectation(description: "Backup completes")

        // When
        Task {
            try await sut.performBackup()
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sut.backupDirectoryURL.path))
    }
}
```

## Project Structure

```
ScreenTimeCapsule/
├── Sources/
│   ├── ScreenTimeCapsuleApp.swift    # App entry point
│   ├── Models/                        # Data models
│   │   └── AppUsage.swift
│   ├── Managers/                      # Business logic
│   │   ├── DatabaseManager.swift
│   │   ├── BackupManager.swift
│   │   └── ScreenTimeDataManager.swift
│   └── Views/                         # SwiftUI views
│       ├── ContentView.swift
│       ├── UsageChartView.swift
│       ├── AppListView.swift
│       ├── PermissionView.swift
│       └── SettingsView.swift
├── Resources/                         # Resources
│   ├── Info.plist
│   └── ScreenTimeCapsule.entitlements
├── Tests/                             # Unit tests
└── Package.swift                      # SPM configuration
```

## Areas for Contribution

We welcome contributions in these areas:

### High Priority
- [ ] Export to CSV/JSON functionality
- [ ] Advanced search and filtering
- [ ] Website usage tracking
- [ ] Historical data comparisons
- [ ] Performance optimizations

### Medium Priority
- [ ] Menu bar widget
- [ ] Notification system
- [ ] Data insights and trends
- [ ] Custom themes
- [ ] Localization

### Low Priority
- [ ] Widgets
- [ ] Shortcuts integration
- [ ] AppleScript support

## Commit Messages

Follow conventional commit format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```
feat(backup): add automatic backup scheduling

Implement timer-based automatic backups with configurable intervals.
Users can now set backup frequency in settings.

Closes #123
```

```
fix(ui): prevent crash when selecting custom date range

Add validation for custom date range to ensure start date is before
end date. Display error message for invalid ranges.

Fixes #456
```

## Review Process

All submissions require review. We use GitHub pull requests for this purpose.

**Review Criteria:**
- Code quality and style
- Test coverage
- Documentation
- Performance impact
- Breaking changes

**Response Time:**
We aim to review PRs within 3-5 business days. Complex changes may take longer.

## License

By contributing, you agree that your contributions will be licensed under the same [MIT License](LICENSE) that covers the project.

## Questions?

Feel free to:
- Open an issue for questions
- Start a discussion in GitHub Discussions
- Contact the maintainers

## Recognition

Contributors will be recognized in:
- README.md acknowledgments
- Release notes
- GitHub contributors page

Thank you for contributing to ScreenTimeCapsule! 🎉
