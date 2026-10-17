import SwiftUI

// MARK: - Clickable Open-Source Credit
struct BuiltBySamWatermark: View {
    var body: some View {
        Link(destination: URL(string: "https://github.com/r-samarth/Krono")!) {
            #if os(macOS)
            HStack(spacing: 3) {
                Text("Built by Sam")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(KronoTheme.inkMuted)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(KronoTheme.inkMuted.opacity(0.6))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.04), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            .contentShape(Rectangle())
            #else
            VStack(spacing: 2) {
                Text("By Sam")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(KronoTheme.inkPrimary)
                    .lineLimit(1)
                    .fixedSize()
                
                Text("Open Source")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(KronoTheme.completed)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(width: 70, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(KronoTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(KronoTheme.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Built by Sam. Open source. View Krono on GitHub")
    }
}

// MARK: - 1. KINETIC CHECKBOX PRIMITIVE
struct SemanticCheckbox: View {
    let isCompleted: Bool
    let urgencyColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isCompleted ? KronoTheme.completed : Color.white.opacity(0.03))
                    .frame(width: 20, height: 20)
                
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isCompleted ? KronoTheme.completed : urgencyColor.opacity(0.65),
                        lineWidth: 1.5
                    )
                    .frame(width: 20, height: 20)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(KronoTheme.canvas)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 2. SEMANTIC TASK ROW
struct TaskRowView: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var signalColor: Color {
        KronoTheme.deadlineColor(for: task.dueAt, isCompleted: task.isCompleted)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            SemanticCheckbox(
                isCompleted: task.isCompleted,
                urgencyColor: signalColor,
                action: onToggle
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(task.isCompleted ? KronoTheme.inkMuted : KronoTheme.inkPrimary)
                    .strikethrough(task.isCompleted, color: KronoTheme.inkMuted)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(signalColor)
                        .frame(width: 6, height: 6)
                    
                    Text(task.relativeDeadlineText)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(signalColor)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KronoTheme.inkMuted)
                    .padding(6)
                    .background(Color.white.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1.0 : 0.4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovered ? KronoTheme.surfaceHover : KronoTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(KronoTheme.border, lineWidth: 1)
        )
        #if os(macOS)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        #endif
    }
}

// MARK: - 3. QUICK DEADLINE PRESET PICKER
enum DeadlinePreset: String, CaseIterable, Identifiable {
    case oneHour = "+1h"
    case threeHours = "+3h"
    case tonight = "Tonight"
    case tomorrow = "Tomorrow"
    
    var id: String { rawValue }
    
    var resolvedDate: Date {
        let now = Date()
        let cal = Calendar.current
        switch self {
        case .oneHour:
            return now.addingTimeInterval(3600)
        case .threeHours:
            return now.addingTimeInterval(3 * 3600)
        case .tonight:
            return cal.date(bySettingHour: 21, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(6 * 3600)
        case .tomorrow:
            let tom = cal.date(byAdding: .day, value: 1, to: now) ?? now
            return cal.date(bySettingHour: 10, minute: 0, second: 0, of: tom) ?? now.addingTimeInterval(24 * 3600)
        }
    }
}

// MARK: - 4. CLOUD SETTINGS SHEET (Optional Supabase Configuration)
struct CloudSettingsView: View {
    @ObservedObject var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var url: String = ""
    @State private var key: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("SUPABASE CLOUD SYNC")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(KronoTheme.accent)
                    Text("Realtime Configuration")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(KronoTheme.inkPrimary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(KronoTheme.inkMuted)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Project URL")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KronoTheme.inkMuted)
                TextField("https://xyzcompany.supabase.co", text: $url)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(KronoTheme.surfaceHover, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(KronoTheme.border, lineWidth: 1))
                    .foregroundStyle(KronoTheme.inkPrimary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Anon Public API Key")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KronoTheme.inkMuted)
                TextField("eyJhbGciOi...", text: $key)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(KronoTheme.surfaceHover, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(KronoTheme.border, lineWidth: 1))
                    .foregroundStyle(KronoTheme.inkPrimary)
            }
            
            HStack {
                Button {
                    store.saveCredentials(url: url, key: key)
                    dismiss()
                } label: {
                    Text("Save & Connect")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(KronoTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                if store.hasCloudConfig {
                    Button("Clear Credentials") {
                        store.saveCredentials(url: "", key: "")
                        url = ""
                        key = ""
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(KronoTheme.critical)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .background(KronoTheme.surface)
        .preferredColorScheme(.dark)
        .onAppear {
            url = store.supabaseURL.contains("YOUR_PROJECT_ID") ? "" : store.supabaseURL
            key = store.supabaseKey.contains("YOUR_SUPABASE_ANON_KEY") ? "" : store.supabaseKey
        }
    }
}

// MARK: - 5. macOS MENU BAR HUD VIEW (380x480 POPOVER)
struct MacMenuBarPopoverView: View {
    @ObservedObject var store: TaskStore
    @State private var newTitle: String = ""
    @State private var selectedPreset: DeadlinePreset = .threeHours
    @State private var showCompleted: Bool = false
    @State private var showSettings: Bool = false
    
    var filteredTasks: [TaskItem] {
        store.tasks.filter { showCompleted ? $0.isCompleted : !$0.isCompleted }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        )

                    Text("KRONO")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(KronoTheme.inkPrimary)

                    Circle()
                        .fill(store.activeCount > 0 ? KronoTheme.accent : KronoTheme.completed)
                        .frame(width: 6, height: 6)
                }
                
                Spacer()
                
                // Segmented Filter Pill
                HStack(spacing: 4) {
                    filterTab(title: "Active (\(store.activeCount))", isSelected: !showCompleted) {
                        showCompleted = false
                    }
                    filterTab(title: "Logbook", isSelected: showCompleted) {
                        showCompleted = true
                    }
                }
                .padding(3)
                .background(KronoTheme.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(KronoTheme.border, lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            // Quick Task Composer
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("Deploy new task...", text: $newTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KronoTheme.inkPrimary)
                        .onSubmit(submitTask)
                    
                    Button(action: submitTask) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(KronoTheme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(KronoTheme.inkMuted)
                    
                    ForEach(DeadlinePreset.allCases) { preset in
                        Button {
                            selectedPreset = preset
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                .foregroundStyle(selectedPreset == preset ? .white : KronoTheme.inkMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(selectedPreset == preset ? KronoTheme.accent.opacity(0.85) : Color.white.opacity(0.04))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .padding(12)
            .background(KronoTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(KronoTheme.border, lineWidth: 1))
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            
            Divider().overlay(KronoTheme.border)
            
            // Task List
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    if filteredTasks.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: showCompleted ? "tray" : "checkmark.seal.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(KronoTheme.completed.opacity(0.8))
                            Text(showCompleted ? "No completed tasks yet" : "Zero pending tasks. Clear skies.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(KronoTheme.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    } else {
                        ForEach(filteredTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggle: { store.toggleTask(task) },
                                onDelete: { store.deleteTask(task) }
                            )
                        }
                    }
                }
                .padding(14)
            }
            
            Divider().overlay(KronoTheme.border)

            // Footer Status Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.hasCloudConfig ? KronoTheme.completed : KronoTheme.warning)
                        .frame(width: 6, height: 6)
                    
                    Text(store.hasCloudConfig ? "Realtime Cloud Sync Active" : "Local Mode (Click to connect)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(KronoTheme.inkMuted)
                }
                .onTapGesture {
                    showSettings = true
                }
                
                Spacer()

                BuiltBySamWatermark()
                
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(KronoTheme.inkMuted)
                }
                .buttonStyle(.plain)
                
                #if os(macOS)
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(KronoTheme.inkMuted)
                .buttonStyle(.plain)
                #endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 375, height: 480)
        .background(KronoTheme.canvas.opacity(0.96))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            CloudSettingsView(store: store)
        }
    }
    
    private func submitTask() {
        store.addTask(title: newTitle, dueAt: selectedPreset.resolvedDate)
        newTitle = ""
    }
    
    private func filterTab(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? KronoTheme.inkPrimary : KronoTheme.inkMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.white.opacity(0.1) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 6. iPHONE COMPANION APPLICATION VIEW
struct iOSCompanionView: View {
    @ObservedObject var store: TaskStore
    @State private var newTitle: String = ""
    @State private var customDate: Date = Date().addingTimeInterval(3600)
    @State private var showDatePicker: Bool = false
    @State private var showSettings: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            KronoTheme.canvas.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                // Top Telemetry Header
                HStack(alignment: .center, spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                        )
                        .shadow(color: KronoTheme.accent.opacity(0.18), radius: 8, y: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("KRONO // MOBILE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(KronoTheme.accent)
                        
                        Text("\(store.activeCount) Active")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(KronoTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        BuiltBySamWatermark()

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(KronoTheme.inkMuted)
                                .frame(width: 36, height: 36)
                                .background(KronoTheme.surface, in: Circle())
                                .overlay(Circle().strokeBorder(KronoTheme.border, lineWidth: 1))
                        }
                        
                        Button {
                            Task { await store.fetchRemoteTasks() }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(KronoTheme.inkPrimary)
                                .frame(width: 36, height: 36)
                                .background(KronoTheme.surface, in: Circle())
                                .overlay(Circle().strokeBorder(KronoTheme.border, lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 18)
                
                // Legend Strip
                HStack(spacing: 16) {
                    legendDot(color: KronoTheme.critical, label: "Overdue")
                    legendDot(color: KronoTheme.warning, label: "Under 3h")
                    legendDot(color: KronoTheme.completed, label: "Completed")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                
                // Scrollable Task Feed
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if store.tasks.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 36))
                                    .foregroundStyle(KronoTheme.inkMuted.opacity(0.6))
                                Text("No tasks in queue")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(KronoTheme.inkMuted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            ForEach(store.tasks) { task in
                                TaskRowView(
                                    task: task,
                                    onToggle: { store.toggleTask(task) },
                                    onDelete: { store.deleteTask(task) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 160)
                }
            }

            // Bottom-Anchored Thumb Dock for Creating Tasks on iPhone
            VStack(spacing: 12) {
                if showDatePicker {
                    DatePicker(
                        "Deadline",
                        selection: $customDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KronoTheme.inkPrimary)
                    .tint(KronoTheme.accent)
                    .padding(.horizontal, 4)
                }
                
                HStack(spacing: 10) {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            showDatePicker.toggle()
                        }
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(showDatePicker ? KronoTheme.accent : KronoTheme.inkMuted)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    TextField("New task with deadline...", text: $newTitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(KronoTheme.inkPrimary)
                        .submitLabel(.done)
                        .onSubmit(createMobileTask)
                    
                    Button(action: createMobileTask) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(KronoTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(KronoTheme.surface)
                    .shadow(color: .black.opacity(0.55), radius: 24, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(KronoTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            CloudSettingsView(store: store)
        }
    }
    
    private func createMobileTask() {
        store.addTask(title: newTitle, dueAt: customDate)
        newTitle = ""
        showDatePicker = false
        customDate = Date().addingTimeInterval(3600)
    }
    
    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(KronoTheme.inkMuted)
        }
    }
}
