//
//  LCEPagedState.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 05.05.2022.
//

import Foundation

public enum LCEPagedLoadingState {
    case refresh
    case nextPage
}

public enum LCEPagedState<T: Collection & Equatable, K: Equatable>: Equatable {
    case loading(previousData: T, state: LCEPagedLoadingState)
    case content(data: T, isListEnded: Bool)
    case error(previousData: T, isListEnded: Bool, error: K)
}

extension LCEPagedState {
    var data: T {
        switch self {
        case .loading(previousData: let data, state: _),
                .content(data: let data, isListEnded: _),
                .error(previousData: let data, isListEnded: _, error: _):
            return data
        }
    }
}
