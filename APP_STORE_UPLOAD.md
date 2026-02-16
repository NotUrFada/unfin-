# App Store Connect – Bundle ID and New App

## Bundle ID

**Use this exact value everywhere:**

```
io.unfin.app
```

(This was set because `com.afterlight.app` is already taken by another developer.)

---

## If the Bundle ID doesn’t show in “New App”

App Store Connect only lists **registered** App IDs. Register this one first:

1. Go to **https://developer.apple.com/account** and sign in.
2. Open **Certificates, Identifiers & Profiles** → **Identifiers**.
3. Tap the **+** button (top left).
4. Choose **App IDs** → **Continue** → **App** → **Continue**.
5. Set:
   - **Description:** e.g. `Unfin` (any label you like).
   - **Bundle ID:** choose **Explicit**, then enter: `io.unfin.app`
6. Enable any capabilities you use (e.g. Sign in with Apple, Push Notifications), then **Continue** → **Register**.

After that, when you create a **New App** in App Store Connect, the **Bundle ID** dropdown will include **io.unfin.app**. Pick it there.

---

## Quick check in Xcode

- Select the **Unfin** target → **Signing & Capabilities**.
- **Bundle Identifier** should be: `io.unfin.app`

If you change it in Xcode, use the same value when registering the App ID and when creating the app in App Store Connect.
