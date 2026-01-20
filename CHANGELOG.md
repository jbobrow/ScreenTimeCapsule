# Changelog

All notable changes to ScreenTimeCapsule will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Export to CSV/JSON
- Advanced search and filtering
- Custom date range selector
- Website usage tracking
- Historical data comparisons
- Menu bar widget
- Notification integration

## [1.0.0] - 2026-01-20

### Added
- Initial release of ScreenTimeCapsule
- Automatic backup system with configurable intervals
- Manual backup functionality
- Multi-device support and data aggregation
- Beautiful data visualization matching Apple's Screen Time design
- Hourly and weekly usage charts
- Category-based usage breakdown
- App usage list with search functionality
- Full Disk Access permission flow
- Configurable data retention policies
- Settings panel for backup and data management
- Backup status and statistics display
- Native macOS SwiftUI interface
- Support for macOS 14.0 (Sonoma) and later

### Technical
- Built with SwiftUI and Swift Charts
- SQLite.swift for database access
- Combines reactive programming for data flow
- App sandbox with Full Disk Access entitlement
- Automatic backup scheduling
- Database WAL and SHM file preservation

### Documentation
- Comprehensive README with setup instructions
- Build guide for developers
- Contributing guidelines
- Technical notes on Screen Time databases
- Makefile for easy building

[Unreleased]: https://github.com/yourusername/ScreenTimeCapsule/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yourusername/ScreenTimeCapsule/releases/tag/v1.0.0
