//
//  InfiniteScrollTests.swift
//  InfiniteScrollTests
//
//  Created by Dmitrii Coolerov on 05.05.2022.
//

import Combine
import Swiftea
import Swinject

import XCTest

@testable import InfiniteScroll

class TCAInfiniteScrollTests: XCTestCase {
    var infiniteScrollRepository: InfiniteScrollRepositoryProtocolMock!

    var viewStore: ViewStore<TCAInfiniteScrollViewState, TCAInfiniteScrollViewEvent>!
    var viewController: UIViewController!

    var cancellable = Set<AnyCancellable>()

    var eventPublusher = PassthroughSubject<TCAInfiniteScrollEvent, Never>()

    override func setUpWithError() throws {
        let container = Container()
        let resolver: Resolver = container

        infiniteScrollRepository = InfiniteScrollRepositoryProtocolMock()
        container.register(InfiniteScrollRepositoryProtocol.self) { _ in
            self.infiniteScrollRepository
        }

        let toastNotificationManager = ToastNotificationManagerProtocolMock()
        toastNotificationManager.showNotificationWithClosure = { _ in
            // unused
        }
        container.register(ToastNotificationManagerProtocol.self) { _ in
            toastNotificationManager
        }

        let feature = TCAInfiniteScrollFeature()

        let testReducer = Reducer<TCAInfiniteScrollState, TCAInfiniteScrollEvent, TCAInfiniteScrollCommand> { state, event in
            self.eventPublusher.send(event)
            return feature.getReducer().dispatch(state: state, event: event)
        }

        let store = Store<TCAInfiniteScrollState, TCAInfiniteScrollEvent, TCAInfiniteScrollCommand, InfiniteScrollEnvironment>(
            state: TCAInfiniteScrollState(),
            reducer: testReducer,
            commandHandler: feature.getCommandHandler(
                environment: InfiniteScrollEnvironment(
                    infiniteScrollRepository: resolver.resolve(InfiniteScrollRepositoryProtocol.self)!,
                    moduleOutput: nil
                )
            )
        )

        viewStore = ViewStore<TCAInfiniteScrollViewState, TCAInfiniteScrollViewEvent>(
            store: store,
            eventMapper: feature.getEventMapper(),
            stateMapper: feature.getStateMapper()
        )

        viewController = TCAInfiniteScrollViewController(
            viewStore: viewStore,
            toastNotificationManager: resolver.resolve(ToastNotificationManagerProtocol.self)!
        )
    }

    override func tearDownWithError() throws {
        // unused
    }

    func testNextPage() throws {
        // Arrange
        let finalExpectation = expectation(description: "final")

        eventPublusher.sink { event in
            if event == .updateInitialData(
                data: (0...14).map { index in
                    InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                },
                isListEnded: false
            ) {
                self.infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
                    let data = (15...15).map { index in
                        InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                    }
                    promise(.success(data))
                }).eraseToAnyPublisher()
                self.viewStore.dispatch(.viewWillScrollToLastItem)
            }
        }.store(in: &cancellable)

        var states: [TCAInfiniteScrollViewState] = []
        viewStore.statePublisher.sink { state in
            states.append(state)

            let finalState = TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...15).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            )
            if state == finalState {
                finalExpectation.fulfill()
            }
        }.store(in: &cancellable)

        // Act
        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            let data = (0...14).map { index in
                InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
            }
            promise(.success(data))
        }).eraseToAnyPublisher()
        viewStore.dispatch(.viewDidLoad)

        // Assert
        wait(for: [finalExpectation], timeout: 1)

        let referenseStates: [TCAInfiniteScrollViewState] = [
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: [],
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: [],
                    state: .refresh
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    state: .nextPage
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...15).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            ),
        ]
        XCTAssertEqual(states, referenseStates)
    }

    func testRefresh() throws {
        // Arrange
        let finalExpectation = expectation(description: "final")

        eventPublusher.sink { event in
            if event == .updateInitialData(
                data: (0...14).map { index in
                    InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                },
                isListEnded: false
            ) {
                self.infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
                    let data = (15...20).map { index in
                        InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                    }
                    promise(.success(data))
                }).eraseToAnyPublisher()
                self.viewStore.dispatch(.viewDidPullToRefresh)
            }
        }.store(in: &cancellable)

        var states: [TCAInfiniteScrollViewState] = []
        viewStore.statePublisher.sink { state in
            states.append(state)

            let finalState = TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (15...20).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            )
            if state == finalState {
                finalExpectation.fulfill()
            }
        }.store(in: &cancellable)

        // Act
        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            let data = (0...14).map { index in
                InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
            }
            promise(.success(data))
        }).eraseToAnyPublisher()
        viewStore.dispatch(.viewDidLoad)

        // Assert
        wait(for: [finalExpectation], timeout: 1)

        let referenseStates: [TCAInfiniteScrollViewState] = [
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: [],
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: [],
                    state: .refresh
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    state: .refresh
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (15...20).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            ),
        ]
        XCTAssertEqual(states, referenseStates)
    }

    func testNextPageError() throws {
        // Arrange
        let finalExpectation = expectation(description: "final")

        eventPublusher.sink { event in
            if event == .updateInitialData(
                data: (0...14).map { index in
                    InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                },
                isListEnded: false
            ) {
                self.infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
                    promise(.failure(URLError(.notConnectedToInternet)))
                }).eraseToAnyPublisher()
                self.viewStore.dispatch(.viewWillScrollToLastItem)
            }
        }.store(in: &cancellable)

        var states: [TCAInfiniteScrollViewState] = []
        viewStore.statePublisher.sink { state in
            states.append(state)

            let finalState = TCAInfiniteScrollViewState(
                contentState: .error(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false,
                    error: .api
                )
            )
            if state == finalState {
                finalExpectation.fulfill()
            }
        }.store(in: &cancellable)

        // Act
        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            let data = (0...14).map { index in
                InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
            }
            promise(.success(data))
        }).eraseToAnyPublisher()
        viewStore.dispatch(.viewDidLoad)

        // Assert
        wait(for: [finalExpectation], timeout: 1)

        let referenseStates: [TCAInfiniteScrollViewState] = [
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: [],
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: [],
                    state: .refresh
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    state: .nextPage
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .error(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false,
                    error: .api
                )
            ),
        ]
        XCTAssertEqual(states, referenseStates)
    }

    func testRefreshError() throws {
        // Arrange
        let finalExpectation = expectation(description: "final")

        eventPublusher.sink { event in
            if event == .updateInitialData(
                data: (0...14).map { index in
                    InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                },
                isListEnded: false
            ) {
                self.infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
                    promise(.failure(URLError(.notConnectedToInternet)))
                }).eraseToAnyPublisher()
                self.viewStore.dispatch(.viewDidPullToRefresh)
            }
        }.store(in: &cancellable)

        var states: [TCAInfiniteScrollViewState] = []
        viewStore.statePublisher.sink { state in
            states.append(state)

            let finalState = TCAInfiniteScrollViewState(
                contentState: .error(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false,
                    error: .api
                )
            )
            if state == finalState {
                finalExpectation.fulfill()
            }
        }.store(in: &cancellable)

        // Act
        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            let data = (0...14).map { index in
                InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
            }
            promise(.success(data))
        }).eraseToAnyPublisher()
        viewStore.dispatch(.viewDidLoad)

        // Assert
        wait(for: [finalExpectation], timeout: 1)

        let referenseStates: [TCAInfiniteScrollViewState] = [
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: [],
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: [],
                    state: .refresh
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    state: .refresh
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .error(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false,
                    error: .api
                )
            ),
        ]
        XCTAssertEqual(states, referenseStates)
    }

    func testRetryLoadNextPageOnError() throws {
        // Arrange
        let finalExpectation = expectation(description: "final")

        eventPublusher.sink { event in
            if event == .updateInitialData(
                data: (0...14).map { index in
                    InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                },
                isListEnded: false
            ) {
                self.infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
                    promise(.failure(URLError(.notConnectedToInternet)))
                }).eraseToAnyPublisher()
                self.viewStore.dispatch(.viewWillScrollToLastItem)
            }

            if event == .updateDataWithError(error: .networkError) {
                self.infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
                    let data = (15...20).map { index in
                        InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
                    }
                    promise(.success(data))
                }).eraseToAnyPublisher()
                self.viewStore.dispatch(.viewDidTapRetryNextPageLoading)
            }
        }.store(in: &cancellable)

        var states: [TCAInfiniteScrollViewState] = []
        viewStore.statePublisher.sink { state in
            states.append(state)

            let finalState = TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...20).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            )
            if state == finalState {
                finalExpectation.fulfill()
            }
        }.store(in: &cancellable)

        // Act
        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            let data = (0...14).map { index in
                InfiniteScrollModel(title: "\(index)", subtitle: "", id: "", details: "")
            }
            promise(.success(data))
        }).eraseToAnyPublisher()
        viewStore.dispatch(.viewDidLoad)

        // Assert
        wait(for: [finalExpectation], timeout: 20)

        let referenseStates: [TCAInfiniteScrollViewState] = [
            TCAInfiniteScrollViewState(contentState: .content(data: [], isListEnded: false)),
            TCAInfiniteScrollViewState(contentState: .loading(previousData: [], state: InfiniteScroll.LCEPagedLoadingState.refresh)),
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    state: .nextPage
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .error(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: false,
                    error: .api
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .loading(
                    previousData: (0...14).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    state: .nextPage
                )
            ),
            TCAInfiniteScrollViewState(
                contentState: .content(
                    data: (0...20).map { index in
                        InfiniteScrollItemDisplayData(title: "\(index)", subtitle: "", id: "", details: "")
                    },
                    isListEnded: true
                )
            ),
        ]
        XCTAssertEqual(states, referenseStates)
    }
}
