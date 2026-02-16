REQUIRED: Add your app icon here.

1. Create or export a square image exactly 1024×1024 pixels (PNG, no transparency for App Store).
2. Name it: AppIcon.png
3. Put it in this folder (same folder as this README and Contents.json).
   Full path: Afterlight/Assets.xcassets/AppIcon.appiconset/AppIcon.png

4. In Xcode: open Assets.xcassets → AppIcon → drag your 1024×1024 image into the "App Store iOS" slot (or replace the empty slot).
5. Clean build (Product → Clean Build Folder), then re-archive and upload a new build to App Store Connect.

Until AppIcon.png exists, the app will use a placeholder and App Store Connect will show the grid icon.
