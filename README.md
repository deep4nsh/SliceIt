# SliceIt 🍕

**SliceIt** is a modern, intuitive expense-splitting application designed to make sharing costs with friends and family seamless and stress-free. Whether you're on a trip, sharing an apartment, or just dining out, SliceIt ensures everyone pays their fair share without the awkward math.

## ✨ Key Attractions

### 🚀 **Smart Debt Simplification**
Say goodbye to circular payments! SliceIt uses an advanced **greedy algorithm** to minimize the number of transactions required to settle up. It intelligently calculates who owes whom, reducing the total number of transfers needed within a group.

### 👥 **Effortless Group Management**
*   **Create Groups**: Easily organize expenses by trips, housemates, or events.
*   **Deep Linking**: Invite friends instantly via shareable links. No more manual adding!
*   **Real-time Updates**: Keep everyone in the loop with instant sync powered by Firebase.

### 💸 **Flexible Expense Tracking**
*   **Split Your Way**: Divide bills equally, unequally, or by exact amounts.
*   **Detailed History**: Keep a transparent record of all expenses and payments.
*   **Visual Analytics**: Understand your spending habits with beautiful charts and insights.

### 🎨 **Premium User Experience**
*   **Modern Design**: A sleek, "industry-grade" UI with smooth animations and a polished look.
*   **Dark Mode**: Fully supported dark theme for comfortable viewing at night.
*   **Secure & Private**: Built on Firebase Authentication to keep your data safe.

---

## 📸 Screenshots

| Home Screen | Group Details | Split Bill | Analytics |
|:---:|:---:|:---:|:---:|
| <img src="assets/images/SliceIt.png" width="200" /> | <img src="assets/images/SliceIt.png" width="200" /> | <img src="assets/images/SliceIt.png" width="200" /> | <img src="assets/images/SliceIt.png" width="200" /> |

*(Note: Replace placeholder images with actual screenshots)*

---

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (3.9.2 or later)
*   Dart SDK
*   Firebase Project (for Auth, Firestore, Functions)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/sliceit.git
    cd sliceit
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Configure Firebase:**
    *   Create a project in the [Firebase Console](https://console.firebase.google.com/).
    *   Enable **Authentication** (Email/Password, Google).
    *   Enable **Firestore Database**.
    *   Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) and place them in their respective directories (`android/app` and `ios/Runner`).
    *   *(Optional)* Use `flutterfire configure` to automatically set up Firebase.

4.  **Run the app:**
    ```bash
    flutter run
    ```

---

## � Usage

### 1. Creating a Group
*   Navigate to the **Groups** tab.
*   Tap the **"Create Group"** button.
*   Enter a group name and confirm.
*   Once created, tap the **Invite** icon to share a deep link with friends via email or other apps.

### 2. Splitting a Bill
*   Tap the **"+"** button or navigate to **Split Bill**.
*   **Scan Receipt**: The app attempts to parse the total amount from a receipt text (if available).
*   **Enter Details**: Manually enter the Title and Total Amount.
*   **Select Participants**: Choose friends from your contacts or add them by email.
*   **Split Type**:
    *   **Equal**: Automatically divides the total among selected participants.
    *   **Unequal**: Manually specify how much each person owes (must sum to total).
*   Tap **"Create Split"** to save.

### 3. Managing Expenses
*   Go to the **Expenses** tab to view your personal expense history.
*   **Filter**: Use the date range picker to view expenses for a specific period.
*   **Search**: Find expenses by title or category.
*   **Add/Edit**: Quickly add personal expenses or edit existing ones.

### 4. Settle Up (Debt Simplification)
*   Inside a group, the app automatically calculates the most efficient way to settle debts.
*   View the **"Balances"** section to see who owes whom.
*   Follow the suggested payments to clear debts with the fewest transactions.

---

## 📂 Project Structure

```
lib/
├── main.dart                  # App entry point & theme setup
├── firebase_options.dart      # Firebase configuration
├── models/                    # Data models (Participant, Expense, etc.)
├── screens/                   # UI Screens
│   ├── home_screen.dart       # Dashboard
│   ├── groups_screen.dart     # Group management
│   ├── expenses_screen.dart   # Personal expense tracking
│   ├── create_split_bill.dart # Bill splitting logic
│   └── ...
├── services/                  # Business logic & Services
│   ├── debt_simplifier.dart   # Greedy algorithm for debt simplification
│   ├── invite_service.dart    # Handling group invites
│   └── ...
├── utils/                     # Constants, Colors, Styles
└── widgets/                   # Reusable UI components
```

---

## �🛠️ Tech Stack

*   **Frontend**: Flutter (Dart)
*   **Backend**: Firebase (Auth, Firestore, Functions)
*   **State Management**: Provider
*   **Deep Linking**: Firebase Dynamic Links / App Links
*   **ML Integration**: Google ML Kit (for receipt scanning/smart features)

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:
1.  Fork the project.
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*SliceIt - Splitting bills has never been this smooth.*
