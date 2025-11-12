# Beszel Mobile

Beszel Mobile is a Flutter-based Android application that provides comprehensive system monitoring and management capabilities. The application connects to a Beszel Hub instance via PocketBase, enabling real-time monitoring of system resources, containers, services, and alerts.

## Overview

Beszel Mobile offers a native mobile interface for the Beszel monitoring platform, allowing administrators and operators to monitor infrastructure health, manage alerts, and access system information from Android devices. The application provides feature parity with the web interface while leveraging mobile-specific UI patterns and interactions.

## Features

### System Monitoring

- Real-time system status and health metrics
- CPU, memory, disk, and network utilization tracking
- Historical performance charts with configurable time ranges
- Per-core CPU breakdown and per-interface network statistics
- GPU power monitoring and temperature tracking
- Load average visualization
- Swap memory usage tracking
- Battery status monitoring

### Alert Management

- Active alerts dashboard with real-time updates
- Alert history per system
- Configurable alert thresholds for CPU, memory, disk, network, temperature, load, swap, and GPU
- Customizable alert duration requirements
- Email and webhook notification configuration
- Alert status tracking and resolution

### Container Management

- Docker container listing and status monitoring
- Container resource usage metrics (CPU, memory, network)
- Container logs viewing
- Container details and configuration information
- Health status indicators

### System Services

- Systemd service listing and management
- Service status monitoring
- Service details and configuration viewing
- Service control operations

### Storage Health

- S.M.A.R.T. data retrieval and display
- Disk health monitoring
- Storage attribute tracking
- Disk information and statistics

### Authentication and Security

- Email and password authentication
- One-time password (OTP) login support
- Password reset functionality
- Token-based agent authentication
- Fingerprint management for system registration
- Universal token support for agent self-registration

### Configuration

- Configurable Beszel Hub base URL
- Theme selection (light, dark, system)
- Chart time range preferences
- Unit format preferences (temperature, network, disk)
- Notification destination management
- YAML configuration export (admin only)

## Requirements

- Flutter SDK 3.9.2 or higher
- Dart SDK 3.9.2 or higher
- Android SDK (minimum API level 21)
- Active Beszel Hub instance with PocketBase backend

## Installation

### Prerequisites

1. Install Flutter by following the [official installation guide](https://docs.flutter.dev/get-started/install)
2. Verify installation by running `flutter doctor`
3. Ensure Android development environment is properly configured

### Building the Application

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd beszel
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Build the Android APK:
   ```bash
   flutter build apk
   ```

   For a release build:
   ```bash
   flutter build apk --release
   ```

4. Install on a connected device:
   ```bash
   flutter install
   ```

### Development Setup

1. Ensure your development environment meets the requirements listed above
2. Connect an Android device or start an emulator
3. Run the application in debug mode:
   ```bash
   flutter run
   ```

## Configuration

### Initial Setup

On first launch, the application will prompt for the Beszel Hub base URL. Enter the full URL of your Beszel Hub instance (e.g., `https://beszel.example.com`).

### Authentication

The application supports multiple authentication methods:

- **Email/Password**: Standard email and password authentication
- **OTP Login**: One-time password authentication via email
- **Password Reset**: Self-service password reset functionality

### Server Connection

The base URL can be configured or changed at any time through Settings > Server Connection. Changing the base URL will log out the current session and require re-authentication.

## Architecture

### Project Structure

```
lib/
├── api/              # PocketBase client configuration
├── models/           # Data models and DTOs
├── screens/          # Application screens and UI
├── services/         # Business logic and API services
├── theme/            # Theme configuration and management
└── widgets/          # Reusable UI components
```

### Key Components

- **PocketBase Client**: Manages connection to the Beszel Hub backend
- **Services Layer**: Handles data fetching, real-time subscriptions, and business logic
- **State Management**: Uses StreamBuilder and FutureBuilder for reactive UI updates
- **Theme System**: Supports light, dark, and system theme modes

### Real-time Updates

The application leverages PocketBase real-time subscriptions to provide live updates for:
- System status and metrics
- Active alerts
- Container status
- Service status

## Dependencies

- `pocketbase`: Backend API client and real-time subscriptions
- `shared_preferences`: Local storage for user preferences and configuration
- `fl_chart`: Chart rendering for system metrics visualization

## Development

### Code Style

The project follows Flutter and Dart style guidelines. Run the following commands to ensure code quality:

```bash
flutter analyze
flutter format .
```

### Testing

Run tests using:

```bash
flutter test
```

## Troubleshooting

### Connection Issues

If the application cannot connect to the Beszel Hub:

1. Verify the base URL is correct and accessible
2. Ensure the Beszel Hub instance is running and reachable
3. Check network connectivity on the device
4. Verify authentication credentials are correct

### Real-time Updates Not Working

If real-time updates are not appearing:

1. Verify the PocketBase connection is active
2. Check that the user has appropriate permissions
3. Ensure the backend supports real-time subscriptions
4. Review application logs for subscription errors

### Build Issues

If encountering build errors:

1. Run `flutter clean` to clear build artifacts
2. Execute `flutter pub get` to refresh dependencies
3. Verify Flutter and Dart SDK versions meet requirements
4. Check that all required Android SDK components are installed

## License

[Specify license information]

## Contributing

[Specify contribution guidelines if applicable]

## Support

For issues, questions, or feature requests, please refer to the project's issue tracker or contact the development team.
