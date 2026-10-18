# SmartPark AI: AI-Assisted Mobile Parking Management System

**B.Tech Computer Science & Engineering — 7th Semester Major Project**  
*A complete, offline-first, mobile parking management system with camera-assisted OCR plate recognition and deterministic billing.*

---

## 1. Project Overview

**SmartPark AI** is an Android mobile application engineered for parking facility operators and attendants. Designed to operate completely offline without recurring cloud subscriptions, remote APIs, or user logins, the system streamlines vehicle entry, exit, fee calculation, payment tracking, and audit reporting.

### Core Capabilities
- **Vehicle Entry**: Attendant captures the number plate using the system camera. Google ML Kit performs on-device OCR. Attendant verifies or corrects the normalized plate and selects vehicle category (`CAR`, `BIKE`, `OTHER`). Saving creates an `ACTIVE` session with a UTC timestamp.
- **Duplicate Prevention**: Partial unique index `ux_active_plate` and repository checks strictly forbid duplicate active sessions for the same vehicle.
- **Active Vehicle Tracking**: Real-time list of parked vehicles with dynamic elapsed duration counter and rapid search.
- **Vehicle Exit & Transparent Billing**: Scan or search active vehicle. The system locks the exit timestamp, applies configurable tariff rules (with grace period and rounding choices), and presents a clear line-item bill breakdown.
- **Atomic Concurrency Guarantee**: Conditional SQL `UPDATE ... WHERE id = ? AND status = 'ACTIVE'` ensures exactly one process can complete an exit, preventing double billing or repeated button presses.
- **Decoupled Payment Tracking**: Parking session status (`ACTIVE` / `COMPLETED`) is decoupled from payment status (`UNPAID` / `PAID`), supporting cash, UPI, or later settlement.
- **Receipts & CSV Export**: Digital receipt with breakdown reproduction from stored JSON snapshots and RFC 4180 CSV export for accounting spreadsheets.

---

## 2. Technical Stack & Engineering Decisions

| Layer | Technology | Decision & Rationale |
|---|---|---|
| **Platform** | Android (minSdk 21, targetSdk 34) | Native mobile target for parking attendants |
| **Framework** | Flutter 3.47.7 + Dart 3.13.5 | Cross-platform UI toolkit, null-safe, Material 3 design |
| **Design System** | Material 3 (#0E8C7F seed) | Light theme, portrait orientation lock, minimum 48 dp touch targets |
| **State Management** | `provider` (ChangeNotifier) | Unidirectional data flow with revision counter invalidation |
| **Local Database** | SQLite via `sqflite` (v1) | Hand-written SQL with `PRAGMA foreign_keys = ON`; avoids code-generation bloat |
| **Vision & OCR** | `google_mlkit_text_recognition` | On-device Latin text recognition without cloud latency or cost |
| **Camera Access** | `image_picker` (System Camera Intent) | Uses Android camera intent; requires zero intrusive `CAMERA` permission declarations |
| **Testing** | `flutter_test`, `sqflite_common_ffi` | Unit testing + in-memory SQLite integration testing |

---

## 3. Project Architecture & Directory Structure

The codebase adheres strictly to clean architecture principles: UI screens communicate solely with the `ParkingProvider`, which orchestrates domain services, which in turn query database repositories.

```
smartpark_ai/
├── android/                        # Native Android configuration (minSdk 21, label "SmartPark AI")
├── lib/
│   ├── main.dart                   # Binding init, portrait lock, DB open with retry, runApp
│   ├── app.dart                    # MaterialApp, Material 3 theme (#0E8C7F), HomeShell
│   ├── core/
│   │   ├── constants.dart          # Database constants, defaults, UI strings
│   │   ├── exceptions.dart         # Typed domain exceptions (DuplicateActiveSession, etc.)
│   │   └── formatters.dart         # Money (whole ₹), date-time, duration, receipt formatters
│   ├── data/
│   │   ├── app_database.dart       # SQLite database initialization, DDL creation, FK pragma
│   │   └── repositories/
│   │       ├── parking_repository.dart # SQL queries for sessions, payments, aggregates
│   │       └── tariff_repository.dart  # SQL queries for singleton tariff settings
│   ├── models/
│   │   ├── bill_breakdown.dart     # Immutable model holding billing computation line items
│   │   ├── daily_summary.dart      # Reporting aggregate models for daily performance
│   │   ├── parking_session.dart    # Parking session entity with JSON tariff snapshot
│   │   ├── payment.dart            # Payment entity (amount, method, status, timestamp)
│   │   └── tariff.dart             # Tariff rules entity (rates, grace, rounding, capacity)
│   ├── providers/
│   │   └── parking_provider.dart   # ChangeNotifier with revision counter for reactive reload
│   ├── screens/
│   │   ├── home_shell.dart         # 5-tab NavigationBar (Dashboard, Entry, Exit, Active, History)
│   │   ├── dashboard_screen.dart   # Revenue, active count, entries, exits, occupancy progress bar
│   │   ├── entry_screen.dart       # Camera OCR capture, suggestion chips, category, confirmation
│   │   ├── exit_screen.dart        # Search, bill breakdown card, payment toggle, exit confirm
│   │   ├── active_screen.dart      # Real-time list of parked vehicles with live elapsed timers
│   │   ├── history_screen.dart     # Filterable list of completed parking sessions
│   │   ├── tariff_screen.dart      # Configurable rates, grace period, rounding, capacity
│   │   ├── reports_screen.dart     # Today/7d/30d revenue metrics and RFC 4180 CSV export
│   │   └── receipt_screen.dart     # Digital receipt (SP-XXXXXX), breakdown reconstruction, sharing
│   └── services/
│       ├── billing_service.dart    # Pure deterministic duration and fee computation engine
│       ├── csv_service.dart        # RFC 4180 compliant CSV export generator
│       ├── ocr_service.dart        # ML Kit processing, candidate generation, ranking heuristics
│       ├── parking_service.dart    # Orchestrates transactions and lifecycle operations
│       └── plate_service.dart      # Normalization (uppercase alphanumeric) and regex validation
├── test/
│   ├── billing_service_test.dart   # 26 test cases for billing vectors, grace, overnight, rounding
│   ├── plate_service_test.dart     # 13 test cases for plate normalization, regex, OCR ranking
│   └── parking_service_test.dart   # 10 test cases with sqflite_common_ffi for full DB lifecycle
├── docs/                           # Parallel documentation track (Section 24)
│   ├── SmartPark_AI_Report.docx    # 7-chapter comprehensive academic report with TOC & tables
│   ├── SmartPark_AI_Presentation.pptx # 12-slide structured presentation
│   ├── screenshots/                # Real device/system screenshots
│   └── tools/                      # python-docx and python-pptx documentation generator
├── pubspec.yaml                    # Dependencies and metadata
└── README.md                       # Complete setup, build, and architecture documentation
```

---

## 4. Database Schema (DDL)

Foreign key enforcement is enabled via `PRAGMA foreign_keys = ON;`.

```sql
-- Single-row configuration table
CREATE TABLE tariff_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  first_hour_rate INTEGER NOT NULL CHECK (first_hour_rate >= 0),
  additional_hour_rate INTEGER NOT NULL CHECK (additional_hour_rate >= 0),
  grace_minutes INTEGER NOT NULL CHECK (grace_minutes >= 0),
  rounding_rule TEXT NOT NULL CHECK (rounding_rule IN ('STARTED_HOUR','FULL_HOUR')),
  capacity INTEGER NOT NULL CHECK (capacity >= 1),
  updated_at INTEGER NOT NULL
);

-- Core parking sessions table
CREATE TABLE parking_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plate_number TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'CAR' CHECK (category IN ('CAR','BIKE','OTHER')),
  entry_time INTEGER NOT NULL,
  exit_time INTEGER,
  duration_minutes INTEGER,
  amount INTEGER,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE','COMPLETED')),
  tariff_snapshot TEXT,
  CHECK (
    (status = 'ACTIVE' AND exit_time IS NULL AND amount IS NULL) OR
    (status = 'COMPLETED' AND exit_time IS NOT NULL AND amount IS NOT NULL
       AND duration_minutes IS NOT NULL AND tariff_snapshot IS NOT NULL
       AND exit_time >= entry_time)
  )
);

-- Partial index preventing multiple active sessions for the same vehicle
CREATE UNIQUE INDEX ux_active_plate ON parking_sessions(plate_number)
  WHERE status = 'ACTIVE';

CREATE INDEX ix_sessions_entry ON parking_sessions(entry_time);
CREATE INDEX ix_sessions_exit ON parking_sessions(exit_time);

-- Separate payments table
CREATE TABLE payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL UNIQUE
    REFERENCES parking_sessions(id) ON DELETE RESTRICT,
  amount INTEGER NOT NULL CHECK (amount >= 0),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('CASH','UPI','OTHER')),
  payment_status TEXT NOT NULL CHECK (payment_status IN ('UNPAID','PAID')),
  paid_at INTEGER
);

CREATE INDEX ix_payments_paid_at ON payments(paid_at);
```

---

## 5. Billing Rules & Deterministic Engine

The billing engine calculates elapsed stay duration using stored UTC epoch milliseconds only (never `DateTime.now()` for past transactions):

$$\text{durationMinutes} = \lfloor(\text{exitMs} - \text{entryMs}) / 60000\rfloor$$

$$\text{Charge} = \begin{cases} 
0, & \text{if } \text{durationMinutes} \le \text{graceMinutes} \\
\text{firstHourRate} + \left\lceil \frac{\max(0, \text{durationMinutes} - 60)}{60} \right\rceil \times \text{additionalHourRate}, & \text{for STARTED\_HOUR} \\
\text{firstHourRate} + \left\lfloor \frac{\max(0, \text{durationMinutes} - 60)}{60} \right\rfloor \times \text{additionalHourRate}, & \text{for FULL\_HOUR}
\end{cases}$$

### Standard Tariff Test Vectors (₹30 first hour, ₹20 additional hour, 10 min grace)
| Duration | Case Description | `STARTED_HOUR` | `FULL_HOUR` |
|---|---|:---:|:---:|
| **0 min** | Instant exit | ₹0 | ₹0 |
| **10 min** | Exactly at grace limit | ₹0 | ₹0 |
| **11 min** | Just over grace | ₹30 | ₹30 |
| **60 min** | Exactly one hour | ₹30 | ₹30 |
| **61 min** | One hour plus one minute | ₹50 | ₹30 |
| **119 min** | Just under two hours | ₹50 | ₹30 |
| **120 min** | Exactly two hours | ₹50 | ₹50 |
| **121 min** | Two hours plus one minute | ₹70 | ₹50 |
| **145 min** | Worked example (2h 25m) | **₹70** | **₹50** |
| **520 min** | Overnight (22:30 to 07:10 next day) | ₹190 | ₹170 |
| **1441 min** | Full 24 hours plus one minute | ₹510 | ₹490 |

---

## 6. Automated Testing & Verification Gates

The test suite validates every specification requirement:
```bash
# 1. Static Analysis Gate
flutter analyze

# 2. Automated Test Suite Gate (49 tests)
flutter test
```

### Test Suite Summary (49 Passed)
1. **Billing Service (`test/billing_service_test.dart`)**:
   - Duration calculation and epoch math (2 tests)
   - Invalid exit timestamps throwing `InvalidTimestampException` (2 tests)
   - All 11 billing vectors under `STARTED_HOUR` rule (11 tests)
   - All 11 billing vectors under `FULL_HOUR` rule (11 tests)
2. **Plate & OCR Service (`test/plate_service_test.dart`)**:
   - Normalization: uppercase alphanumeric conversion (5 tests)
   - Plate validation: hard length rules (4 to 12) & soft warning heuristics (4 tests)
   - OCR candidate selection & ranking (standard, Bharat series, 2-line plates, empty) (4 tests)
3. **Parking Service Integration (`test/parking_service_test.dart`)**:
   - In-memory SQLite lifecycle: entry creates `ACTIVE` row (1 test)
   - Duplicate active entry throws `DuplicateActiveSessionException` (1 test)
   - Unknown plate at exit throws `NoActiveSessionException` (1 test)
   - Exit completion with `PAID` payment record (1 test)
   - Exit completion with `UNPAID` payment record (1 test)
   - Repeated exit attempt throws `AlreadyCompletedException` (1 test)
   - Tariff changes do not alter completed session historical amounts (1 test)
   - Marking `UNPAID` session as `PAID` updates database (1 test)
   - Dashboard aggregate counts agree with real database records (1 test)
   - Disk persistence: database close and reopen preserves data (1 test)

---

## 7. Build Instructions

### Prerequisites
- Flutter SDK (Channel stable, 3.47.7+)
- Android SDK (API Level 34.0.0+, minSdk 21)
- Java OpenJDK 17 or 21

### Commands
```bash
# Install dependencies
flutter pub get

# Run tests
flutter test

# Build production release APK
flutter build apk --release
```

The resulting release APK is located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 8. Documentation Artifacts

In parallel with application development (Track B per Section 24), complete academic documentation is generated:
- **`docs/SmartPark_AI_Report.docx`**: Complete 7-chapter project report including front matter (title, certificate, declaration, abstract, TOC, list of figures, list of tables), architecture diagrams, schema specifications, real test results, and references.
- **`docs/SmartPark_AI_Presentation.pptx`**: 12-slide executive presentation formatted with project theme (#0E8C7F) and required slide layout.

---

## 9. Known Limitations

1. **General ML Kit OCR**: Optical character recognition utilizes Google ML Kit's generic Latin text recognition engine. While fast, local, and zero-cost, it is not a specialized ANPR deep neural net; operators must always confirm suggested plates.
2. **Single-Device Offline Operation**: All records persist locally in SQLite on the operator's phone. Multi-lane distributed synchronization across several devices is not supported without a network synchronization broker.
3. **Debug-Signed Release APK**: In accordance with Section 13, the release APK uses Flutter's default debug signing configuration for straightforward deployment and demonstration during academic evaluation without managing private keystore certificates.
