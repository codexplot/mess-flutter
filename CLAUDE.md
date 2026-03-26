# CLAUDE.md

## Project Overview

**RoomMess** is a Flutter app for managing shared accommodation expenses and billing (hostels, PGs, shared flats). It handles expense tracking, monthly bill splitting, member management, and role-based access for owners and members.

## Architecture

- **State management**: Provider (`AuthProvider`, `RoomProvider`, `ExpenseProvider`)
- **API layer**: Centralized `ApiService` in `lib/services/api_service.dart` with static methods
- **Backend**: Node.js/Express expected at port `5001/api`
  - iOS/web: `http://localhost:5001/api`
  - Android emulator: `http://10.0.2.2:5001/api`

## Project Structure

```
lib/
├── main.dart              # Entry point, routing, AuthGate
├── theme.dart             # AppTheme (Material 3, navy/teal palette)
├── models/                # User, Room, Expense data models (JSON factory constructors)
├── providers/             # AuthProvider, RoomProvider, ExpenseProvider
├── services/api_service.dart
├── screens/
│   ├── auth/              # Login, Register
│   ├── owner/             # Home, RoomSetup, Members, Expenses, MonthlyBills, Summary
│   ├── member/            # Home, SubmitExpense, Expenses, Summary
│   └── admin/             # AdminHome
└── widgets/common.dart    # LoadingButton, StatusBadge, InfoCard, SectionHeader
```

## Common Commands

```bash
flutter pub get       # Install dependencies
flutter run           # Run (defaults to iOS on macOS)
flutter run -d chrome # Run on web
flutter test          # Run tests
flutter analyze       # Lint/type check
flutter build apk     # Build Android APK
flutter build ios     # Build iOS
```

## Key Dependencies

| Package | Purpose |
|---|---|
| `provider ^6.1.1` | State management |
| `http ^1.2.0` | API requests |
| `shared_preferences ^2.2.2` | JWT token storage |
| `image_picker ^1.0.7` | Bill image uploads |
| `cached_network_image ^3.3.1` | Image caching |
| `intl ^0.19.0` | Date formatting |

## User Roles

- **Owner**: Creates/manages rooms, sets monthly bills, approves/rejects expenses
- **Member**: Joins rooms via room code, submits expenses, views personal summary
- **Admin**: Separate admin home screen

## Notes

- Auth token stored via `SharedPreferences`, sent as `Authorization: Bearer <token>`
- Model IDs can be strings or objects — models handle both defensively
- `AuthGate` in `main.dart` handles role-based routing automatically
