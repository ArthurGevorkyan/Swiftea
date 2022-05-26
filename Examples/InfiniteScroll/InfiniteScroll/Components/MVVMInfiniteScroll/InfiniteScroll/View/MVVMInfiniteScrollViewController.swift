//
//  MVVMInfiniteScrollViewController.swift
//  InfiniteScroll
//
//  Created by Artur Gevorkyan on 23.05.22.
//

import Combine
import Foundation
import UIKit

final class MVVMinfiniteScrollViewController: UIViewController {

    enum Section: Int {
        case contents
        case errors
        case loaders
    }

    // MARK: Private properties

    private let viewModel: MVVMViewModel
    private let toastNotificationManager: ToastNotificationManagerProtocol?
    private weak var tableView: UITableView?
    private var dataSource: UITableViewDiffableDataSource<Int, AnyHashable>!

    private var cancellable = Set<AnyCancellable>()

    init(
        viewModel: MVVMViewModel,
        toastNotificationManager: ToastNotificationManagerProtocol?
    ) {
        self.viewModel = viewModel
        self.toastNotificationManager = toastNotificationManager
        super.init(nibName: nil, bundle: nil)
    }


    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func bindViewModel() {
        viewModel.contentStatePublisher.throttle(
            for: 0.25,
               scheduler: viewModel.environment.mainQueue,
               latest: true
        ).sink { [weak self] contentStateValue in
            self?.updateView(for: contentStateValue)
        }.store(in: &cancellable)
    }

    deinit {
        cancellable.forEach {
            $0.cancel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let tableView = UITableView(frame: .zero)
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
        ])
        self.tableView = tableView

        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: String(describing: type(of: UITableViewCell.self))
        )

        tableView.delegate = self
        dataSource = UITableViewDiffableDataSource<Int, AnyHashable>(
            tableView: tableView
        ) { tableView, indexPath, itemIdentifier in
            self.cell(with: tableView, indexPath: indexPath, itemIdentifier: itemIdentifier)
        }
        dataSource.defaultRowAnimation = .fade

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        bindViewModel()
        viewModel.loadInitialContent()
    }

    // MARK: Private methods

    @objc private func refresh() {
        viewModel.reloadContent()
    }

    // swiftlint:disable:next function_body_length
    private func cell(
        with tableView: UITableView,
        indexPath: IndexPath,
        itemIdentifier: AnyHashable
    ) -> UITableViewCell {
        switch itemIdentifier {
        case let itemIdentifier as TitleItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = itemIdentifier.title
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .left
            return cell

        case is LoadingItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = "Loading... ⌛⌛⌛"
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            return cell

        case let item as LoadingErrorContentItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = item.title
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            return cell

        case let item as LoadingErrorEmptyItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = item.title
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            return cell

        case let item as EmptyItem:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: String(describing: type(of: UITableViewCell.self)),
                for: indexPath
            )
            cell.selectionStyle = .none
            cell.textLabel?.text = item.title
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.textAlignment = .center
            return cell

        default:
            fatalError("Unexpected state")
        }
    }

    private func makeBlankSnapshot() -> NSDiffableDataSourceSnapshot<Int, AnyHashable> {
        var snapshot = NSDiffableDataSourceSnapshot<Int, AnyHashable>()

        snapshot.appendSections([Section.contents.rawValue])
        snapshot.appendSections([Section.errors.rawValue])
        snapshot.appendSections([Section.loaders.rawValue])

        return snapshot
    }

    private func cellItemData(from displayData: [InfiniteScrollItemDisplayData]) -> [TitleItem] {
        return displayData.map { displayData -> TitleItem in
            let title = "\(displayData.title)\n\(displayData.id)"
            return TitleItem(title: title)
        }
    }

    private func updateView(for state: LCEPagedState<[InfiniteScrollItemDisplayData], InfiniteScrollViewError>) {
        var snapshot = makeBlankSnapshot()
        switch state {
        case .loading(previousData: let previousData, state: let loadingState):
            let display = cellItemData(from: previousData)
            snapshot.appendItems(display, toSection: Section.contents.rawValue)

            if loadingState == .nextPage {
                snapshot.appendItems([LoadingItem()], toSection: Section.loaders.rawValue)
            }

            break
        case .error(previousData: let previousData, isListEnded: let isListEnded, error: let error):
            tableView?.refreshControl?.endRefreshing()
            if previousData.isEmpty {
                let displayData: [AnyHashable] = [
                    LoadingErrorEmptyItem(
                        title: "Error happens. Tap to reload list\n\nDetails:\n\(error.localizedDescription)"
                    ),
                ]
                snapshot.appendItems(displayData, toSection: Section.errors.rawValue)
            } else {

                toastNotificationManager?.showNotification(with: .danger(
                    title: "Error",
                    message: error.localizedDescription
                ))

                let display = cellItemData(from: previousData)

                snapshot.appendItems(display, toSection: Section.contents.rawValue)

                if !isListEnded {
                    snapshot.appendItems([LoadingErrorContentItem(title: "Tap to load more")], toSection: Section.errors.rawValue)
                }
            }

            break
        case .content(data: let displayData, isListEnded: let isListEnded):
            tableView?.refreshControl?.endRefreshing()

            if displayData.isEmpty {
                snapshot.appendItems([EmptyItem(title: "List is empty")], toSection: Section.contents.rawValue)
            } else {
                let display = cellItemData(from: displayData)
                snapshot.appendItems(display, toSection: Section.contents.rawValue)
            }

            if !isListEnded {
                snapshot.appendItems([LoadingErrorContentItem(title: "Tap to load more")], toSection: Section.loaders.rawValue)
            }

            break
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }
}


extension MVVMinfiniteScrollViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let section = MVVMinfiniteScrollViewController.Section(rawValue: indexPath.section)
        guard case .loaders = section else {
            return
        }

        viewModel.loadNextPage()
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let itemIdentifier = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        switch itemIdentifier {
        case is LoadingItem:
            fallthrough
        case is EmptyItem:
            break
        case is LoadingErrorContentItem:
            fallthrough
        case is LoadingErrorEmptyItem:
            viewModel.loadNextPage()

        case is TitleItem:
            viewModel.openDetails(for: indexPath.row)
            break
        default:
            fatalError("Unexpected state")
        }
    }
    // swiftlint:disable:next file_length
}
