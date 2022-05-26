//
//  InfiniteScrollFlowCoordinator.swift
//  InfiniteScroll
//
//  Created by Arthur Gevorkyan on 21.05.2022.
//

import Foundation
import Swinject
import UIKit

final class MVVMInfiniteScrollFlowCoordinator: FlowCoordinatorProtocol {
    private weak var window: UIWindow?
    private weak var rootViewController: UINavigationController?
    private let resolver: Resolver
    private var childFlowCoordinator: FlowCoordinatorProtocol?

    private(set) var state: FlowCoordinatorState = .created

    init(
        window: UIWindow,
        resolver: Resolver
    ) {
        self.window = window
        self.resolver = resolver
    }

    func start() {
        guard state == .created else {
            return
        }
        state = .started

        let viewController = MVVMInfiniteScrollModuleBuilder(
            resolver: resolver,
            moduleOutput: self
        ).build()
        viewController.title = "MVVMInfiniteScroll"

        let nvc = UINavigationController(rootViewController: viewController)
        rootViewController = nvc

        let tabBarItem = UITabBarItem(
            title: "MVVMInfiniteScroll",
            image: UIImage(systemName: "scribble"),
            selectedImage: UIImage(systemName: "scribble.variable")
        )
        nvc.tabBarItem = tabBarItem

        rootViewController = nvc

        if let existingRoot = window?.rootViewController {
            existingRoot.addChild(nvc)
        } else {
            window?.rootViewController = nvc
        }

    }

    func handleDeeplink(with _: URL) {
        // unused
    }

    func finish(compltion: @escaping () -> Void) {
        guard state == .started else {
            compltion()
            return
        }
        state = .finished

        compltion()
    }
}

extension MVVMInfiniteScrollFlowCoordinator: InfiniteScrollModuleOutput {
    func infiniteScrollModuleWantsToOpenDetails(with id: String) {
        resolver.resolve(ToastNotificationManagerProtocol.self)!.showNotification(
            with: .info(
                title: "Details did open",
                message: id
            )
        )
    }
}
