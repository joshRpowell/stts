//
//  SorryService.swift
//  stts
//

import Foundation

typealias SorryService = BaseSorryService & RequiredServiceProperties & RequiredSorryProperties

protocol RequiredSorryProperties {
    var pageID: String { get }
}

class BaseSorryService: BaseService {
    private enum SorryStatus: String, ComparableStatus {
        case operational
        case degraded
        case partiallyDegraded = "partially-degraded"

        var description: String {
            switch self {
            case .operational:
                return "Operational"
            case .degraded:
                return "Degraded"
            case .partiallyDegraded:
                return "Partially Degraded"
            }
        }
        var serviceStatus: ServiceStatus {
            switch self {
            case .operational:
                return .good
            case .degraded:
                return .major
            case .partiallyDegraded:
                return .minor
            }
        }
    }

    override func updateStatus(callback: @escaping (BaseService) -> Void) {
        guard let realSelf = self as? SorryService else { fatalError("BaseSorryService should not be used directly.") }

        let statusURL = URL(string: "https://api.sorryapp.com/v1/pages/\(realSelf.pageID)/components")!

        URLSession.shared.dataTask(with: statusURL) { [weak self] data, _, error in
            guard let selfie = self else { return }
            defer { callback(selfie) }
            guard let data = data else { return selfie._fail(error) }

            let json = try? JSONSerialization.jsonObject(with: data, options: [])

            guard let components = (json as? [String: Any])?["response"] as? [[String: Any]] else {
                return selfie._fail("Unexpected data")
            }

            let statuses = components.compactMap { $0["state"] as? String }.compactMap(SorryStatus.init(rawValue:))

            let highestStatus = statuses.max()
            self?.status = highestStatus?.serviceStatus ?? .undetermined
            self?.message = highestStatus?.description ?? "Undetermined"
        }.resume()
    }
}
