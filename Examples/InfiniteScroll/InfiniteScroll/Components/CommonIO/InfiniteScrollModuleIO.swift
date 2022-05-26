//
//  InfiniteScrollModuleIO.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 17.04.2022.
//

import Foundation

protocol InfiniteScrollModuleOutput: AnyObject {
    func infiniteScrollModuleWantsToOpenDetails(with id: String)
}

enum InfiniteScrollAPIError: Error, Equatable {
    case networkError
}

struct InfiniteScrollEnvironment {
    let pageLentgth = 15
    let mainQueue: DispatchQueue = .main
    let backgroundQueue: DispatchQueue = .global(qos: .background)
    let infiniteScrollRepository: InfiniteScrollRepositoryProtocol
    weak var moduleOutput: InfiniteScrollModuleOutput?
}
