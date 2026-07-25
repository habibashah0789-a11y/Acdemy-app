# Quaid Academy App (my_academy_app)

A premium, feature-rich **Academy Management System** built with Flutter. The app allows administrators to easily manage student admissions, personal details, multiple subjects, specific class schedules/times, payment tracking, invoicing, PDF printing, and analytics.

---

## 🌟 Core Features

- **Multiple Subject Registration**: Register a student in multiple subjects (Biology, Physics, Chemistry, English, Math) simultaneously.
- **Subject-Specific Schedules**: Select a specific class schedule/time slot (e.g. `7:00 AM`, `8:00 AM`, etc.) independently for *each* enrolled subject.
- **Dual-Layer Database System**:
  - **Hive (Local Database)**: Fast, offline-first local caching for instant loads.
  - **Cloud Firestore (Cloud Database)**: Real-time central repository for cross-device database synchronization.
- **Automatic Offline Sync**: Monitors internet connectivity and automatically syncs local offline changes to Firebase Firestore once connection is restored.
- **Dynamic Fee structure & Tracking**:
  - Auto-calculates remaining due fees in real time based on active course fees and submitted amounts.
  - Maintains detailed logs of payment transaction histories.
  - Triggers customized payment notification logs.
- **Admin Analytics Dashboard**: Sleek visual representation of data including fee collection rates, active student metrics, and course strength statistics.
- **Student QR Pass System**: Generates a unique scan pass QR code for student check-ins and logs.
- **PDF Reports & Invoices**: Prints and downloads professional PDF report logs and fee invoice slips.
- **Recycle Bin Safe Delete**: Safe deletion system that moves deleted records to a recycle bin, from which admins can restore records or delete them permanently.
- **WhatsApp Integration**: Start instant chat sessions with students/parents using automated helpers.

---

## 📁 Directory Structure & Key Components

```text
lib/
├── main.dart                 # App initialization, Hive configurations, and run configurations
├── auth_service.dart         # Authentication helpers
├── models/                   # Database schemas
│   ├── student_model.dart    # Student entity, getters, computed fees, and subject-schedule mappings
│   ├── recycled_student.dart # Deleted student wrapper mapping deletedAt timestamps
│   └── notification_model.dart
├── services/                 # Business logic interfaces
│   ├── database_service.dart # Local Hive storage operations + cloud Firestore sync
│   ├── notification_service.dart # Announce registration and payment occurrences
│   ├── print_service.dart    # Custom PDF printing layout and document creation logic
│   └── sync_service.dart     # Background connectivity listener and batch syncing
├── students/                 # Screens related to students management
│   ├── add_student_screen.dart # Admission form with multi-subject checkbox/schedules picker
│   ├── edit_student_screen.dart# Edit student profile and courses panel
│   ├── student_detail_screen.dart# Visual profiles displaying subject timetables
│   └── student_list_screen.dart # Search directory with grade/year sorting
├── teachers/                 # Classrooms grouped by Class Type, Subject, and Grade
├── settings/                 # Admin configurations
│   ├── class_schedules_screen.dart # Chronological visual schedule grid per subject
│   └── recycle_bin_screen.dart# Trash management console
├── utils/                    # Shared utilities
│   ├── whatsapp_helper.dart  # Formats phone inputs and launches WhatsApp
│   └── image_utils.dart      # Local directory picture compression and disk-saving helpers
└── theme/                    # Theme configuration and custom styling parameters
```

---

## 🛠️ Data Model & Schema Details

### `StudentModel` Attributes
- `id`: Unique generated identifier code.
- `firstName` & `lastName`: Combined into a computed `fullName` / `name` getter.
- `fatherName`: Father's name.
- `phone`: Primary mobile number (direct link to WhatsApp).
- `email`: Optional email address.
- `classType`: 'FSc' or 'Matric'.
- `grade`: Ninth, Tenth, First Year, or Second Year.
- `subject`: Comma-separated list of selected subjects (e.g. `"Physics, Chemistry"`).
- `schedule`: Formatted string mapping subjects to times (e.g. `"Physics: 8:00 AM, Chemistry: 9:00 AM"`).
- `subjectSchedulesJson`: Serialized JSON map (`{"Physics": "8:00 AM", "Chemistry": "9:00 AM"}`) for easy profile editing.
- **Fees**:
  - `biologyFee`, `physicsFee`, `chemistryFee`, `englishFee`, `mathFee`: Specific fees set per subject.
  - `feeSubmitted`: Total cumulative payment submitted.
  - `feeRemaining`: Dynamically computed as `totalFee - feeSubmitted`.
- `profilePicUrl`: File path (local device) or Firebase storage URL (cloud).
- `isActive`: Boolean indicating active enrollment status.

---

## 🚀 How to Run the Project

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Configure Google Firebase settings on the Firebase Console.

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Database Adapters
Generate or update the binary serialization adapters for Hive:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Firebase Setup
1. Create a Firebase project and enable **Firestore Database**, **Authentication (Email/Password)**, and **Storage**.
2. Run `flutterfire configure` to generate `firebase_options.dart` automatically.
3. Apply security rules in Firestore using the file located in `firebase_rules/firestore.rules`.

### 4. Create Initial Admin Credentials
Configure and execute the Javascript seed script inside the `tool/` directory:
```powershell
cd tool
npm install
$env:SERVICE_ACCOUNT_PATH='C:\path\to\serviceAccountKey.json'
$env:ADMIN_EMAIL='admin@example.com'
$env:ADMIN_PASSWORD='securePassword123'
node seed_admin.js
```

### 5. Run & Test the Application
Run the desktop Windows app or device emulator:
```bash
flutter run -d windows
```

Run unit tests:
```bash
flutter test
```


