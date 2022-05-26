//
//  MVVMInfiniteScrollModuleBuilder.swift
//  InfiniteScroll
//
//  Created by Artur Gevorkyan on 23.05.22.
//

import Foundation
import Swinject

final class MVVMInfiniteScrollModuleBuilder {
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

        let environment = InfiniteScrollEnvironment(
            infiniteScrollRepository: resolver.resolve(InfiniteScrollRepositoryProtocol.self)!,
            moduleOutput: moduleOutput
        )
        let viewModel = DefaultMVVMViewModel(environment: environment)

        let viewController = MVVMinfiniteScrollViewController(
            viewModel: viewModel,
            toastNotificationManager: resolver.resolve(ToastNotificationManagerProtocol.self)!
        )
        return viewController
    }
}
