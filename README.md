# Krono

**A minimalist task manager for the macOS menu bar and iPhone.**

Krono helps you capture tasks quickly, set deadlines, and keep your task list in sync across your Mac and iPhone. It is built with SwiftUI and uses Supabase for cloud storage.

> **Before you use it:** Krono's source currently contains pre-filled Supabase development credentials. Set up **your own Supabase project** and enter its credentials in Krono before adding tasks. Do not use the maintainer's demo backend for personal tasks.

## Features

- **Quick task capture** — add a task without leaving the menu bar on macOS.
- **Deadline presets** — choose +1 hour, +3 hours, tonight, or tomorrow on Mac.
- **Deadline indicators** — see whether a task is upcoming, due soon, or overdue.
- **Completed-task logbook** — mark tasks done and review completed work.
- **Mac + iPhone sync** — share tasks between devices through Supabase. The app checks for remote changes about every four seconds while running.
- **Offline-friendly storage** — your current task list is cached locally, and pending edits are retained for retry if a cloud request fails.
- **Deadline notifications** — optional alerts 30 minutes before a deadline and at the deadline.

## Requirements

- A **Mac** running macOS 14 or later.
- **Xcode 15 or later** to build the project.
- For the iPhone app: an iPhone running iOS 17 or later, connected to your Mac for installation.
- A [Supabase](https://supabase.com/) project for cloud sync.

There is currently no downloadable app release on this repository, so install Krono by building it from source in Xcode.

## 1. Download the project

Open Terminal and run:

```bash
git clone https://github.com/r-samarth/Krono.git
cd Krono
open Krono.xcodeproj
```

If you prefer, use GitHub's **Code → Download ZIP**, extract it, and open `Krono.xcodeproj`.

## 2. Set up Supabase

You need to do this on your own Supabase project so your app is not connected to the maintainer's development database.

1. Create a project at [supabase.com](https://supabase.com/) and wait for it to finish provisioning.
2. Open the project's **SQL Editor**.
3. Open [`schema.sql`](schema.sql) from this repository, copy its contents, paste them into the SQL Editor, and run the script. This creates the `public.tasks` table and configures the policies used by the current app.
4. In your Supabase project settings, find the **Project URL** and the **publishable key / anon public key**.
5. Keep these values handy for the next step.

**Never put a Supabase `service_role` key or secret key in the app.** The app needs a client-side publishable/anon key.

### Important privacy limitation

The current `schema.sql` uses a permissive policy (`USING (true)` and `WITH CHECK (true)`) and Krono does not currently implement sign-in or per-user data separation. That means the table is **not private**: a person who has the project's URL and public key can read or change its tasks.

Use this setup for testing with non-sensitive tasks only. Before using Krono for private personal data or releasing it to multiple users, add Supabase Auth and row-level security policies that restrict each user to their own tasks. A public/anon key alone does not make a database private.

## 3. Connect Krono to your Supabase project

Run Krono and open its cloud settings:

- **macOS:** click the Krono icon in the menu bar, then click the gear icon in the popover footer.
- **iPhone:** open Krono and tap the gear icon near the top-right corner.

Enter your own **Project URL** and **publishable/anon public key**, then tap **Save & Connect**. Do this on **both devices**, using the same Supabase project on each.

Replace the pre-filled values rather than leaving the app connected to the maintainer's development project.

## 4. Build and run on your Mac

1. In Xcode, select the **Krono-macOS** scheme from the scheme menu.
2. Select **My Mac** as the run destination.
3. Press **⌘R** or click **Run**.
4. After it launches, look for the Krono icon in the **macOS menu bar**, near the system icons.

Krono is designed as a menu-bar app, so it may not appear in the Dock like a regular windowed app.

### Optional: keep Krono available after login

Once you've built and run the app, you can add the installed app to **System Settings → General → Login Items** if you want it to open when you sign in.

## 5. Build and run on your iPhone

1. Connect your iPhone to your Mac and unlock it.
2. In Xcode, select the **Krono-iOS** scheme.
3. Choose your connected iPhone as the run destination.
4. Select the project in Xcode, open the **Krono-iOS** target's **Signing & Capabilities** settings, and enable **Automatically manage signing**.
5. Choose your Apple Developer team. A personal team may be used for development if available to your account.
6. Press **⌘R** to build and install the app.
7. If Xcode or iOS asks you to enable Developer Mode or trust a developer profile, follow the prompts shown on your device.
8. Open Krono, enter the same Supabase Project URL and public key you used on the Mac, and allow notifications if you want deadline alerts.

## Using Krono

### Add a task

- **Mac:** click the Krono menu-bar icon, type a task into the task field, choose a deadline preset, and press Return or the arrow button.
- **iPhone:** open the app and use the task-entry controls to add a task and set its deadline.

### Complete a task

Tap or click the checkbox beside the task. Completed tasks are moved out of the active-task group and can be reviewed in the completed-task/logbook view where available.

### Sync between devices

Keep both devices online and connected to the same Supabase project. Krono checks for cloud changes periodically while running. On iPhone, you can also tap the refresh icon to request a sync.

If you make a change while offline, leave Krono installed and open it again when you have a connection so pending changes can be retried.

### Notifications

Krono can schedule a reminder about 30 minutes before a deadline and another at the deadline. Notifications require permission from macOS or iOS. Completed tasks are not scheduled for future deadline alerts.

## Troubleshooting

**Tasks do not appear on both devices**
- Confirm both devices use the same Project URL and public key.
- Check that the `public.tasks` table exists in Supabase and that the `schema.sql` setup completed successfully.
- Confirm the device is online, then tap the iPhone refresh icon or wait for the next sync cycle.
- Recheck the credentials in Krono's cloud settings if you see a sync error.

**A task looks completed and then becomes active again**
- Pull the latest code from `main` and rebuild the app on each device. Recent versions include fixes for saving the correct task and protecting newer local changes from stale cloud responses.
- Make sure both devices are running the updated build and connected to the same Supabase project.

**Xcode reports a signing error on iPhone**
- Select the `Krono-iOS` target, enable automatic signing, and choose your team.
- Ensure the iPhone is unlocked and selected as the run destination.

**The app does not appear in the Mac Dock**
- That is expected: Krono runs from the menu bar. Look near the system icons at the top of the screen.

**Supabase returns an HTTP error**
- Verify your Project URL and public/anon key.
- Check the Supabase project's API status and make sure you ran the SQL setup script.
- Do not substitute the `service_role` key for the client key.

## Project structure

```text
Krono/
├── Krono.xcodeproj/       # Xcode project for macOS and iOS
├── Sources/
│   ├── KronoApp.swift     # Multiplatform app entry point
│   ├── KronoEngine.swift  # Task model, persistence, notifications and sync
│   └── KronoViews.swift   # macOS and iPhone SwiftUI views
├── Resources/             # App icons, assets, plist files and entitlements
├── schema.sql             # Supabase table and policy setup
└── project.yml            # XcodeGen project definition
```

## Contributing

Bug reports and improvements are welcome. Please include your device, OS version, steps to reproduce, and any relevant error message when reporting a problem. Do not include Supabase secret keys or private task data in an issue.

---

Built by [Sam](https://github.com/r-samarth).
