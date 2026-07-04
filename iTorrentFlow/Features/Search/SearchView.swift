import SwiftUI

// MARK: - Search View
public struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool
    @State private var selectedResult: TorrentSearchResult? = nil

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Header
                    searchHeader
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.top, Theme.spacing8)
                        .padding(.bottom, Theme.spacing12)

                    // Category Chips
                    categoryChips
                        .padding(.bottom, Theme.spacing12)

                    // Content
                    Group {
                        if viewModel.isSearching {
                            loadingView
                        } else if viewModel.results.isEmpty && !viewModel.lastQuery.isEmpty {
                            noResultsView
                        } else if !viewModel.results.isEmpty {
                            resultsList
                        } else {
                            searchPrompt
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(item: $selectedResult) { result in
                SearchResultDetailView(result: result)
            }
        }
    }

    // MARK: - Search Header
    private var searchHeader: some View {
        HStack(spacing: Theme.spacing12) {
            HStack(spacing: Theme.spacing8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(isSearchFocused ? Theme.accent : Theme.textTertiary)
                    .animation(Theme.smooth, value: isSearchFocused)

                TextField("Search torrents...", text: $viewModel.query)
                    .foregroundStyle(Theme.textPrimary)
                    .tint(Theme.accent)
                    .focused($isSearchFocused)
                    .onSubmit { viewModel.search() }
                    .submitLabel(.search)

                if !viewModel.query.isEmpty {
                    Button { viewModel.query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(Theme.spacing12)
            .glassMorphism(cornerRadius: Theme.radiusMedium)

            if !viewModel.query.isEmpty {
                Button("Search") { viewModel.search() }
                    .font(Theme.headlineFont(size: 14))
                    .foregroundStyle(Theme.accent)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(Theme.snappy, value: viewModel.query.isEmpty)
    }

    // MARK: - Category Chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing8) {
                ForEach(SearchCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        label: cat.rawValue,
                        isSelected: viewModel.selectedCategory == cat
                    ) {
                        withAnimation(Theme.snappy) {
                            viewModel.selectedCategory = cat
                            if !viewModel.lastQuery.isEmpty { viewModel.search() }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.spacing16)
        }
    }

    // MARK: - Results List
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing8) {
                ForEach(viewModel.results) { result in
                    SearchResultRowView(result: result) {
                        selectedResult = result
                    }
                }

                // Load more
                if viewModel.hasMorePages {
                    Button { viewModel.loadMore() } label: {
                        HStack {
                            if viewModel.isLoadingMore {
                                ProgressView().tint(Theme.accent)
                            }
                            Text("Load More")
                                .font(Theme.headlineFont(size: 14))
                                .foregroundStyle(Theme.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(Theme.spacing12)
                        .glassMorphism(cornerRadius: Theme.radiusMedium)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Theme.spacing16)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: Theme.spacing20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(Theme.accent)
            Text("Searching...")
                .font(Theme.bodyFont())
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }

    // MARK: - No Results
    private var noResultsView: some View {
        VStack(spacing: Theme.spacing16) {
            Spacer()
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textTertiary)
            Text("No results for \"\(viewModel.lastQuery)\"")
                .font(Theme.headlineFont())
                .foregroundStyle(Theme.textPrimary)
            Text("Try different keywords or check your connection.")
                .font(Theme.bodyFont())
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Theme.spacing24)
    }

    // MARK: - Search Prompt
    private var searchPrompt: some View {
        VStack(spacing: Theme.spacing20) {
            Spacer()
            VStack(spacing: Theme.spacing16) {
                Image(systemName: "globe")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.accent, Theme.accentSecondary],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Text("Search Torrents")
                    .font(Theme.titleFont(size: 22))
                    .foregroundStyle(Theme.textPrimary)
                Text("Search across ThePirateBay and more.\nSearches millions of torrents.")
                    .font(Theme.bodyFont())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Trending suggestions
            VStack(alignment: .leading, spacing: Theme.spacing8) {
                Text("Popular searches")
                    .font(Theme.captionFont())
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, Theme.spacing4)

                FlowLayout(spacing: 8) {
                    ForEach(["Latest Movies", "Ubuntu ISO", "Popular TV Shows", "4K Documentary"], id: \.self) { suggestion in
                        Button {
                            viewModel.query = suggestion
                            viewModel.search()
                        } label: {
                            Text(suggestion)
                                .font(Theme.captionFont(size: 13))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, Theme.spacing12)
                                .padding(.vertical, Theme.spacing8)
                                .background(Theme.accent.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.accent.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(Theme.spacing16)
            .glassMorphism(cornerRadius: Theme.radiusLarge)
            .padding(.horizontal, Theme.spacing16)

            Spacer()
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.height }.max() ?? 0 }.reduce(0, +) + spacing * CGFloat(rows.count - 1)
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let maxH = row.map { $0.height }.max() ?? 0
            for item in row {
                item.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
                x += item.width + spacing
            }
            y += maxH + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[SubviewSize]] {
        var rows: [[SubviewSize]] = [[]]
        var x: CGFloat = 0
        let maxW = proposal.width ?? 320
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxW && !rows.last!.isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(SubviewSize(subview: subview, width: size.width, height: size.height))
            x += size.width + spacing
        }
        return rows
    }

    struct SubviewSize {
        let subview: LayoutSubview
        let width: CGFloat
        let height: CGFloat
        func place(at point: CGPoint, anchor: UnitPoint, proposal: ProposedViewSize) {
            subview.place(at: point, anchor: anchor, proposal: proposal)
        }
    }
}

// MARK: - Search ViewModel
@MainActor
public final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [TorrentSearchResult] = []
    @Published var selectedCategory: SearchCategory = .all
    @Published var isSearching: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var hasMorePages: Bool = false
    @Published var lastQuery: String = ""
    private var currentPage: Int = 1

    func search() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        lastQuery = query
        currentPage = 1
        isSearching = true
        results = []

        Task {
            do {
                let res = try await TorrentSearchService.shared.search(
                    query: query,
                    category: selectedCategory,
                    page: 1
                )
                results = res
                hasMorePages = res.count >= 30
            } catch {
                print("Search error: \(error)")
            }
            isSearching = false
        }
    }

    func loadMore() {
        currentPage += 1
        isLoadingMore = true
        Task {
            do {
                let more = try await TorrentSearchService.shared.search(
                    query: lastQuery,
                    category: selectedCategory,
                    page: currentPage
                )
                results.append(contentsOf: more)
                hasMorePages = more.count >= 30
            } catch {}
            isLoadingMore = false
        }
    }
}
