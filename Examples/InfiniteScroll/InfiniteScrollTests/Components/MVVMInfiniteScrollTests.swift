//
//  MVVMInfiniteScrollTests.swift
//  InfiniteScrollTests
//
//  Created by Artur Gevorkyan on 26.05.22.
//

import Combine
import Swinject
import XCTest

@testable import InfiniteScroll

class MVVMInfiniteScrollTests: XCTestCase {
    var infiniteScrollRepository: InfiniteScrollRepositoryProtocolMock!

    var viewModel: MVVMViewModel!

    var cancellable = Set<AnyCancellable>()

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

        let environment = InfiniteScrollEnvironment(
            infiniteScrollRepository: resolver.resolve(InfiniteScrollRepositoryProtocol.self)!,
            moduleOutput: nil
        )
        viewModel = DefaultMVVMViewModel(environment: environment)
    }

    override func tearDownWithError() throws {
        cancellable.forEach {
            $0.cancel()
        }
    }

    func testInitialContent() throws {
        let repositoryAccessRejection = expectation(description: "Repository access rejection in \(#function)")
        repositoryAccessRejection.isInverted = true // making it a rejection

        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthClosure = { (_,_) in
            //this shouldn't happen as no request to the repository is required
            let error = NSError(domain: #function, code: 111, userInfo: ["Reason" : "no request to the repository is expected"])
            repositoryAccessRejection.fulfill()

            let publisher = PassthroughSubject<[InfiniteScrollModel], Error>()
            publisher.send(completion: .failure(error))
            return publisher.eraseToAnyPublisher()
        }

        let viewModelStateChangeExpectation = expectation(description: "View model state change expectation in \(#function)")

        viewModel.contentStatePublisher.sink { state in
            if case .content(data: let data, isListEnded: _) = state {
                XCTAssert(data.isEmpty)
            } else {
                XCTFail("Invalid state in \(#function)")
            }
            viewModelStateChangeExpectation.fulfill()
        }.store(in: &cancellable)

        viewModel.loadInitialContent()


        wait(for: [repositoryAccessRejection, viewModelStateChangeExpectation], timeout: 1.0)
    }

    func testNextPage() throws {

        let simulatedData = (0...14).map { index in
            InfiniteScrollModel(title: "\(index) -- \(#function)", subtitle: "", id: "", details: "")
        }

        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthReturnValue = Future<[InfiniteScrollModel], Error>({ promise in
            promise(.success(simulatedData))
        }).eraseToAnyPublisher()

        let viewModelLoadingStateExpectation = expectation(description: "Loading in \(#function)")
        let viewModelContentStateExpectation = expectation(description: "Content in \(#function)")

        viewModel.contentStatePublisher.sink { state in
            switch state {
            case .content(data: let data, isListEnded: _):
                XCTAssert(data.map({ $0.title }) == simulatedData.map({ $0.title }))
                viewModelContentStateExpectation.fulfill()
            case .loading(previousData: let previousData, state: let loadingState):
                XCTAssert(previousData.isEmpty)
                XCTAssert(loadingState == .nextPage)
                viewModelLoadingStateExpectation.fulfill()
            default:
                XCTFail("Invalid state in \(#function)")
            }

        }.store(in: &cancellable)

        viewModel.loadNextPage()

        wait(for: [viewModelLoadingStateExpectation, viewModelContentStateExpectation],
               timeout: 1.0,
               enforceOrder: true)
    }


    func testRefresh() throws {

        let preRefreshData = (0...29).map { index in
            InfiniteScrollModel(title: "\(index) -- \(#function)", subtitle: "", id: "", details: "")
        } // as if 2 pages had been loaded

        let refreshResultData = (0...14).map { index in
            InfiniteScrollModel(title: "\(index) -- \(#function)", subtitle: "", id: "", details: "")
        }

        var isPreconditionLoading = true

        let preconditionLoadingStateExpectation = expectation(description: "Precondition loading in \(#function)")
        let preconditionContentStateExpectation = expectation(description: "Precondition content in \(#function)")

        let loadingStateExpectation = expectation(description: "Loading in \(#function)")
        let contentStateExpectation = expectation(description: "Content in \(#function)")

        viewModel.loadInitialContent()

        infiniteScrollRepository.getInfiniteScrollsWithPageLentgthClosure = { (_,_) in
            let dataToReturn = isPreconditionLoading ? preRefreshData : refreshResultData
            let publisher = CurrentValueSubject<[InfiniteScrollModel], Error>(dataToReturn)

            return publisher.eraseToAnyPublisher()
        }

        viewModel.contentStatePublisher.sink { state in
            switch state {
            case .loading(previousData: let previousData, state: let loadingState):
                if isPreconditionLoading == false {
                    XCTAssert(previousData.map({ $0.title }) == preRefreshData.map({ $0.title }))
                    XCTAssert(loadingState == .refresh)

                    loadingStateExpectation.fulfill()
                } else {
                    preconditionLoadingStateExpectation.fulfill()
                }
            case .content(data: let data, isListEnded: _):
                if isPreconditionLoading == false {
                    XCTAssert(data.map({ $0.title }) == refreshResultData.map({ $0.title }))

                    contentStateExpectation.fulfill()
                } else {
                    preconditionContentStateExpectation.fulfill()
                }
            default:
                XCTFail("Invalid state in \(#function)")
            }

        }.store(in: &cancellable)

        viewModel.loadNextPage()

        wait(for: [preconditionLoadingStateExpectation, preconditionContentStateExpectation],
                timeout: 1.0,
                enforceOrder: true)

        isPreconditionLoading = false

        viewModel.reloadContent()

        wait(for: [loadingStateExpectation, contentStateExpectation],
                timeout: 1.0,
                enforceOrder: true)
    }
}
