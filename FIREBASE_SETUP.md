# Firebase setup for Unfin

Follow these steps to connect the app to Firebase.

## 1. Create a Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/).
2. Create a new project (or use an existing one).
3. Add an **iOS app** and register your app’s bundle ID (e.g. `io.unfin.app`).
4. Download **GoogleService-Info.plist** and add it to the **Afterlight** target in Xcode (drag into the project, ensure “Copy items if needed” and the Afterlight target are checked).

## 2. Add the Firebase SDK (Swift Package Manager)

1. In Xcode: **File → Add Package Dependencies…**
2. Enter: `https://github.com/firebase/firebase-ios-sdk.git`
3. Dependency rule: **Up to Next Major** (e.g. 11.0.0).
4. Click **Add Package**, then select these products:
   - **FirebaseAuth**
   - **FirebaseFirestore**
   - **FirebaseFirestoreSwift**
   - **FirebaseStorage**
5. Add to the **Afterlight** target and finish.

## 3. Enable Auth and Firestore

1. In Firebase Console → **Build → Authentication**: enable **Email/Password** sign-in.
2. In **Build → Firestore Database**: create a database (start in **production** or **test** mode; you can relax rules for development).
3. In **Build → Storage**: get started and leave default rules or adjust as needed.

## 4. Firestore security rules (minimal for development)

In Firestore **Rules**, you can start with something like this (tighten for production):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /ideas/{ideaId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null;
    }
    match /categories/{categoryId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    match /notifications/{notificationId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## 5. Firestore indexes

If Firestore asks for indexes, create them:

- **Collection:** `ideas`  
  Fields: `createdAt` (Descending)

- **Collection:** `notifications`  
  Fields: `targetDisplayName` (Ascending), `createdAt` (Descending)

You can also use the link in the Firestore error message to create the index in the console.

## 6. Build and run

1. Build the app in Xcode (**⌘B**).
2. Run on a simulator or device. Sign up with email/password; data will sync to Firebase (Auth, Firestore, Storage).

---

**Note:** The app configures Firebase in code when the store initializes. If `GoogleService-Info.plist` is missing or the package isn’t added, the app will crash on launch—complete steps 1 and 2 first.
