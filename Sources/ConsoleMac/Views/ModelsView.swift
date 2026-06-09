import SwiftUI

struct ModelsView: View {
    @ObservedObject var store: ConsoleStore
    @State private var searchText = ""
    @State private var filter: ModelFilter = .all

    private var filteredModels: [LocalModel] {
        store.models.filter { model in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .installed:
                matchesFilter = model.status == .installed
            case .coding:
                matchesFilter = model.strengths.contains("Coding") || model.strengths.contains("Debugging")
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesFilter }

            return matchesFilter && [
                model.name,
                model.family,
                model.summary,
                model.strengths.joined(separator: " ")
            ]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modelsHeader

            Divider()

            ScrollView {
                if filteredModels.isEmpty {
                    ModelsEmptyState(searchText: searchText, filterTitle: filter.title)
                        .frame(maxWidth: .infinity, minHeight: 360)
                        .padding(.top, 48)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(filteredModels) { model in
                            ModelCard(
                                model: model,
                                isSelected: store.selectedModel?.id == model.id,
                                startDownload: { store.startModelDownload(model.id) },
                                select: { store.selectModel(model.id) },
                                remove: { store.removeModel(model.id) }
                            )
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 880, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .background(Theme.windowBackground)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search models")
    }

    private var modelsHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Models")
                    .font(Typography.interface(22, .semibold))
                    .foregroundStyle(.primary)

                Text(store.selectedModel?.name ?? "No local model selected")
                    .font(Typography.interface(12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Filter", selection: $filter) {
                ForEach(ModelFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
        .background(.bar)
    }
}

private struct ModelsEmptyState: View {
    let searchText: String
    let filterTitle: String

    var body: some View {
        VStack(spacing: 10) {
            ConsoleSymbolView(asset: .models, size: 34)
                .foregroundStyle(.secondary)

            Text(title)
                .font(Typography.interface(18, .semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(Typography.interface(13))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
    }

    private var title: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "No \(filterTitle.lowercased()) models"
            : "No matching models"
    }

    private var subtitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Try a different filter."
            : "Try a shorter name, provider, or capability."
    }
}

private enum ModelFilter: String, CaseIterable, Identifiable {
    case all
    case installed
    case coding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .installed:
            return "Installed"
        case .coding:
            return "Coding"
        }
    }
}

private struct ModelCard: View {
    let model: LocalModel
    let isSelected: Bool
    let startDownload: () -> Void
    let select: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ProviderLogoView(provider: model.provider, width: 44, height: 44)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(Typography.interface(16, .semibold))
                            .foregroundStyle(.primary)

                        if isSelected {
                            Label("Default", systemImage: "checkmark.circle.fill")
                                .font(Typography.interface(11, .semibold))
                                .foregroundStyle(.secondary)
                                .labelStyle(.titleAndIcon)
                        }
                    }

                    Text(model.subtitle)
                        .font(Typography.interface(12, .medium))
                        .foregroundStyle(.secondary)

                    Text(model.summary)
                        .font(Typography.interface(13))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                actionView
            }

            HStack(spacing: 8) {
                ForEach(model.strengths, id: \.self) { strength in
                    Text(strength)
                        .font(Typography.interface(11, .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.subtleFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                Spacer()

                Text("\(model.diskSize) · \(model.recommendedMemory)")
                    .font(Typography.interface(11))
                    .foregroundStyle(.secondary)
            }

            if model.status == .downloading {
                ProgressView(value: model.downloadProgress)
                    .progressViewStyle(.linear)
            }

            if let downloadError = model.downloadError, downloadError.isEmpty == false {
                Text(downloadError)
                    .font(Typography.interface(11))
                    .foregroundStyle(.red.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.primary.opacity(0.5) : Theme.separator.opacity(0.7), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var actionView: some View {
        switch model.status {
        case .notInstalled:
            Button(action: startDownload) {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
        case .downloading:
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(Int(model.downloadProgress * 100))%")
                    .font(Typography.interface(12, .semibold))
                    .foregroundStyle(.secondary)
                ProgressView()
                    .controlSize(.small)
            }
            .frame(width: 88, alignment: .trailing)
        case .installed:
            HStack(spacing: 8) {
                if isSelected {
                    Button("Selected", action: select)
                        .buttonStyle(.bordered)
                        .disabled(true)
                } else {
                    Button("Use", action: select)
                        .buttonStyle(.borderedProminent)
                }

                Button(action: remove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove")
            }
        }
    }
}
