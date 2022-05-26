//
//  InfiniteScrollModuleBuilder.swift
//  InfiniteScroll
//
//  Created by Dmitrii Coolerov on 23.03.2022.
//

import Combine
import Foundation
import Swiftea
import Swinject
import UIKit

final class TCAInfiniteScrollModuleBuilder {
    private let resolver: Resolver
    private weak var moduleOutput: InfiniteScrollModuleOutput!

    init(
        resolver: Resolver,
        moduleOutput: InfiniteScrollModuleOutput
    ) {
        self.resolver = resolver
        self.moduleOutput = moduleOutput
    }

    func build() -> UIViewController {
        let feature = TCAInfiniteScrollFeature()
        let store = Store<TCAInfiniteScrollState, TCAInfiniteScrollEvent, TCAInfiniteScrollCommand, InfiniteScrollEnvironment>(
            state: TCAInfiniteScrollState(),
            reducer: feature.getReducer(),
            commandHandler: feature.getCommandHandler(
                environment: InfiniteScrollEnvironment(
                    infiniteScrollRepository: resolver.resolve(InfiniteScrollRepositoryProtocol.self)!,
                    moduleOutput: moduleOutput
                )
            )
        )

        let viewStore = ViewStore<TCAInfiniteScrollViewState, TCAInfiniteScrollViewEvent>(
            store: store,
            eventMapper: feature.getEventMapper(),
            stateMapper: feature.getStateMapper()
        )

        let viewController = TCAInfiniteScrollViewController(
            viewStore: viewStore,
            toastNotificationManager: resolver.resolve(ToastNotificationManagerProtocol.self)!
        )
        return viewController
    }
}
