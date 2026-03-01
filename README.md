# Unfin

A collaborative creativity app where you post incomplete ideas (songs, stories, show concepts, poetry) and others can complete them.

## Features

- **Post ideas** — Share a melody hook, story start, show concept, or any unfinished idea.
- **Browse by type** — Filter the feed by **For You**, **Lyrics**, **Micro-Fiction**, **Melody**, **Concept**, or **Poetry**.
- **Complete ideas** — Open any idea and add your completion (verse, write, build, etc.).
- **Profile** — Set your display name and see ideas you’ve started.
- **Persistence** — Ideas and your name are saved locally on device (no backend required).

## How to run

1. Open **`Afterlight.xcodeproj`** (or **Unfin** if renamed) in Xcode (double‑click or **File → Open**).
2. Choose an iOS Simulator or a connected device (e.g. iPhone 16).
3. Press **⌘R** to build and run.

**Requirements:** Xcode 15+, iOS 17+.

## Project structure

- **AfterlightApp.swift** — App entry point (struct `UnfinApp`).
- **Models/Idea.swift** — Idea and contribution models, categories.
- **Services/IdeaStore.swift** — In-memory + JSON persistence for ideas and display name.
- **Views/** — Main tab, feed, create idea, idea detail, profile, and card components.

The UI follows your design: gradient background, glass-style cards, category tabs, FAB to add ideas, and bottom nav (Home, Explore, Profile).
