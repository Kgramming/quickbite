# QuickBite Flutter App

A cross-platform mobile application for the QuickBite food delivery system, built with Flutter and Dart.

## Features

- **Customer Authentication**: Secure login with JWT tokens
- **Restaurant Browsing**: Browse available restaurants and menus
- **Shopping Cart**: Add items, manage quantities, and view totals
- **Checkout**: Idempotent order placement with delivery address
- **Order Tracking**: Real-time order status updates with live polling
- **Order History**: View past orders and their details
- **User Profile**: Manage account settings and logout

## Getting Started

### Prerequisites

1. **Flutter SDK** (3.0 or higher)
   ```bash
   # Install Flutter: https://flutter.dev/docs/get-started/install
   flutter --version
   dart --version
   ```

2. **Backend API** running locally or deployed
   - Default: `http://localhost:8002`
   - Configure via build parameter (see below)

3. **Development Device/Emulator**
   - iOS: Xcode simulator or physical device
   - Android: Android emulator or physical device

### Installation

1. **Clone the repository** (if not already done)
   ```bash
   cd /Users/keval/Documents/quickbite/flutter_app
   ```

2. **Get Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code** (for serialization and retrofit)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Running the App

#### iOS Simulator
```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8002
```

#### Android Emulator
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8002
```

#### Production/Custom Server
```bash
flutter run --dart-define=API_BASE_URL=https://<prod-host>
```

### Building for Distribution

#### iOS (IPA)
```bash
flutter build ios --release --dart-define=API_BASE_URL=https://<prod-host>
```

#### Android (APK)
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<prod-host>
```

## Project Structure

```
flutter_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   ├── app_config.dart         # Environment configuration
│   │   ├── router.dart             # GoRouter navigation setup
│   │   └── theme.dart              # Material Design theme
│   ├── models/
│   │   ├── user.dart               # Auth & User models
│   │   ├── order.dart              # Order models
│   │   └── restaurant.dart         # Restaurant & Menu models
│   ├── services/
│   │   ├── api_client.dart         # Retrofit API client
│   │   └── local_storage.dart      # Hive local storage
│   ├── providers/                   # Riverpod state management
│   │   ├── auth_provider.dart      # Authentication state
│   │   ├── restaurant_provider.dart# Restaurants & cart
│   │   └── order_provider.dart     # Orders & checkout
│   └── screens/
│       ├── splash_screen.dart      # Initial load
│       ├── login_screen.dart       # Customer login
│       ├── home_screen.dart        # Restaurant list
│       ├── restaurant_detail_screen.dart
│       ├── cart_screen.dart        # Shopping cart
│       ├── checkout_screen.dart    # Order placement
│       ├── order_confirmation_screen.dart
│       ├── order_tracking_screen.dart
│       ├── order_history_screen.dart
│       └── profile_screen.dart
├── test/                           # Unit & widget tests
├── pubspec.yaml                    # Dependencies
├── analysis_options.yaml           # Lint rules
├── .gitignore
└── README.md
```

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_riverpod` | State management |
| `go_router` | Navigation & routing |
| `dio` | HTTP client |
| `retrofit` | Type-safe API client |
| `hive_flutter` | Local storage |
| `intl` | Localization & formatting |
| `json_serializable` | JSON serialization |
| `uuid` | Idempotency keys |

## API Integration

### Demo Credentials

```
Email: customer@example.com
Password: customer123
```

### Key Endpoints

| Endpoint | Purpose |
|----------|---------|
| `POST /api/v1/auth/login` | Customer login |
| `GET /api/v1/restaurants` | Browse restaurants |
| `GET /api/v1/restaurants/{id}/menu` | Get restaurant menu |
| `POST /api/v1/orders` | Create order (requires Idempotency-Key) |
| `GET /api/v1/orders` | Get customer's orders |
| `GET /api/v1/orders/{id}` | Get order details |
| `GET /api/v1/orders/{id}/history` | Get order status history |

See `/api/v1/orders/` endpoint for full contract details.

## Testing

### Run all tests
```bash
flutter test
```

### Run tests with coverage
```bash
flutter test --coverage
```

### Run specific test file
```bash
flutter test test/unit/models_test.dart
```

## Code Quality

### Lint analysis
```bash
flutter analyze
```

### Format code
```bash
dart format lib/
```

### Watch mode (rebuilds on file changes)
```bash
flutter run --verbose
```

## Troubleshooting

### "Flutter command not found"
Ensure Flutter is in your PATH:
```bash
export PATH="$PATH:$(flutter pub global run path_provider)/bin"
# Or permanently add to ~/.zprofile or ~/.bashrc
```

### "API connection refused"
1. Ensure backend API is running: `docker compose up`
2. Verify base URL in `config/app_config.dart`
3. Check firewall/network access

### "Build failed due to code generation"
Rebuild the generated code:
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Hive Storage Issues
Clear app data and reinstall:
```bash
flutter clean
flutter run
```

## Development Workflow

1. **Edit source code** in `lib/`
2. **Hot reload** changes:
   ```bash
   flutter run    # Press 'r' for hot reload
   ```
3. **Run tests** after changes:
   ```bash
   flutter test
   ```
4. **Generate code** after model changes:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

## Production Deployment

1. **Test build locally**
   ```bash
   flutter build apk --release
   flutter build ios --release
   ```

2. **Deploy APK** to Google Play Store
3. **Deploy IPA** to Apple App Store

## Contributing

- Follow Dart code style guidelines
- Run `dart format` before committing
- Ensure all tests pass
- Write tests for new features

## Support & Issues

For issues or questions:
1. Check existing issues on GitHub
2. Review backend API contract in `docs/API_CONTRACT_V1.md`
3. Contact the backend team (Muse)

## License

Proprietary — QuickBite Team

---

**Built with Flutter** 🚀  
**Backend by Muse** 🔧  
**Coordinated by ChatGPT** 📋
