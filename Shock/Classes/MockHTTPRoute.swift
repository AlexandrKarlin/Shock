//
//  MockHTTPRoute.swift
//  Shock
//
//  Created by Jack Newcombe on 27/06/2018.
//  Copyright © 2018 Just Eat. All rights reserved.
//
import Foundation
public enum MockHTTPRoute {
    
    case simple(
        method: MockHTTPMethod,
        urlPath: String,
        code: Int,
        filename: String?
    )
    
    case custom(
        method: MockHTTPMethod,
        urlPath: String,
        query: [String: String],
        requestHeaders: [String: String],
        requestBody: [UInt8]?,
        responseHeaders: [String: String],
        code: Int,
        filename: String?
    )
    
    case template(
        method: MockHTTPMethod,
        urlPath: String,
        code: Int,
        filename: String?,
        templateInfo: [String: AnyHashable?]
    )
    
    case redirect(
        urlPath: String,
        destination: String
    )
    
    case collection(
        routes: [MockHTTPRoute]
    )
    
    case timeout(
        method: MockHTTPMethod,
        urlPath: String,
        timeoutInSeconds: Int = 120
    )
    
    // Request fields
    
    public var urlPath: String? {
        switch self {
        case .simple(_, let urlPath, _, _),
             .custom(_, let urlPath, _, _, _, _, _, _),
             .template(_, let urlPath, _, _, _),
             .redirect(let urlPath, _),
             .timeout(_, let urlPath, _):
            return urlPath
        case .collection:
            return nil
        }
    }
    
    public var method: MockHTTPMethod? {
        switch self {
        case .simple(let method, _, _, _),
             .custom(let method, _, _, _, _, _, _, _),
             .template(let method, _, _, _, _),
             .timeout(let method, _, _):
            return method
        case .redirect:
            return .get
        case .collection:
            return nil
        }
    }
    
    public var requestHeaders: [String: String]? {
        switch self {
        case .custom(_, _, _, let headers, _, _, _, _):
            return headers
        case .simple, .template, .redirect, .collection, .timeout:
            return nil
        }
    }
    
    public var query: [String: String]? {
        switch self {
        case .custom(_, _, let query, _, _, _, _, _):
            return query
        case .simple, .template, .redirect, .collection, .timeout:
            return nil
        }
    }
    
    public var requestBody: [UInt8]? {
        switch self {
        case .custom(_, _, _, _, let requestBody, _, _, _):
            return requestBody
        default:
            return nil
        }
    }
    
    // Response fields
    
    var statusCode: Int? {
        switch self {
        case .custom(_, _, _, _, _, _, let statusCode, _),
             .simple(_, _, let statusCode, _),
             .template(_, _, let statusCode, _, _):
             return statusCode
        case .redirect:
            return 301
        default:
            return nil
        }
    }
    
    var responseHeaders: [String: String]? {
        switch self {
        case .custom(_, _, _, _, _, let responseHeaders, _, _):
            return responseHeaders
        default:
            return nil
        }
    }
    
    var filename: String? {
        switch self {
        case .custom(_, _, _, _, _, _, _, let filename),
             .simple(_, _, _, let filename),
             .template(_, _, _, let filename, _):
            return filename
        default:
            return nil
        }
    }
    
    var templateInfo:  [String: Any]? {
        switch self {
        case .template(_, _, _, _, let templateInfo):
            return templateInfo
        default:
            return nil
        }
    }
}
/// The philosophy for Equatable/Hashable `MockHTTPRoute` is anything in the request
/// part of the route (e.g. `method` or `urlPath`) are part of the identify of the route
extension MockHTTPRoute: Equatable {
    public static func == (lhs: MockHTTPRoute, rhs: MockHTTPRoute) -> Bool {
        if case MockHTTPRoute.simple(let lhsMethod, let lhsUrlPath, let _, _) = lhs,
           case MockHTTPRoute.simple(let rhsMethod, let rhsUrlPath, let _, _) = rhs {
            return lhsMethod == rhsMethod && lhsUrlPath.pathMatchesStrippingVariables(rhsUrlPath)
        }
        if case MockHTTPRoute.custom(let lhsMethod, let lhsUrlPath, let lhsQuery, _, let lhsRequestBody, let lhsResponseHeaders, _, _) = lhs,
           case MockHTTPRoute.custom(let rhsMethod, let rhsUrlPath, let rhsQuery, _, let rhsRequestBody, let rhsResponseHeaders, _, _) = rhs {
            return lhsMethod == rhsMethod && lhsUrlPath.pathMatchesStrippingVariables(rhsUrlPath)
                && lhsQuery == rhsQuery && lhsRequestBody == rhsRequestBody && headers(lhsResponseHeaders, contains: rhsResponseHeaders)
        }
        if case MockHTTPRoute.template(let lhsMethod, let lhsUrlPath, let _, _, _) = lhs,
           case MockHTTPRoute.template(let rhsMethod, let rhsUrlPath, let _, _, _) = rhs {
            return lhsMethod == rhsMethod && lhsUrlPath.pathMatchesStrippingVariables(rhsUrlPath)
        }
        if case MockHTTPRoute.redirect(let lhsUrlPath, _) = lhs,
           case MockHTTPRoute.redirect(let rhsUrlPath, _) = rhs {
            return lhsUrlPath.pathMatchesStrippingVariables(rhsUrlPath)
        }
        if case MockHTTPRoute.timeout(let lhsMethod, let lhsUrlPath, _) = lhs,
           case MockHTTPRoute.timeout(let rhsMethod, let rhsUrlPath, _) = rhs {
            return lhsMethod == rhsMethod && lhsUrlPath.pathMatchesStrippingVariables(rhsUrlPath)
        }
        if case MockHTTPRoute.collection(let lhsRoutes) = lhs,
           case MockHTTPRoute.collection(let rhsRoutes) = rhs {
            return lhsRoutes.elementsEqual(rhsRoutes)
        }
        return false
    }
    
    private static func headers(_ lhs: [String:String], contains rhs: [String:String]) -> Bool {
        guard !(lhs.isEmpty && rhs.isEmpty) else { return true }
        var bigger = lhs
        var smaller = rhs
        if smaller.count != bigger.count {
            bigger = lhs.count > rhs.count ? lhs : rhs
            smaller = lhs.count < rhs.count ? lhs : rhs
        }
        guard !smaller.isEmpty else { return true }
        for outer in smaller {
            let result = bigger.contains() { (key: String, value: String) in
                key.lowercased() == outer.key.lowercased() && value.lowercased() == outer.value.lowercased()
            }
            if result {
                return true
            }
        }
        return false
    }
    
    public func matches(method: MockHTTPMethod, path: String, params: [String:String], headers: [String:String], requestBody: [UInt8]?) -> Bool {
        guard !method.rawValue.isEmpty else { return false }
        guard !path.isEmpty else { return false }
        switch self {
        case .simple:
            return MockHTTPRoute.simple(method: method, urlPath: path, code: 0, filename: nil) == self
        case .custom:
            return MockHTTPRoute.custom(method: method, urlPath: path, query: params, requestHeaders: headers, requestBody: requestBody, responseHeaders: [:], code: 0, filename: nil) == self
        case .template:
            return MockHTTPRoute.template(method: method, urlPath: path, code: 0, filename: nil, templateInfo: [:]) == self
        case .redirect:
            return MockHTTPRoute.redirect(urlPath: path, destination: "") == self
        case .collection:
            return false
        case .timeout:
            return MockHTTPRoute.timeout(method: method, urlPath: path, timeoutInSeconds: 0) == self
        }
    }
}
extension String {
    func pathMatchesStrippingVariables(_ other: String) -> Bool {
        let bothTemplates = self.contains() { $0 == ":" } && other.contains() { $0 == ":" }
        let parts = self.split(separator: "/")
        let otherParts = other.split(separator: "/")
        guard parts.count == otherParts.count else { return false }
        var match = true
        for (index, part) in parts.enumerated() {
            let otherPart = otherParts[index]
            if !bothTemplates {
                if part.hasPrefix(":") {
                    continue
                }
                if otherPart.hasPrefix(":") {
                    continue
                }
            }
            match = part.lowercased() == otherPart.lowercased()
            if !match {
                break
            }
        }
        return match
    }
}
