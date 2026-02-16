# Firebase package dependencies

The app uses **FirebaseAuth**, **FirebaseFirestore**, and **FirebaseStorage** from the Firebase iOS SDK.

## Why you don’t see FirebaseFirestoreSwift

**FirebaseFirestoreSwift** is no longer a separate product in the Firebase iOS SDK. Its Swift APIs (Codable, `@DocumentID`, `@ServerTimestamp`, etc.) were merged into **FirebaseFirestore**, so you only need to add **FirebaseFirestore** in Xcode. This project does not use `import FirebaseFirestoreSwift`; it uses `FirebaseFirestore` only.

## Adding Firebase in Xcode

1. **File → Add Package Dependencies…**
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Add these products to the **Unfin** target:
   - **FirebaseAuth**
   - **FirebaseFirestore**
   - **FirebaseStorage**

You will not see **FirebaseFirestoreSwift** in the list; that’s expected. The three products above are enough.
