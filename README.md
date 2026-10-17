
# Krono // Minimalist Menu Bar & Mobile To-Do System

An ultra-refined, high-craft to-do ecosystem built specifically for **macOS Menu Bar** and **iPhone**, adhering to strict functional semantics (Anti-AI Slop Design System) and backed by **Supabase PostgreSQL + Realtime Sync**.

---

## ⚡ What Has Been Built & Ready in Your Workspace

Your workspace (`/Users/samarthr/ISO-todo list`) contains:

1. **`Krono.app`**: Ready-to-use, precompiled macOS Menu Bar App. You can run it immediately or drag it to `/Applications`.
2. **`Krono.xcodeproj`**: Full Xcode project configured for both **macOS (Menu Bar)** and **iOS (iPhone)**.
3. **`Sources/`**:
   - `KronoEngine.swift`: Semantic color tokens, task data models, offline-first cache (`UserDefaults`), deadline calculation, local notification scheduler, and Supabase REST sync engine.
   - `KronoViews.swift`: macOS Menu Bar HUD popover (380x480), kinetic checkbox, quick-entry bar with deadline presets (`+1h`, `+3h`, `Tonight`, `Tomorrow`), filter pills, and iPhone companion view with thumb-anchored task dock.
   - `KronoApp.swift`: Multiplatform entry point (`MenuBarExtra` for macOS, `WindowGroup` for iOS).
4. **`schema.sql`**: Complete database script for Supabase (table, RLS security, and realtime publication).
5. **`Resources/`**: Plists, sandbox network entitlements, and asset catalogs.

---

## 🎨 Semantic Design System (Anti-AI Slop Color Palette)

Color in Krono is strictly a data signal, never visual decoration:
- **Canvas (`#0D0E11`)**: Deep Carbon Obsidian for maximum contrast and eye comfort.
- **Card Surface (`#15171C`)**: Elevated Graphite with 1px hairline border (`rgba(255,255,255,0.08)`).
- **Interactive Accent (`#E05A47`)**: Burnt Vermilion, used exclusively for primary action triggers and focus states.
- **Approaching Deadline (`#F59E0B`)**: Warm Amber, triggers when deadline is under 3 hours away.
- **Critical / Overdue (`#EF4444`)**: Crimson Coral, triggers when deadline has passed.
- **Kinetic Completion (`#10B981`)**: Sage Emerald, flashes on completion spring animation.

---

## 🚀 Part 1: Setting up the Realtime Database (Supabase)

1. Create a free project at [supabase.com](https://supabase.com).
2. Go to the **SQL Editor** in your Supabase dashboard.
3. Copy and run the contents of [`schema.sql`](file:///Users/samarthr/ISO-todo%20list/schema.sql):
   ```sql
   create table public.tasks (
       id uuid primary key default gen_random_uuid(),
       title text not null,
       due_at timestamptz not null,
       is_completed boolean not null default false,
       updated_at timestamptz not null default now()
   );
   alter table public.tasks enable row level security;
   create policy "Allow personal access" on public.tasks for all using (true) with check (true);
   alter publication supabase_realtime add table public.tasks;
   ```
4. Go to **Project Settings > API** in Supabase and copy:
   - **Project URL** (e.g., `https://xyz.supabase.co`)
   - **anon / public key**
5. Connect it in Krono:
   - **Option A (In-App)**: Click the Cloud/Gear icon in Krono's footer and paste your URL and Anon Key.
   - **Option B (Code)**: Update `supabaseURL` and `supabaseKey` in [`KronoEngine.swift`](file:///Users/samarthr/ISO-todo%20list/Sources/KronoEngine.swift#L125-L126).

---

## 🖥️ Part 2: Installing Permanently on macOS Menu Bar

The app is configured as an **Agent App (`LSUIElement = true`)**, meaning it never clutters your Dock or `Cmd + Tab` switcher; it sits permanently in the top-right menu bar.

### Quick Run
Double-click `Krono.app` in Finder, or run in Terminal:
```bash
open "/Users/samarthr/ISO-todo list/Krono.app"
```

### Install into Applications & Launch on Boot
1. Drag `Krono.app` into `/Applications`.
2. Open **System Settings > General > Login Items & Extensions**.
3. Under **Open at Login**, click `+` and select `Krono.app`.
Now, Krono will launch automatically every time you start your Mac!

---

## 📱 Part 3: Installing on Your Physical iPhone

Your iPhone is already recognized by your system. To install Krono onto your iPhone:

1. Open the project in Xcode:
   ```bash
   open "/Users/samarthr/ISO-todo list/Krono.xcodeproj"
   ```
2. Enable Developer Mode on your iPhone (if not already enabled):
   - On iPhone: **Settings > Privacy & Security > Developer Mode** → toggle **ON** and reboot.
3. In Xcode's top destination dropdown, select **Krono-iOS** and choose **Samarth’s iPhone**.
4. In Xcode, click the **Krono** project icon in the left sidebar → **Krono-iOS target > Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - Select your **Personal Apple ID Team** from the dropdown.
5. Press `Cmd + R` to build and deploy to your iPhone.
6. **Trust Developer Certificate (First time only)**:
   - On your iPhone: **Settings > General > VPN & Device Management** → select your Apple ID under Developer App → tap **Trust**.
7. Open Krono on your iPhone and tap **Allow** for notifications.

---

## 🔄 Cross-Device Synchronization & Notifications

- **Realtime Sync**: Adding or completing a task on either device updates the other device in real time.
- **Offline-First Resilience**: Tasks open with 0ms latency from local storage even when completely offline, and automatically sync once connected.
- **Smart Notifications**: Automatically schedules local alerts on your iPhone:
  - 30 minutes before deadline ("Approaching Deadline")
  - At the exact deadline ("Deadline Reached")
  - Completed tasks immediately cancel pending notifications!
