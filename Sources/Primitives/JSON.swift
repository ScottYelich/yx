import Foundation
//
//  JSON.swift
//  yx
//
//  Created by Scott Yelich on 5/20/25.
//


// filename: JSON.swift


public enum JSON: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSON])
    case object([String: JSON])

    public init?(_ any: Any) {
        switch any {
        case let s as String:
            self = .string(s)
        case let i as Int:
            self = .int(i)
        case let d as Double:
            self = .double(d)
        case let b as Bool:
            self = .bool(b)
        case is NSNull:
            self = .null
        case let a as [Any]:
            let converted = a.compactMap { JSON($0) }
            guard converted.count == a.count else { return nil }
            self = .array(converted)
        case let o as [String: Any]:
            var result: [String: JSON] = [:]
            for (k, v) in o {
                guard let jsonValue = JSON(v) else { return nil }
                result[k] = jsonValue
            }
            self = .object(result)
        default:
            return nil
        }
    }

    public var rawValue: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .null: return NSNull()
        case .array(let array): return array.map { $0.rawValue }
        case .object(let dict): return dict.mapValues { $0.rawValue }
        }
    }
}

public extension Dictionary where Key == String, Value == JSON {
    var rawValue: [String: Any] {
        mapValues { $0.rawValue }
    }

    init?(_ raw: [String: Any]) {
        var result: [String: JSON] = [:]
        for (k, v) in raw {
            guard let json = JSON(v) else { return nil }
            result[k] = json
        }
        self = result
    }
}

public extension JSON {
    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }
}

