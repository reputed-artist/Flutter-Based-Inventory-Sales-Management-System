# 📦 Flutter-Based Inventory & Sales Management System

<p align="center">
  <strong>A smart, cross-platform solution for inventory and sales management.</strong>
  <br />
  Powered by Flutter & Supabase for backend services, authentication, and data synchronization.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Framework-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-Language-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-Backend-3FCF8E?logo=supabase&logoColor=white" alt="Supabase" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Cross--platform-4CAF50" alt="Platforms" />
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT License" />
</p>

---

## ✨ Overview

The **Flutter-Based Inventory & Sales Management System** is designed to simplify inventory operations and sales tracking through a modern application interface.

Built with Flutter and integrated with Supabase, the application provides backend services, authentication, and database synchronization to support inventory and sales workflows.

## 🚀 Features

| Feature | Description |
|---|---|
| 📦 **Inventory Management** | Manage products and inventory records. |
| 🛒 **Sales Management** | Track sales and transaction records. |
| ☁️ **Supabase Integration** | Connect to a cloud backend and database. |
| 🔐 **Authentication** | Supports anonymous sign-in through Supabase. |
| 🗄️ **Database Migrations** | Set up the database schema using SQL migrations. |
| 📱 **Android APK** | Build a release APK for Android devices. |
| 🔄 **Cross-Platform Architecture** | Built with Flutter for cross-platform development. |

## 🛠️ Tech Stack

- **Frontend:** Flutter
- **Programming Language:** Dart
- **Backend & Database:** Supabase
- **Authentication:** Supabase Auth
- **Database Setup:** SQL migrations
- **Version Control:** Git & GitHub

## 📋 Prerequisites

Before getting started, install the following:

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Dart SDK](https://dart.dev/get-dart) — included with Flutter
- [Git](https://git-scm.com/downloads)
- [Android Studio](https://developer.android.com/studio) or [Visual Studio Code](https://code.visualstudio.com/)
- A [Supabase account](https://supabase.com/)

Verify your Flutter installation:

```bash
flutter doctor
```

## ⚡ Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/reputed-artist/Flutter-Based-Inventory-Sales-Management-System.git
```

Navigate to the project directory:

```bash
cd Flutter-Based-Inventory-Sales-Management-System
```

### 2. Install Dependencies

Run the following command to install the packages defined in `pubspec.yaml`:

```bash
flutter pub get
```

### 3. Create a Supabase Project

1. Open the [Supabase Dashboard](https://supabase.com/dashboard).
2. Sign in to your account.
3. Select **New Project**.
4. Enter a project name and configure your database password and region.
5. Wait for the project to finish provisioning.

### 4. Get Your Supabase Credentials

Open your project in the Supabase Dashboard and locate the API settings.

Copy these values:

- **Project URL**
- **Publishable Key** — typically begins with `sb_publishable_`

Keep these values available for the next step.

### 5. Configure Supabase

Open the following file in your project:

```text
lib/services/supabase_service.dart
```

Locate the default configuration:

```dart
static const String _defaultUrl = 'Copy paste Project URL';
static const String _defaultKey =
    'Copy paste Publishable Key';
```

Replace the placeholders with your own Supabase project details:

```dart
static const String _defaultUrl =
    'https://YOUR_PROJECT_REF.supabase.co';

static const String _defaultKey =
    'sb_publishable_YOUR_PUBLISHABLE_KEY';
```

**Important:** The values above are examples. Use the actual URL and publishable key from your Supabase project.

Never place a Supabase `service_role` key or secret key in a Flutter application.

### 6. Enable Anonymous Authentication

If your application uses anonymous sign-in, configure it in Supabase:

1. Open the Supabase Dashboard.
2. Select your project.
3. Navigate to **Authentication → Sign In / Providers** or the equivalent provider settings.
4. Enable **Allow anonymous sign-ins**.
5. Confirm that user sign-ups are enabled if required by your project configuration.
6. Save the changes.

> **Note:** Anonymous authentication is different from email/password authentication. Enable the anonymous sign-in option specifically.

### 7. Set Up the Database

The application requires its database schema and appropriate access policies to be configured before use.

1. Locate the project's SQL migration files and additional setup scripts.
2. Open **Supabase Dashboard → SQL Editor**.
3. Open the required SQL migration file from your repository.
4. Review the statements and copy the SQL into the SQL Editor.
5. Execute the migration.
6. Repeat for the remaining migrations, following their required order.
7. Verify that the required tables, indexes, functions, triggers, and Row Level Security (RLS) policies have been created.

If your project is configured for the Supabase CLI, you may use the repository's documented migration workflow instead:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Use the CLI commands only after installing and configuring the CLI and verifying the migration files.

**⚠️ Important:** Review destructive SQL commands before executing them. Avoid rerunning migrations unless they are designed to be safely repeated.

### 8. Run the Application

Check the available devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

To target a particular device:

```bash
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with an identifier returned by `flutter devices`.

## 📱 Build the Android APK

To generate a release APK, execute:

```bash
flutter build apk --release
```

After a successful build, your APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Transfer the APK to a compatible Android device to install and test the application.

## 🧰 Troubleshooting

<details>
<summary><strong>🔐 Anonymous sign-in fails</strong></summary>

- Verify that anonymous sign-ins are enabled in Supabase.
- Check that the Project URL and publishable key are correct.
- Confirm that the device has an active internet connection.
- Review Supabase authentication logs for additional details.

</details>

<details>
<summary><strong>🗄️ Database or permission errors</strong></summary>

- Verify that all required SQL migrations have been applied.
- Check the database tables and RLS policies.
- Confirm that the policies permit the intended operations for the application's authenticated or anonymous users.
- Review Supabase logs for permission-related errors.

</details>

<details>
<summary><strong>📦 Flutter dependencies fail to resolve</strong></summary>

Try refreshing the project dependencies:

```bash
flutter clean
flutter pub get
```

Then run the application again.

</details>

## 🔑 Demo Login Passcodes

Use the following passcodes to test the application's login functionality, if supported by your current app configuration.

| Demo Account | Passcode |
|---|---|
| Demo User 1 | `2222` |
| Demo User 2 | `3333` |
| Demo User 3 | `4444` |
| Demo User 4 | `5555` |

> **📝 Note:** These are demo passcodes for testing purposes. Make sure they match the passcodes configured in your application. Do not use these simple passcodes for production accounts.

## 🔒 Security Best Practices

- Never commit service-role keys, secret keys, database passwords, or other private credentials.
- Use only the appropriate publishable key in the Flutter client.
- Enable and configure RLS policies for database tables.
- Give anonymous users only the minimum permissions required.
- Do not disable RLS on sensitive tables to work around permission errors.
- Consider account linking and account recovery if users need persistent identities or cross-device access.

**Remember:** A publishable key is intended for client-side use, but it does not replace database access controls.

## 🤝 Contributing

Contributions, suggestions, and improvements are welcome!

1. Fork this repository.
2. Create a feature branch.
3. Commit your changes.
4. Submit a pull request describing your improvements.

Please open a GitHub Issue to report bugs or discuss potential features.

## 📜 License

This project is licensed under the **MIT License**. See the [`LICENSE`](LICENSE) file for details.

Ensure that a valid `LICENSE` file containing the full MIT License text is present in the repository root.

## 📬 Contact

For support, questions, or suggestions:

- **Email:** [tejaschavda2020@gmail.com](mailto:tejaschavda2020@gmail.com)
- **Issues:** [GitHub Issues](https://github.com/reputed-artist/Flutter-Based-Inventory-Sales-Management-System/issues)

---

<p align="center">
  <strong>Built with ❤️ using Flutter & Supabase</strong>
  <br />
  <sub>Streamlining inventory and sales, one transaction at a time.</sub>
</p>
