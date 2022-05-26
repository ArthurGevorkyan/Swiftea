//
//  InfiniteScrollStructures.swift
//  InfiniteScroll
//
//  Created by Artur Gevorkyan on 23.05.22.
//

import Foundation

struct TitleItem: Hashable {
    let title: String
}

struct EmptyItem: Hashable {
    let title: String
}

struct LoadingErrorEmptyItem: Hashable {
    let title: String
}

struct LoadingItem: Hashable {
    private let id = UUID()
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return false
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct LoadingErrorContentItem: Hashable {
    private let id = UUID()
    let title: String
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return false
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct InfiniteScrollItemDisplayData: Equatable {
    let title: String
    let subtitle: String
    let id: String
    let details: String
}

enum InfiniteScrollViewError: Error, Equatable {
    case api
}

