//
//  MVVMViewModel.swift
//  InfiniteScroll
//
//  Created by Artur Gevorkyan on 23.05.22.
//

import Combine
import Foundation

protocol MVVMViewModel {
    var contentStatePublisher: AnyPublisher<LCEPagedState<[InfiniteScrollItemDisplayData], InfiniteScrollViewError>, Never> { get }
    var environment: InfiniteScrollEnvironment { get }

    func loadInitialContent()
    func reloadContent()
    func loadNextPage()

    func openDetails(for itemIndex: Int)
}
