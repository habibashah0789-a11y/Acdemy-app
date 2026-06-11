# my_academy_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

**Academy App (Admin-only) — Additional Setup**

Follow these steps to configure Firebase, create an initial admin, and run tests.

1) Install dependencies:

```bash
flutter pub get
```

2) Configure Firebase for your platforms (recommended: use `flutterfire`):

- Create a Firebase project at https://console.firebase.google.com
- Register your Android/iOS/Web apps and download the required config files.
- Optionally run `flutterfire configure` to generate `firebase_options.dart`.

3) Firestore security rules (only admins may read/write):

- See `firebase_rules/firestore.rules` for a recommended starting point.

4) Create an initial admin account (server-side service account required):

Use the Node-based seed script included at `tool/seed_admin.js`. Install dependencies and run:

```powershell
cd tool
npm init -y
npm install firebase-admin
$env:SERVICE_ACCOUNT_PATH='C:\path\to\serviceAccountKey.json'
$env:ADMIN_EMAIL='admin@example.com'
$env:ADMIN_PASSWORD='ChangeMe!123'
node seed_admin.js
```

This script requires a Firebase service account JSON. It will create the user, set the `admin` custom claim, and write the admin entry to Firestore.

5) Run the app (Windows example):

```bash
flutter run -d windows
```

6) Run tests:

```bash
flutter test
```

Notes:
- Do NOT commit service account JSON or actual API keys. Use environment variables or secret managers.
- The app expects Firebase configuration (via `flutterfire configure` or manual platform config) before `Firebase.initializeApp()` succeeds.

