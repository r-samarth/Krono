import SwiftUI
import UserNotifications
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - 1. SEMANTIC DESIGN SYSTEM (ANTI-SLOP COLOR ARCHITECTURE)
enum KronoTheme {
    static let canvas = Color(hex: "0D0E11")         // Deep Carbon Obsidian
    static let surface = Color(hex: "15171C")        // Elevated Graphite Card
    static let surfaceHover = Color(hex: "1D2028")   // Interactive Row State
    static let border = Color.white.opacity(0.08)   // 1px Hairline Border
    
    static let inkPrimary = Color(hex: "F3F4F6")    // Primary Crisp Ink
    static let inkMuted = Color(hex: "8A8F9E")      // Secondary Metadata Slate
    
    // Semantic Signal Colors (Every color has a strict functional meaning)
    static let accent = Color(hex: "E05A47")        // Burnt Vermilion: Primary Action
    static let warning = Color(hex: "F59E0B")       // Warm Amber: Due under 3 hours
    static let critical = Color(hex: "EF4444")      // Crimson Coral: Overdue
    static let completed = Color(hex: "10B981")     // Sage Emerald: Completed State
    
    static func deadlineColor(for date: Date, isCompleted: Bool) -> Color {
        if isCompleted { return completed }
        let remaining = date.timeIntervalSinceNow
        if remaining < 0 { return critical }
        if remaining < 3 * 3600 { return warning }
        return inkMuted
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - 2. DATA MODEL
struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var dueAt: Date
    var isCompleted: Bool
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case dueAt = "due_at"
        case isCompleted = "is_completed"
        case updatedAt = "updated_at"
    }
    
    var relativeDeadlineText: String {
        let diff = Int(dueAt.timeIntervalSinceNow)
        if isCompleted { return "Completed" }
        if diff < 0 {
            let mins = abs(diff) / 60
            return mins < 60 ? "Overdue \(mins)m" : "Overdue \(mins / 60)h"
        }
        let mins = diff / 60
        if mins < 60 { return "Due in \(max(1, mins))m" }
        let hours = mins / 60
        if hours < 24 { return "Due in \(hours)h \(mins % 60)m" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: dueAt)
    }
}

// MARK: - 3. NATIVE DEADLINE NOTIFICATION SCHEDULER (iOS & macOS)
final class NotificationManager {
    static let shared = NotificationManager()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    func syncNotifications(for tasks: [TaskItem]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        for task in tasks where !task.isCompleted && task.dueAt > Date() {
            // 1. 30-Minute Heads-Up Reminder
            let warningDate = task.dueAt.addingTimeInterval(-30 * 60)
            if warningDate > Date() {
                schedule(
                    id: "\(task.id.uuidString)-warn",
                    title: "Approaching Deadline (30m)",
                    body: task.title,
                    date: warningDate
                )
            }
            // 2. Exact Deadline Alert
            schedule(
                id: "\(task.id.uuidString)-due",
                title: "Deadline Reached",
                body: task.title,
                date: task.dueAt
            )
        }
    }
    
    private func schedule(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - 4. REALTIME CLOUD + OFFLINE-FIRST STORE
@MainActor
final class TaskStore: ObservableObject {
    // Paste Supabase project credentials here or configure dynamically via the Settings dialog
    @Published var supabaseURL: String = "https://uuymrzihjlbvkkjdnlfo.supabase.co"
    @Published var supabaseKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV1eW1yemloamxidmtramRubGZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIyMTg1MDksImV4cCI6MjEwNzc5NDUwOX0.CtEBxMv_QUbBTIJggGLBBlPeO9iEzGB8Gr98LZv_rGA"
    
    @Published var tasks: [TaskItem] = []
    @Published var isSyncing: Bool = false
    @Published var lastSyncError: String? = nil
    
    private let cacheKey = "krono_local_tasks_v1"
    private let configUrlKey = "krono_supabase_url"
    private let configAnonKey = "krono_supabase_key"
    private var syncTimer: AnyCancellable?
    private let pendingChangesKey = "krono_pending_changes_v1"

    private struct PendingChanges: Codable {
        var upserts: [TaskItem]
        var deletions: [UUID]
    }

    // A small durable outbox prevents a temporary network failure from losing a task edit.
    private var pendingUpserts: [UUID: TaskItem] = [:]
    private var pendingDeletes: Set<UUID> = []
    private var inFlightUpserts: Set<UUID> = []
    private var inFlightDeletes: Set<UUID> = []
    private var isFetchingRemote = false
    private var localMutationRevision: UInt64 = 0
    
    var activeCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }
    
    var hasCloudConfig: Bool {
        !supabaseURL.contains("YOUR_PROJECT_ID") &&
        !supabaseKey.contains("YOUR_SUPABASE_ANON_KEY") &&
        !supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !supabaseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init() {
        // Load persisted credentials if previously entered
        if let savedUrl = UserDefaults.standard.string(forKey: configUrlKey), !savedUrl.isEmpty {
            self.supabaseURL = savedUrl
        }
        if let savedKey = UserDefaults.standard.string(forKey: configAnonKey), !savedKey.isEmpty {
            self.supabaseKey = savedKey
        }
        
        loadPendingChanges()
        loadFromLocalCache()
        NotificationManager.shared.requestPermission()
        
        // Poll every 4 seconds for instant cross-device state recognition
        syncTimer = Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.fetchRemoteTasks() }
            }
            
        Task { await fetchRemoteTasks() }
    }
    
    func saveCredentials(url: String, key: String) {
        self.supabaseURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        self.supabaseKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(self.supabaseURL, forKey: configUrlKey)
        UserDefaults.standard.set(self.supabaseKey, forKey: configAnonKey)
        Task { await fetchRemoteTasks() }
    }
    
    func addTask(title: String, dueAt: Date) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newTask = TaskItem(
            id: UUID(),
            title: trimmed,
            dueAt: dueAt,
            isCompleted: false,
            updatedAt: Date()
        )
        
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            tasks.insert(newTask, at: 0)
            sortTasks()
        }
        localMutationRevision &+= 1
        markForUpsert(newTask)
        triggerHaptic(isSuccess: false)
        saveToLocalCache()

        Task { await pushUpsert(newTask) }
    }
    
    func toggleTask(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        // Capture the updated task BEFORE sorting: sorting can move it to a different index.
        var updated: TaskItem?
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            tasks[idx].isCompleted.toggle()
            tasks[idx].updatedAt = Date()
            updated = tasks[idx]
            sortTasks()
        }

        guard let updated else { return }
        localMutationRevision &+= 1
        markForUpsert(updated)
        triggerHaptic(isSuccess: updated.isCompleted)
        saveToLocalCache()
        Task { await pushUpsert(updated) }
    }

    func deleteTask(_ task: TaskItem) {
        localMutationRevision &+= 1
        markForDeletion(task.id)
        withAnimation(.easeOut(duration: 0.2)) {
            tasks.removeAll { $0.id == task.id }
        }
        saveToLocalCache()
        Task { await pushDelete(task.id) }
    }
    
    private func sortTasks() {
        tasks.sort {
            if $0.isCompleted != $1.isCompleted {
                return !$0.isCompleted
            }
            return $0.dueAt < $1.dueAt
        }
        NotificationManager.shared.syncNotifications(for: tasks)
    }
    
    // MARK: - Local Offline Persistence
    private func saveToLocalCache() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    private func loadPendingChanges() {
        guard let data = UserDefaults.standard.data(forKey: pendingChangesKey),
              let changes = try? JSONDecoder().decode(PendingChanges.self, from: data) else { return }
        pendingUpserts = Dictionary(changes.upserts.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        pendingDeletes = Set(changes.deletions)
    }

    private func persistPendingChanges() {
        let changes = PendingChanges(upserts: Array(pendingUpserts.values), deletions: Array(pendingDeletes))
        if let encoded = try? JSONEncoder().encode(changes) {
            UserDefaults.standard.set(encoded, forKey: pendingChangesKey)
        }
    }

    private func markForUpsert(_ task: TaskItem) {
        pendingUpserts[task.id] = task
        pendingDeletes.remove(task.id)
        persistPendingChanges()
    }

    private func markForDeletion(_ id: UUID) {
        pendingUpserts.removeValue(forKey: id)
        pendingDeletes.insert(id)
        persistPendingChanges()
    }

    private func loadFromLocalCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([TaskItem].self, from: data) {
            self.tasks = decoded
            for id in pendingDeletes {
                self.tasks.removeAll { $0.id == id }
            }
            for task in pendingUpserts.values {
                if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[index] = task
                } else {
                    self.tasks.append(task)
                }
            }
            sortTasks()
        } else {
            // Seed sample tasks on first launch
            let now = Date()
            self.tasks = [
                TaskItem(id: UUID(), title: "Review menu bar vibrancy & deadline alerts", dueAt: now.addingTimeInterval(3600 * 2), isCompleted: false, updatedAt: now),
                TaskItem(id: UUID(), title: "Sync iPhone task state to MacBook", dueAt: now.addingTimeInterval(3600 * 5), isCompleted: false, updatedAt: now),
                TaskItem(id: UUID(), title: "Configure Supabase cloud synchronization", dueAt: now.addingTimeInterval(3600 * 24), isCompleted: false, updatedAt: now)
            ]
            sortTasks()
        }
    }
    
    // MARK: - Supabase REST Sync
    func fetchRemoteTasks() async {
        guard hasCloudConfig, !isFetchingRemote,
              let url = URL(string: "\(supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/rest/v1/tasks?select=*&order=due_at.asc") else { return }

        isFetchingRemote = true
        isSyncing = true
        let revisionAtStart = localMutationRevision
        defer {
            isFetchingRemote = false
            isSyncing = false
        }

        var req = URLRequest(url: url)
        req.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastSyncError = "Invalid response while fetching tasks"
                return
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                lastSyncError = "Task fetch failed (HTTP \(httpResponse.statusCode))"
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let string = try container.decode(String.self)
                let fractional = ISO8601DateFormatter()
                fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = fractional.date(from: string) { return date }
                let standard = ISO8601DateFormatter()
                standard.formatOptions = [.withInternetDateTime]
                if let date = standard.date(from: string) { return date }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 task date: \(string)")
            }
            let remoteTasks = try decoder.decode([TaskItem].self, from: data)

            // Never apply a snapshot that was fetched while the user was changing tasks.
            guard revisionAtStart == localMutationRevision else { return }

            let localByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
            let remoteIDs = Set(remoteTasks.map(\.id))
            var mergedByID: [UUID: TaskItem] = [:]

            // Merge per task, not by replacing the whole local list. A stale cloud value
            // must not undo a newer local completion state.
            for remote in remoteTasks {
                if pendingDeletes.contains(remote.id) { continue }

                if let pending = pendingUpserts[remote.id] {
                    if pending.updatedAt >= remote.updatedAt {
                        mergedByID[remote.id] = pending
                    } else {
                        // Another device has a genuinely newer version.
                        pendingUpserts.removeValue(forKey: remote.id)
                        mergedByID[remote.id] = remote
                    }
                    continue
                }

                if let local = localByID[remote.id], local.updatedAt > remote.updatedAt {
                    // Recover edits made by older app builds and queue them for repair.
                    mergedByID[local.id] = local
                    pendingUpserts[local.id] = local
                } else {
                    mergedByID[remote.id] = remote
                }
            }

            // Keep local additions that are waiting to reach Supabase.
            for (id, pending) in pendingUpserts where !remoteIDs.contains(id) && !pendingDeletes.contains(id) {
                mergedByID[id] = pending
            }

            let mergedTasks = Array(mergedByID.values)
            if mergedTasks != tasks {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    tasks = mergedTasks
                    sortTasks()
                }
                saveToLocalCache()
            } else {
                sortTasks()
            }
            persistPendingChanges()
            lastSyncError = nil
            await flushPendingChanges()
        } catch {
            lastSyncError = "Task sync failed: \(error.localizedDescription)"
        }
    }

    private func flushPendingChanges() async {
        guard hasCloudConfig else { return }
        for id in Array(pendingDeletes) {
            await pushDelete(id)
        }
        for task in Array(pendingUpserts.values) {
            await pushUpsert(task)
        }
    }

    private func pushUpsert(_ task: TaskItem) async {
        guard hasCloudConfig, !inFlightUpserts.contains(task.id),
              let baseURL = URL(string: "\(supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/rest/v1/tasks?on_conflict=id") else { return }

        inFlightUpserts.insert(task.id)
        defer {
            inFlightUpserts.remove(task.id)
            if let newest = pendingUpserts[task.id], newest.updatedAt != task.updatedAt {
                Task { await self.pushUpsert(newest) }
            }
        }

        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        encoder.dateEncodingStrategy = .custom { date, enc in
            var container = enc.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }

        do {
            req.httpBody = try encoder.encode(task)
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastSyncError = "Invalid response while saving task"
                return
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                lastSyncError = "Task save failed (HTTP \(httpResponse.statusCode))"
                return
            }

            if pendingUpserts[task.id]?.updatedAt == task.updatedAt {
                pendingUpserts.removeValue(forKey: task.id)
                persistPendingChanges()
            }
            if pendingUpserts.isEmpty && pendingDeletes.isEmpty {
                lastSyncError = nil
            }
        } catch {
            lastSyncError = "Task save failed: \(error.localizedDescription)"
        }
    }

    private func pushDelete(_ id: UUID) async {
        guard hasCloudConfig, !inFlightDeletes.contains(id),
              let url = URL(string: "\(supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/rest/v1/tasks?id=eq.\(id.uuidString)") else { return }

        inFlightDeletes.insert(id)
        defer { inFlightDeletes.remove(id) }

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else {
                lastSyncError = "Invalid response while deleting task"
                return
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                lastSyncError = "Task deletion failed (HTTP \(httpResponse.statusCode))"
                return
            }
            pendingDeletes.remove(id)
            persistPendingChanges()
            if pendingUpserts.isEmpty && pendingDeletes.isEmpty {
                lastSyncError = nil
            }
        } catch {
            lastSyncError = "Task deletion failed: \(error.localizedDescription)"
        }
    }
    
    private func triggerHaptic(isSuccess: Bool) {
        #if os(iOS)
        if isSuccess {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}
