# Screen Time Database Technical Notes

## Database Locations

### Primary Screen Time Database
- **Path**: `~/Library/Application Support/com.apple.screentime/`
- **Main DB**: `RMAdminStore-Local.sqlite`
- Contains screen time limits, app limits, downtime schedules

### Device Activity Database (iOS 15+)
- **Path**: `~/Library/Application Support/Knowledge/knowledgeC.db`
- Contains detailed app usage events, web usage, notifications
- This is the primary database for usage statistics

### Additional Files
- `~/Library/Application Support/com.apple.screentime/*.sqlite-wal` (Write-Ahead Logs)
- `~/Library/Application Support/com.apple.screentime/*.sqlite-shm` (Shared Memory)

## Database Schema Overview

### knowledgeC.db Key Tables
- **ZOBJECT**: Main events table
  - App launches and usage durations
  - Screen on/off events
  - Safari usage

- **ZSTRUCTUREDMETADATA**: Metadata for events
  - App bundle IDs
  - Website domains
  - Device identifiers

- **ZSOURCE**: Source applications
  - Bundle identifiers
  - App names

### RMAdminStore-Local.sqlite Tables
- **ZUSAGEBLOCK**: Screen time usage blocks
- **ZUSAGECOUNTEDITEM**: Per-app usage tracking
- **ZUSAGETIMEDITEM**: Time-based usage data
- **ZDEVICE**: Connected devices info

## Data Retention
- Apple typically keeps ~28 days of detailed data
- Older data is aggregated and summarized
- Need to backup regularly to preserve granular data

## Required Permissions
- **Full Disk Access**: Required to read Screen Time databases
- **TCC (Transparency, Consent, and Control)**: System privacy framework

## Backup Strategy
1. Monitor databases for changes using FSEvents
2. Copy databases to backup location with timestamp
3. Merge data into consolidated archive database
4. Maintain granular data based on user preference
5. Support incremental backups to minimize disk space

## Multi-Device Support
- Screen Time syncs across devices via CloudKit
- Device-specific data is marked with device identifier
- Can aggregate data from ZDEVICE table
