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

## UI Design

Owner screens follow a Figma design with:
- **Dark navy header** (`AppTheme.navy`) per screen — no global `AppBar`
- **White/grey body** (`#F5F7FA`) with `BorderRadius.vertical(top: Radius.circular(24))` overlap
- **Custom bottom nav** in `OwnerHomeScreen` (tab order: Home → Expenses → Members → Summary)
- **Status badges**: outlined pill style with color-matched border + background tint
- **Expense cards**: title | amount (red), paid-by row, divider, status badge
- **Donut chart** in Summary uses `CustomPainter` (no chart library needed)
- **Member actions** exposed via three-dot → `showModalBottomSheet` action sheet

### Owner Screen Layout Pattern
```dart
Scaffold(
  backgroundColor: AppTheme.navy,
  body: Column(children: [
    SafeArea(child: /* dark header content */),
    Expanded(child: Container(
      decoration: BoxDecoration(color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: /* scrollable white body */,
    )),
  ]),
)
```

### Color Reference
| Token | Hex | Usage |
|---|---|---|
| `AppTheme.navy` | `#1A2B4A` | Header backgrounds |
| `#243560` | — | Dark stat cards inside header |
| `AppTheme.teal` | `#4DB6AC` | Accent, active states |
| `AppTheme.warning` | `#FF9800` | Pending badge, rent category |
| `AppTheme.error` | `#F44336` | Rejected, amount text |
| `AppTheme.success` | `#4CAF50` | Approved, positive balance |
| `#F5F7FA` | — | Body background |

## Notes

- Auth token stored via `SharedPreferences`, sent as `Authorization: Bearer <token>`
- Model IDs can be strings or objects — models handle both defensively
- `AuthGate` in `main.dart` handles role-based routing automatically
- `Expense` model has no `category` field — use `comments` as category display
- `MonthlyBills` (rent, food, electricity, water) drives the Summary donut chart categories
