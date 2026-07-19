import Foundation
// filename: TCPNetworking.swift

import Primitives

/// TCP networking utility for performing HTTP requests (e.g. REST API calls).
/// Stateless and safe for use in concurrent contexts.
public struct TCPNetworking: Sendable {

    public init() {}

    /// Performs an HTTP GET request to the given URL and calls the completion handler.
    public func performRequest(url: URL, completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            let result: Result<Data, Error>
            if let error = error {
                result = .failure(error)
            } else if let data = data {
                result = .success(data)
            } else {
                result = .failure(NSError(domain: "TCPNetworking", code: -1, userInfo: nil))
            }

            DispatchQueue.global().async {
                completion(result)
            }
        }

        task.resume()
    }
}


