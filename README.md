# SmartPark AI: Offline-First AI-Assisted Mobile Parking Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.5-0175C2?logo=dart)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-WAL%20Enabled-003B57?logo=sqlite)](https://www.sqlite.org)
[![Google ML Kit](https://img.shields.io/badge/Google%20ML%20Kit-On--Device%20OCR-4285F4?logo=google)](https://developers.google.com/ml-kit)
[![Tests](https://img.shields.io/badge/Automated%20Tests-54%20Passing-success)](test/)
[![License](https://img.shields.io/badge/Copyright-%C2%A9%202026%20Kunal%20Chauhan-blue)](#author--copyright)

**B.Tech Computer Science & Engineering — 7th Semester Major Project**  
*Lead Architect & Software Engineer:* **Kunal Chauhan**  
*Copyright:* **© 2026 Kunal Chauhan. All rights reserved.**

---

## 1. Project Overview & Problem Statement

**SmartPark AI** is an enterprise-grade, offline-first Android mobile parking management solution engineered for commercial, municipal, and private parking facilities. Unlike legacy solutions that require continuous high-bandwidth cloud connectivity, expensive recurring SaaS subscriptions, or vulnerable manual paper ticketing, SmartPark AI operates **100% autonomously on-device**.

By combining **on-device computer vision (Google ML Kit)**, an **ACID-compliant SQLite relational database**, a **deterministic mathematical billing engine**, and an **Apple VisionOS-inspired minimalist glassmorphic interface**, SmartPark AI eliminates revenue leakage, prevents ghost vehicle entries, ensures single-digit millisecond transaction latency, and guarantees total operational resilience in basements and remote areas.

---

## 2. Comprehensive Documentation & Viva Preparation Suite

The project includes an end-to-end documentation ecosystem designed for peer review, academic evaluation, and viva defense:

| Document / Artifact | Location | Description |
|---|---|---|
| **Viva Q&A Master Guide** | [`SmartPark_AI_Viva_QA_Master_Guide.pdf`](../SmartPark_AI_Viva_QA_Master_Guide.pdf) | **5-page master guide with 22 comprehensive technical defense Q&As** covering architecture, ML Kit CNNs, SQLite partial unique indexes, billing math, R8 ProGuard fixes, and scaling curveballs. |
| **Project Completion Dossier** | [`SmartPark_AI_Project_Completion_Dossier.pdf`](../SmartPark_AI_Project_Completion_Dossier.pdf) | **4-page executive sign-off report** detailing project evolution, problem space, architecture verification, 54-test matrix, and hardware deployment proofs. |
| **Academic Thesis / Report** | [`docs/SmartPark_AI_Report.docx`](docs/SmartPark_AI_Report.docx) | 7-chapter complete academic project report with Table of Contents, figures, schema diagrams, and academic citations. |
| **Defense Slide Deck** | [`docs/SmartPark_AI_Presentation.pptx`](docs/SmartPark_AI_Presentation.pptx) | 12-slide high-impact presentation formatted with project theme (#0E8C7F) and structured for thesis defense. |
| **Project Implementation Plan** | [`SmartPark_AI_Project_Plan-2.pdf`](../SmartPark_AI_Project_Plan-2.pdf) | Original technical specification and engineering roadmap. |

---

## 3. Key Features & Architectural Pillars

### A. On-Device Vision & Plate Recognition (Google ML Kit)
- **Zero Cloud Latency**: Powered by a lightweight Convolutional Neural Network (CNN) running locally via TensorFlow Lite on the device's hardware NPU/GPU.
- **Android Camera System Intent**: Uses `image_picker` to delegate optical acquisition to Android's native OEM camera HAL. Leverages hardware auto-focus, dynamic exposure, auto-flash, and multi-lens optical switching without holding intrusive native camera locks.
- **Dual-Pass RegEx Heuristics**: Automatically strips non-alphanumeric noise and tests candidates against Indian RTO registration formats (`^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$`).
- **Resilient Fallback**: Dirty, obscured, or broken plates can be manually typed or edited via an instant keyboard fallback.

### B. Database & Concurrency Engineering (SQLite)
- **Partial Unique Index (`ux_active_plate`)**:
  ```sql
  CREATE UNIQUE INDEX ux_active_plate 
  ON parking_sessions(plate_number) 
  WHERE status = 'ACTIVE';
  ```
  Physically prevents the same vehicle from having multiple active parking sessions simultaneously.
- **Atomic Exit Update**:
  ```sql
  UPDATE parking_sessions 
  SET status = 'COMPLETED', exit_time = ?, duration_minutes = ?, amount = ?, tariff_snapshot = ?
  WHERE id = ? AND status = 'ACTIVE';
  ```
  Returns `1` row affected on the first exit tap and `0` on any subsequent tap, completely eliminating race conditions and double-billing.
- **Decoupled Architecture**: `parking_sessions` and `payments` are maintained in separate normalized tables, allowing physical vehicle exit to be recorded independently of cash/UPI payment settlement.

### C. Deterministic Mathematical Billing Engine
- **UTC Millisecond Arithmetic**: All duration calculations derive strictly from stored integer timestamps (`exit_ms - entry_ms`), avoiding daylight saving shifts or device time modifications.
- **15-Minute Grace Period**: Vehicles exiting within 15 minutes of entry are billed ₹0.00 (`isGracePeriod = true`).
- **Configurable Rounding Rules**:
  - `STARTED_HOUR` (Ceiling): Any fractional hour beyond 60 minutes rounds up (`ceil(delta / 60)`).
  - `FULL_HOUR` (Floor): Fractional hours are discarded until a full 60-minute interval elapses (`floor(delta / 60)`).
- **Immutable Tariff Snapshots**: The exact tariff structure at checkout is serialized as JSON in `tariff_snapshot`. If an administrator alters rates tomorrow, historical receipts and revenue audits remain 100% immutable.

### D. Apple VisionOS Minimalist Glassmorphic UI
- **Translucent Frosted Glass**: Built using custom `GlassContainer` widgets leveraging Flutter's native `BackdropFilter` and `ImageFilter.blur(sigmaX: 12, sigmaY: 12)`.
- **Subtle Layering & Depth**: Semi-transparent dark gradients (`rgba(255,255,255,0.06)` to `rgba(255,255,255,0.02)`), 0.8px translucent specular border highlights, and soft ambient drop shadows.
- **Micro-Animations & Visual Polish**: Fluid entrance transitions, responsive tap feedback, live pulsing parking status indicators, and custom `GlassBottomNavBar`.
- **60 FPS Mobile GPU Optimization**: Blur filters are cached and bound using `RepaintBoundary` to prevent canvas repainting cascades.

### E. Financial Reporting & Data Governance
- **Digital Receipts**: Instant generation of shareable tickets with unique tracking codes (`SP-XXXXXX`) and exact line-item breakdowns reconstructed from stored tariff snapshots.
- **RFC 4180 CSV Export**: Generates comma-separated audit files with escaped quotes, strict CRLF (`\r\n`) endings, and direct export via the native Android Share Sheet to Excel and Google Sheets.

---

## 4. Codebase Directory Structure

```
smartpark_ai/
├── android/                             # Android native Gradle configuration & R8 rules
│   └── app/proguard-rules.pro           # Custom ProGuard rules (-dontoptimize, ML Kit keep rules)
├── lib/
│   ├── main.dart                        # Entry point, orientation lock, DB initialization
│   ├── app.dart                         # MaterialApp, Dark theme, Material 3 (#0E8C7F)
│   ├── core/
│   │   ├── constants.dart               # AppConstants, copyright (© 2026 Kunal Chauhan)
│   │   ├── exceptions.dart              # Custom domain exceptions (DuplicateActiveSession, etc.)
│   │   └── formatters.dart              # AppFormatters (Currency, Date-Time, Duration)
│   ├── data/
│   │   ├── app_database.dart            # SQLite helper, DDL, Write-Ahead Logging (WAL)
│   │   └── repositories/
│   │       ├── parking_repository.dart  # Raw SQL CRUD for sessions and payments
│   │       └── tariff_repository.dart   # Singleton tariff settings repository
│   ├── models/
│   │   ├── bill_breakdown.dart          # Immutable billing computation line items
│   │   ├── daily_summary.dart           # Aggregate financial reporting models
│   │   ├── parking_session.dart         # Core parking session domain entity
│   │   ├── payment.dart                 # Payment record entity (CASH, UPI, UNPAID, PAID)
│   │   └── tariff.dart                  # Tariff configuration model
│   ├── providers/
│   │   └── parking_provider.dart        # ChangeNotifier with revision counter invalidation
│   ├── screens/
│   │   ├── home_shell.dart              # Main shell with animated GlassBottomNavBar
│   │   ├── dashboard_screen.dart        # Live occupancy meter, revenue cards, quick actions
│   │   ├── entry_screen.dart            # Vision OCR plate capture, manual edit, check-in
│   │   ├── exit_screen.dart             # Vehicle search, live bill breakdown, exit confirmation
│   │   ├── active_screen.dart           # Real-time list of parked vehicles with elapsed timers
│   │   ├── history_screen.dart          # Searchable, filterable audit log of completed sessions
│   │   ├── tariff_screen.dart           # Interactive tariff editor (rates, grace, rounding)
│   │   ├── reports_screen.dart          # Today/7-day/30-day analytics & RFC 4180 CSV export
│   │   └── receipt_screen.dart          # Glassmorphic digital receipt with share actions
│   ├── services/
│   │   ├── billing_service.dart         # Pure deterministic duration & billing math engine
│   │   ├── csv_service.dart             # RFC 4180 compliant CSV export generator
│   │   ├── ocr_service.dart             # ML Kit processing, OCR ranking, confidence scoring
│   │   ├── parking_service.dart         # High-level transactional business logic orchestrator
│   │   └── plate_service.dart           # Alphanumeric normalization & RegEx validation
│   └── widgets/
│       ├── ambient_background.dart      # Deep layered ambient gradient background
│       ├── glass_bottom_nav_bar.dart    # VisionOS floating frosted navigation bar
│       └── glass_container.dart         # Reusable BackdropFilter glass card & container
├── test/
│   ├── billing_service_test.dart        # 26 unit tests for grace, ceiling, floor, & overnight billing
│   ├── plate_service_test.dart          # 17 unit tests for plate normalization & OCR ranking
│   └── parking_service_test.dart        # 11 integration tests (in-memory SQLite, ACID, persistence)
├── docs/                                # Academic documentation, thesis report, & presentation
├── pubspec.yaml                         # Flutter dependencies & metadata
└── README.md                            # Complete technical documentation
```

---

## 5. Database Schema & Architecture

```sql
PRAGMA foreign_keys = ON;

-- 1. Singleton Tariff Configuration
CREATE TABLE tariff_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  first_hour_rate INTEGER NOT NULL CHECK (first_hour_rate >= 0),
  additional_hour_rate INTEGER NOT NULL CHECK (additional_hour_rate >= 0),
  grace_minutes INTEGER NOT NULL CHECK (grace_minutes >= 0),
  rounding_rule TEXT NOT NULL CHECK (rounding_rule IN ('STARTED_HOUR', 'FULL_HOUR')),
  capacity INTEGER NOT NULL CHECK (capacity >= 1),
  updated_at INTEGER NOT NULL
);

-- 2. Parking Sessions Table
CREATE TABLE parking_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plate_number TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'CAR' CHECK (category IN ('CAR', 'BIKE', 'OTHER')),
  entry_time INTEGER NOT NULL,
  exit_time INTEGER,
  duration_minutes INTEGER,
  amount INTEGER,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'COMPLETED')),
  tariff_snapshot TEXT,
  CHECK (
    (status = 'ACTIVE' AND exit_time IS NULL AND amount IS NULL) OR
    (status = 'COMPLETED' AND exit_time IS NOT NULL AND amount IS NOT NULL
       AND duration_minutes IS NOT NULL AND tariff_snapshot IS NOT NULL
       AND exit_time >= entry_time)
  )
);

-- Partial Unique Index (Enforces Single Active Session per Vehicle)
CREATE UNIQUE INDEX ux_active_plate ON parking_sessions(plate_number)
  WHERE status = 'ACTIVE';

CREATE INDEX ix_sessions_entry ON parking_sessions(entry_time);
CREATE INDEX ix_sessions_exit ON parking_sessions(exit_time);

-- 3. Decoupled Payment Settlements Table
CREATE TABLE payments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL UNIQUE
    REFERENCES parking_sessions(id) ON DELETE RESTRICT,
  amount INTEGER NOT NULL CHECK (amount >= 0),
  payment_method TEXT NOT NULL CHECK (payment_method IN ('CASH', 'UPI', 'OTHER')),
  payment_status TEXT NOT NULL CHECK (payment_status IN ('UNPAID', 'PAID')),
  paid_at INTEGER
);

CREATE INDEX ix_payments_paid_at ON payments(paid_at);
```

---

## 6. Deterministic Billing Engine & Test Vectors

Duration is computed as pure elapsed integer minutes:
$$\text{durationMinutes} = \left\lfloor \frac{\text{exitMs} - \text{entryMs}}{60000} \right\rfloor$$

Fee computation formula:
$$\text{Charge} = \begin{cases} 
0, & \text{if } \text{durationMinutes} \le \text{graceMinutes} \\
\text{firstHourRate} + \left\lceil \frac{\max(0, \text{durationMinutes} - 60)}{60} \right\rceil \times \text{additionalHourRate}, & \text{for STARTED\_HOUR} \\
\text{firstHourRate} + \left\lfloor \frac{\max(0, \text{durationMinutes} - 60)}{60} \right\rfloor \times \text{additionalHourRate}, & \text{for FULL\_HOUR}
\end{cases}$$

### Standard Test Vectors (₹30 First Hour, ₹20 Additional Hour, 10-Min Grace)
| Duration | Description | `STARTED_HOUR` (Ceiling) | `FULL_HOUR` (Floor) |
|---|---|:---:|:---:|
| **0 min** | Instantaneous exit | **₹0** | **₹0** |
| **10 min** | Exactly at grace limit | **₹0** | **₹0** |
| **11 min** | Just beyond grace threshold | **₹30** | **₹30** |
| **60 min** | Exactly one hour | **₹30** | **₹30** |
| **61 min** | One hour plus one minute | **₹50** | **₹30** |
| **119 min** | One minute shy of two hours | **₹50** | **₹30** |
| **120 min** | Exactly two hours | **₹50** | **₹50** |
| **121 min** | Two hours plus one minute | **₹70** | **₹50** |
| **145 min** | Typical stay (2h 25m) | **₹70** | **₹50** |
| **520 min** | Overnight parking (8h 40m) | **₹190** | **₹170** |
| **1441 min** | Full 24 hours + 1 min | **₹510** | **₹490** |

---

## 7. Verification & Automated Testing

The project maintains a 100% pass rate across **54 automated unit, integration, and database tests**:

```bash
# Execute full automated test suite
flutter test
```

```
00:00 +54: All tests passed!
```

### Test Suite Coverage Breakdown:
1. **Billing Service Tests (`test/billing_service_test.dart` — 26 tests)**:
   - Validates all 11 test vectors under `STARTED_HOUR`.
   - Validates all 11 test vectors under `FULL_HOUR`.
   - Checks negative duration handling and `InvalidTimestampException`.
2. **Plate & Vision Service Tests (`test/plate_service_test.dart` — 17 tests)**:
   - Normalization: lower-case to uppercase, stripping hyphens/dots/spaces.
   - Validation: hard boundary length checks (4–12 chars) and soft warning heuristics.
   - OCR candidate ranking: standard plates, Bharat series (`22BH...`), and multi-line formats.
3. **Parking Service & SQLite Integration Tests (`test/parking_service_test.dart` — 11 tests)**:
   - In-memory database session lifecycle (`ACTIVE` -> `COMPLETED`).
   - Duplicate entry validation (`DuplicateActiveSessionException`).
   - Atomic exit concurrency and double-exit prevention (`AlreadyCompletedException`).
   - Immutable tariff snapshotting verification.
   - Physical disk persistence across database close and reopen cycles.

---

## 8. Build & Deployment Instructions

### Prerequisites
- **Flutter SDK**: 3.47.7+ (Channel stable)
- **Dart SDK**: 3.13.5+
- **Android SDK**: API Level 34 (Android 14), `minSdk 21` (Android 5.0 Lollipop)
- **Java**: OpenJDK 17 or 21
- **Python**: 3.10+ (for report and PDF compilation scripts)

### Installation & Verification
```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run static analysis
flutter analyze

# 3. Execute automated test suite
flutter test

# 4. Build optimized production release APK
flutter build apk --release
```

The resulting release APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk` *(Size: ~80.4 MB with ML Kit models included)*

### Physical Device Deployment
```bash
# Install directly to connected Android hardware
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
*Successfully verified on physical hardware device ID: `3080747934000CI`.*

---

## 9. Viva Q&A & Technical Defense Tips

When presenting SmartPark AI during evaluations or technical viva:
1. **Explain the Offline Rationale First**: Emphasize that in basement parking or remote highway lots, internet fails. An offline-first design guarantees 100% uptime with zero recurring cloud bills.
2. **Highlight the Concurrency Protections**: Reference the SQLite Partial Unique Index (`ux_active_plate`) and the atomic conditional SQL `UPDATE ... WHERE status = 'ACTIVE'`. This proves you understand database integrity and race conditions.
3. **Defend the Vision Architecture**: When asked why you used `image_picker` instead of a custom camera stream, explain that the Android Camera Intent delegates hardware sensor control (autofocus, macro lens, flash) to the OEM camera HAL, saving battery and eliminating memory leaks.
4. **Mention Tariff Snapshots**: Explain that yesterday's receipts must never change if tariffs are altered today. Serializing an immutable JSON snapshot at the moment of exit guarantees audit compliance.

---

## 10. Author & Copyright

- **Author & Lead Software Engineer**: **Kunal Chauhan**
- **Degree**: Bachelor of Technology (B.Tech) in Computer Science & Engineering
- **Institution**: Himachal Pradesh Technical University (HPTU) / ASIST
- **Copyright**: **© 2026 Kunal Chauhan. All rights reserved.**

*All source code, database schemas, user interface designs, mathematical models, and documentation artifacts are the intellectual property of Kunal Chauhan.*
