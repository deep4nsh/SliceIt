    # SliceIt 🍕

**SliceIt** is a modern, premium expense-splitting application designed to make sharing costs with friends and family seamless, offline-resilient, and stress-free. Built with a beautiful dark-first aesthetic, rich micro-animations, and powered by Firebase, SliceIt ensures everyone pays their fair share without the awkward math.

---

## ✨ Features & Attractions

### 🚀 Smart Debt Simplification & Settlement Tracking
Say goodbye to complex circular payments.
* **Greedy Algorithm**: SliceIt uses a highly efficient greedy algorithm in [debt_simplifier.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/debt_simplifier.dart) to minimize transactions within any group.
* **Settlement Recording**: Track who paid whom with [settlement_service.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/settlement_service.dart) and browse previous settlements in the [settlement_history_screen.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/screens/settlement_history_screen.dart).
* **UPI Payment Support**: Quick payments initiated with UPI VPAs using [upi_payment_service.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/upi_payment_service.dart).

### 🔔 Automatic & On-Demand Notification System
Keep group members up-to-date with push notifications triggered via Firebase Cloud Functions in [functions/index.js](file:///Users/deepansh/StudioProjects/SliceIt/functions/index.js).
* **Automatic Triggers**: Receive instant updates when a new expense is added, when you are added to a group, or when a payment is marked successful.
* **Manual Settlement Reminders**: Trigger reminders on-demand in the Balances tab of [group_detail_screen.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/screens/group_detail_screen.dart) to instantly alert members who owe money.
* **Granular Client Preferences**: Toggle pushing notifications on/off globally or per-category (Expense Updates, Group Invites, Settlement Reminders, Payment Reminders) directly in [profile_screen.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/screens/profile_screen.dart) with local caching in [notification_preferences.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/notification_preferences.dart).

### 📶 Offline Mode & Synchronized Caching
No network? No problem. SliceIt keeps running smoothly with offline-first capabilities.
* **Hive Data Caching**: Read and write local database models via [offline_service.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/offline_service.dart).
* **Connectivity Awareness**: Utilizes [connectivity_service.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/connectivity_service.dart) to detect changes in network status.
* **Sync Queue**: Automatically queues offline mutations and pushes them to Firebase Firestore once connection is restored.

### 👥 Native Group Invitations & Deep Linking
* **Native Share Sheet**: Send invite links instantly to contacts using a native OS sharing panel via [invite_service.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/invite_service.dart).
* **App Links & Deep Linking**: Seamlessly parse incoming invitation links using [deep_link_config.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/utils/deep_link_config.dart).
* **Join Verification Dialogs**: Validate details automatically in a user-friendly UI before adding users to groups.

### 📊 Group Analytics & Charts
* **Rich Visualizations**: Custom charts (Pie, Bar, Line) rendered with `fl_chart` in [analytics_screen.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/screens/analytics_screen.dart).
* **Spend Segmentation**: Track categories (Food, Travel, Rent, Utilities) and individual member share analytics via [group_analytics_service.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/group_analytics_service.dart).

### 📄 Professional PDF Exports
* **Custom Reports**: Generate high-fidelity PDFs containing group details, expense reports, and settlement logs via [pdf_export_service.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/pdf_export_service.dart).
* **Printing Integration**: Directly preview, share, or print generated PDFs in-app.

### 🧾 Receipt Parsing & Itemized Splits
* **Receipt OCR**: Automatically scan and extract text from receipts using Google ML Kit Text Recognition with [bill_parser_service.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/services/bill_parser_service.dart).
* **Itemized Splits**: Assign individual items to specific group members for highly precise bill splits.

### 🔁 Subscription Management
* **Recurring Bills**: Track subscription metrics and split recurring expenses automatically on custom intervals in [subscriptions_screen.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/screens/subscriptions_screen.dart).

---

## 🎨 Design System & Aesthetics
SliceIt stands out with a tailored, modern design system:
* **Dark-First Theme**: Curated dark palette with vibrant olive green accents configured in [app_theme.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/utils/app_theme.dart).
* **Fluid Backgrounds**: Stunning visuals using the customized [mesh_background.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/widgets/mesh_background.dart).
* **Sleek Cards**: Premium glassmorphism feel using the [modern_card.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/widgets/modern_card.dart) widget.
* **Component Standardization**: Responsive layout tokens in [app_spacing.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/utils/app_spacing.dart) and high-quality animated buttons using [custom_button.dart](file:///Users/deepansh/StudioProjects/SliceIt/lib/widgets/custom_button.dart).

---

## 📂 Project Structure

```
SliceIt/
├── functions/                     # Backend Firebase Cloud Functions (Node.js)
│   └── index.js                   # Cloud triggers & Callable notification functions
├── assets/                        # Design assets, custom fonts & icons
├── lib/
│   ├── main.dart                  # App initialization, Providers & routes
│   ├── firebase_options.dart      # Autogenerated configuration
│   ├── models/                    # Data models
│   │   ├── expense_model.dart     # Expense data structure
│   │   ├── group_model.dart       # Group schema mapping
│   │   ├── subscription_model.dart# Recurring bill settings
│   │   └── settlement_model.dart  # Completed settlements
│   ├── screens/                   # UI Modules
│   │   ├── home_screen.dart       # Main Dashboard
│   │   ├── group_detail_screen.dart# balances, PDF, reminders & list tabs
│   │   ├── profile_screen.dart     # User profile and notification toggles
│   │   ├── subscriptions_screen.dart# Recurring bill tracker
│   │   └── analytics_screen.dart   # Interactive FL Charts
│   ├── services/                  # Business logic and external API integrations
│   │   ├── offline_service.dart   # Hive CRUD caching & synchronization queue
│   │   ├── notification_service.dart# FCM listeners & local notifications
│   │   ├── pdf_export_service.dart# PDF document layout generation
│   │   └── debt_simplifier.dart   # Math/algorithm logic for splitting
│   ├── utils/                     # Color tokens, styles, spacers, configurations
│   └── widgets/                   # Centralized reusable widgets
```

---

## ⚙️ Tech Stack & Dependencies

* **Core Platform**: [Flutter SDK](https://flutter.dev) (v3.9.2+) & [Dart](https://dart.dev)
* **Backend Platform**: [Firebase Suite](https://firebase.google.com) (Auth, Firestore, Cloud Functions, Messaging)
* **Database & Caching**: [Hive](https://pub.dev/packages/hive) (Offline Store), [shared_preferences](https://pub.dev/packages/shared_preferences) (User Preferences)
* **Design & Animations**: [flutter_animate](https://pub.dev/packages/flutter_animate), [fl_chart](https://pub.dev/packages/fl_chart)
* **OCR Text Extraction**: [google_mlkit_text_recognition](https://pub.dev/packages/google_mlkit_text_recognition)
* **Device Utility**: [share_plus](https://pub.dev/packages/share_plus), [app_links](https://pub.dev/packages/app_links), [connectivity_plus](https://pub.dev/packages/connectivity_plus), [flutter_contacts](https://pub.dev/packages/flutter_contacts)
* **Document Generation**: [pdf](https://pub.dev/packages/pdf), [printing](https://pub.dev/packages/printing)

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
* [Firebase CLI](https://firebase.google.com/docs/cli) installed and configured.
* A registered Firebase project.

### Local Setup
1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/sliceit.git
   cd sliceit
   ```
2. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```
3. **Configure Firebase:**
   Generate platform-specific Firebase configuration using FlutterFire CLI:
   ```bash
   flutterfire configure --project=sliceit-124
   ```
   Alternatively, place the downloaded `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in their respective platform folders.
4. **Launch the application:**
   ```bash
   flutter run
   ```

### ⚡ Backend Deploy (Cloud Functions)
To activate push notifications, triggers, and manual settlement reminders, deploy the Node.js functions:
1. Navigate to the functions directory:
   ```bash
   cd functions
   ```
2. Deploy code to your Firebase backend:
   ```bash
   firebase deploy --only functions
   ```
3. Follow function execution logs:
   ```bash
   firebase functions:log --follow
   ```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:
1. Fork this repository.
2. Create a specific branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes with descriptive messages (`git commit -m 'feat: Add some amazing feature'`).
4. Push your branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*SliceIt - Splitting bills has never been this smooth.*
