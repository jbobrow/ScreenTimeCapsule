# ScreenTimeCapsule 📊

> Keep all of your Screen Time data safe in an archive

ScreenTimeCapsule is a native macOS application that automatically backs up your Screen Time data and provides beautiful visualizations of your usage patterns. Apple only keeps ~4 weeks of Screen Time data, but with ScreenTimeCapsule, you can keep your complete history forever.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🔒 Automatic Backups
- Configurable automatic backup intervals (hourly, daily, weekly)
- Manual backup on-demand
- Preserves complete Screen Time history beyond Apple's 4-week limit

### 📱 Multi-Device Support
- View data from all your Apple devices
- Aggregates usage across devices
- Device-specific filtering

### 📈 Beautiful Data Visualization
- Charts matching Apple's Screen Time design
- Hourly usage breakdown
- Weekly usage trends
- Category-based analytics

### ⚙️ Flexible Data Retention
- Choose how long to keep backup data (3 months to forever)
- Automatic cleanup of old backups based on retention policy
- Export backups to external storage

### 🎨 Native macOS Design
- Built with SwiftUI
- Follows macOS design guidelines
- Native app performance

## Screenshots

[Screenshots would go here showing the app interface]

## Requirements

- macOS 14.0 (Sonoma) or later
- Full Disk Access permission
- Screen Time enabled on your Mac

## Installation

### Option 1: Build from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/ScreenTimeCapsule.git
cd ScreenTimeCapsule
```

2. Open in Xcode:
```bash
open Package.swift
```

3. Build and run the project (⌘R)

### Option 2: Swift Package Manager

```bash
swift build -c release
```

The built application will be available in `.build/release/`

## Setup

### Granting Full Disk Access

ScreenTimeCapsule requires Full Disk Access to read Screen Time databases.

1. Open **System Settings** → **Privacy & Security** → **Full Disk Access**
2. Click the **+** button
3. Navigate to the ScreenTimeCapsule app
4. Toggle the switch to enable access
5. Restart ScreenTimeCapsule

The app will guide you through this process on first launch.

## Usage

### First Launch

1. Launch ScreenTimeCapsule
2. Grant Full Disk Access when prompted
3. The app will automatically load your current Screen Time data
4. Configure backup settings in Preferences (⌘,)

### Configuring Backups

1. Open **Settings** (⌘,)
2. Go to the **Backup** tab
3. Configure:
   - Enable/disable automatic backups
   - Set backup interval
   - Choose backup location
4. Optionally trigger a manual backup

### Viewing Data

- **Device Filter**: Select "All Devices" or a specific device from the dropdown
- **Time Period**: Choose from Today, Last 7 Days, Last 30 Days, etc.
- **Category Filter**: Click on categories in the sidebar to filter apps
- **Search**: Use the search bar to find specific apps

### Data Retention

1. Open **Settings** (⌘,)
2. Go to the **Data** tab
3. Set retention period (or choose "Forever" for unlimited storage)
4. Old backups are automatically cleaned up based on your setting

## Technical Details

### Database Locations

ScreenTimeCapsule reads from these system databases:

- **Usage Data**: `~/Library/Application Support/Knowledge/knowledgeC.db`
- **Screen Time Config**: `~/Library/Application Support/com.apple.screentime/RMAdminStore-Local.sqlite`

### Backup Storage

By default, backups are stored in:
```
~/Library/Application Support/ScreenTimeCapsule/Backups/
```

You can change this location in Settings.

### Data Format

Backups are timestamped copies of the original SQLite databases, preserving the complete data structure. Each backup includes:
- Main database file (`.db` or `.sqlite`)
- Write-Ahead Log files (`.wal`)
- Shared memory files (`.shm`)

## Architecture

ScreenTimeCapsule is built with:

- **SwiftUI**: Modern declarative UI framework
- **SQLite.swift**: Type-safe SQLite database access
- **Combine**: Reactive programming for data flow
- **Swift Charts**: Native charting framework

### Key Components

- `DatabaseManager`: Reads Screen Time databases
- `BackupManager`: Handles backup operations and scheduling
- `ScreenTimeDataManager`: Aggregates and manages usage data
- SwiftUI Views: Native macOS interface

## Privacy & Security

- All data stays on your Mac
- No cloud sync or external servers
- Requires explicit Full Disk Access permission
- App sandbox enabled for security
- Open source - audit the code yourself

## Troubleshooting

### "No data available"

1. Ensure Screen Time is enabled in System Settings
2. Check that Full Disk Access is granted
3. Try refreshing the data (⌘R)

### "Failed to load data"

1. Verify Full Disk Access permission
2. Check that Screen Time databases exist
3. Restart ScreenTimeCapsule

### Backups not working

1. Check backup location is writable
2. Verify sufficient disk space
3. Check Settings → Backup for error messages

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Roadmap

- [ ] Export data to CSV/JSON
- [ ] Advanced filtering and search
- [ ] Custom date ranges
- [ ] Website usage tracking
- [ ] Notification integration
- [ ] Menu bar widget
- [ ] Historical comparisons
- [ ] Data insights and trends

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by Apple's Screen Time interface
- Built with love for privacy-conscious Mac users

## Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/yourusername/ScreenTimeCapsule/issues) page
2. Create a new issue with details about your problem
3. Include macOS version and app version

---

Made with ❤️ for macOS
