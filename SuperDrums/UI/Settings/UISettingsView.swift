import SwiftUI

/// Settings view for saving/loading projects and drum kits.
struct UISettingsView: View {
    @Bindable var store: AppStore

    @State private var showNewProjectAlert = false
    @State private var showSaveAsAlert = false
    @State private var showSaveKitAlert = false
    @State private var newName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: UISpacing.lg) {
                // Project Section
                projectSection

                Divider()
                    .background(UIColors.border)

                // Drum Kits Section
                kitsSection
            }
            .padding(UISpacing.md)
        }
        .background(UIColors.background)
        .onAppear {
            Task {
                await store.refreshSavedProjects()
                await store.refreshSavedKits()
            }
        }
        .alert("New Project", isPresented: $showNewProjectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Create", role: .destructive) {
                store.newProject()
            }
        } message: {
            Text("Create a new project? Unsaved changes will be lost.")
        }
        .alert("Save Project As", isPresented: $showSaveAsAlert) {
            TextField("Project Name", text: $newName)
            Button("Cancel", role: .cancel) { newName = "" }
            Button("Save") {
                Task {
                    await store.saveProjectAs(name: newName)
                    newName = ""
                }
            }
        }
        .alert("Save Drum Kit", isPresented: $showSaveKitAlert) {
            TextField("Kit Name", text: $newName)
            Button("Cancel", role: .cancel) { newName = "" }
            Button("Save") {
                Task {
                    await store.saveCurrentKit(name: newName)
                    newName = ""
                }
            }
        }
    }

    // MARK: - Project Section

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("PROJECT")

            // Current project info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.project.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(UIColors.textPrimary)

                    Text("\(store.project.patterns.count) patterns")
                        .font(.system(size: 12))
                        .foregroundStyle(UIColors.textSecondary)
                }

                Spacer()

                if store.isSaving {
                    ProgressView()
                        .tint(UIColors.accentCyan)
                }
            }
            .padding(UISpacing.md)
            .background(UIColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Project actions
            HStack(spacing: UISpacing.sm) {
                Button {
                    showNewProjectAlert = true
                } label: {
                    Label("New", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    Task { await store.saveCurrentProject() }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(accentColor: UIColors.accentGreen))

                Button {
                    newName = store.project.name
                    showSaveAsAlert = true
                } label: {
                    Label("Save As", systemImage: "square.and.arrow.down.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            // Error display
            if let error = store.persistenceError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(UISpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Saved projects list
            if !store.savedProjects.isEmpty {
                VStack(alignment: .leading, spacing: UISpacing.sm) {
                    Text("SAVED PROJECTS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(UIColors.textSecondary)

                    ForEach(store.savedProjects) { metadata in
                        ProjectRow(
                            metadata: metadata,
                            onLoad: {
                                Task { await store.loadProject(metadata: metadata) }
                            },
                            onDelete: {
                                Task { await store.deleteProject(metadata: metadata) }
                            }
                        )
                    }
                }
            } else {
                Text("No saved projects")
                    .font(.system(size: 12))
                    .foregroundStyle(UIColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(UISpacing.lg)
            }
        }
    }

    // MARK: - Kits Section

    private var kitsSection: some View {
        VStack(alignment: .leading, spacing: UISpacing.md) {
            sectionHeader("DRUM KITS")

            Text("Save and load reusable sound presets independent of patterns.")
                .font(.system(size: 11))
                .foregroundStyle(UIColors.textSecondary)

            Button {
                newName = "\(store.project.name) Kit"
                showSaveKitAlert = true
            } label: {
                Label("Save Current Kit", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(accentColor: UIColors.accentMagenta))

            // Saved kits list
            if !store.savedKits.isEmpty {
                VStack(alignment: .leading, spacing: UISpacing.sm) {
                    Text("SAVED KITS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(UIColors.textSecondary)

                    ForEach(store.savedKits) { metadata in
                        KitRow(
                            metadata: metadata,
                            onLoad: {
                                Task { await store.loadKit(metadata: metadata) }
                            },
                            onDelete: {
                                Task { await store.deleteKit(metadata: metadata) }
                            }
                        )
                    }
                }
            } else {
                Text("No saved drum kits")
                    .font(.system(size: 12))
                    .foregroundStyle(UIColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(UISpacing.lg)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(UIColors.textSecondary)
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let metadata: ProjectMetadata
    let onLoad: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: metadata.modifiedAt)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UIColors.textPrimary)

                HStack(spacing: UISpacing.sm) {
                    Text("\(metadata.patternCount) patterns")
                    Text("•")
                    Text(formattedDate)
                }
                .font(.system(size: 10))
                .foregroundStyle(UIColors.textSecondary)
            }

            Spacer()

            Button {
                onLoad()
            } label: {
                Text("Load")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIColors.accentCyan)
                    .padding(.horizontal, UISpacing.sm)
                    .padding(.vertical, UISpacing.xs)
                    .background(UIColors.accentCyan.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(UIColors.muted)
                    .frame(width: 28, height: 28)
                    .background(UIColors.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(UISpacing.sm)
        .background(UIColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .confirmationDialog(
            "Delete \"\(metadata.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Kit Row

struct KitRow: View {
    let metadata: KitMetadata
    let onLoad: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: metadata.modifiedAt)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UIColors.textPrimary)

                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundStyle(UIColors.textSecondary)
            }

            Spacer()

            Button {
                onLoad()
            } label: {
                Text("Load")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UIColors.accentMagenta)
                    .padding(.horizontal, UISpacing.sm)
                    .padding(.vertical, UISpacing.xs)
                    .background(UIColors.accentMagenta.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button {
                showDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(UIColors.muted)
                    .frame(width: 28, height: 28)
                    .background(UIColors.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(UISpacing.sm)
        .background(UIColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .confirmationDialog(
            "Delete \"\(metadata.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) { }
        }
    }
}

// MARK: - Preview

#Preview {
    UISettingsView(store: AppStore(project: .demo()))
}
