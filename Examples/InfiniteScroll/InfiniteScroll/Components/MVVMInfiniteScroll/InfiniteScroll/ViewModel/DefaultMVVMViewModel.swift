//
//  DefaultMVVMViewModel.swift
//  InfiniteScroll
//
//  Created by Artur Gevorkyan on 23.05.22.
//

import Combine
import Foundation

final class DefaultMVVMViewModel: MVVMViewModel {
    lazy var contentStatePublisher: AnyPublisher<LCEPagedState<[InfiniteScrollItemDisplayData], InfiniteScrollViewError>, Never>  = {
        contentStatePublisherStorage.eraseToAnyPublisher() //type erasure
    }()

    private(set) var environment: InfiniteScrollEnvironment

    // MARK: Private properties
    private var cancellable = Set<AnyCancellable>()
    private let contentStatePublisherStorage = PassthroughSubject<LCEPagedState<[InfiniteScrollItemDisplayData], InfiniteScrollViewError>, Never>() // could be a "box"

    private var lastLoadedPage: Int = -1
    private var lastContentState: LCEPagedState<[InfiniteScrollItemDisplayData], InfiniteScrollViewError> {
        didSet {
            contentStatePublisherStorage.send(lastContentState) // could be a "box" (or CurrentValueSubject) but...
        }
    }

    init(environment: InfiniteScrollEnvironment) {
        self.environment = environment
        lastContentState = .content(data: [], isListEnded: false)
    }

    deinit {
        cancellable.forEach({
            $0.cancel()
        })
    }


    func loadInitialContent() {
        lastContentState = .content(data: [], isListEnded: false)
    }

    func reloadContent() {
        //can be dispatched on main queue to make avoid concurrent access to 'lastContentState'
        if case .loading = lastContentState {
            return //can be replaced with cancellation
        }

        let previousData = lastContentState.data

        lastContentState = .loading(previousData: previousData, state: LCEPagedLoadingState.refresh)
        loadPage(
            0, // can be optimized
            receiveValueHandler: { [weak self] displayData in
                self?.lastLoadedPage = 0 // can be optimized
                let isListEnded = displayData.count < (self?.environment.pageLentgth ?? 0)
                self?.lastContentState = .content(data: displayData, isListEnded: isListEnded) // can be optimized
            }, failureHandler: { [weak self] error in
                self?.lastContentState = .error(previousData: previousData, isListEnded: false, error: error) // can be optimized
            }
        )
    }

    func loadNextPage() {
        //can be dispatched on main queue to make avoid concurrent access to 'lastContentState' and 'lastLoadedPage'
        if case .loading = lastContentState {
            return //can be replaced with cancellation
        }

        let previousData = lastContentState.data
        let pageToLoad = lastLoadedPage + 1

        lastContentState = .loading(previousData: previousData, state: LCEPagedLoadingState.nextPage)
        loadPage(
            pageToLoad,
            receiveValueHandler: { [weak self] displayData in
                self?.lastLoadedPage = pageToLoad
                let isListEnded = displayData.count < (self?.environment.pageLentgth ?? 0)
                self?.lastContentState = .content(data: previousData + displayData, isListEnded: isListEnded)
            },
            failureHandler: { [weak self] error in
                self?.lastContentState = .error(previousData: previousData, isListEnded: false, error: error)
            }
        )
    }

    func openDetails(for itemIndex: Int) { //index is bad. ID is better
        let items = lastContentState.data
        guard itemIndex < items.count else {
            return
        }
        
        //Ideally, it should talk to coordinator
        let item = lastContentState.data[itemIndex]
        environment.moduleOutput?.infiniteScrollModuleWantsToOpenDetails(with: item.id)
    }

    private func loadPage(
        _ pageToLoad: Int,
        receiveValueHandler: @escaping ([InfiniteScrollItemDisplayData]) -> Void,
        failureHandler: ((InfiniteScrollViewError) -> Void)?
    ) {
        environment.infiniteScrollRepository.getInfiniteScrolls(
            with: pageToLoad,
            pageLentgth: environment.pageLentgth
        ).subscribe(on: environment.backgroundQueue)
            .map { result -> [InfiniteScrollItemDisplayData] in
                result.map { model in
                    InfiniteScrollItemDisplayData(
                        title: model.title,
                        subtitle: model.subtitle,
                        id: model.id,
                        details: model.details
                    )
                }
            }
            .mapError { _ in
                InfiniteScrollViewError.api
            }
            .receive(on: environment.mainQueue)
            .sink(
                receiveCompletion: { completionResult in
                    switch completionResult {
                    case .failure(let error):
                        failureHandler?(error)
                    case .finished:
                        break
                    }
                },
                receiveValue: receiveValueHandler
            ).store(in: &cancellable)
    }

}
