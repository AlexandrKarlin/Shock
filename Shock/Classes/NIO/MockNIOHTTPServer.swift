//
//  MockNIOHTTPServer.swift
//  Shock
//
//  Created by Antonio Strijdom on 30/09/2020.
//

import Foundation
import NIO
import NIOHTTP1

/// SwiftNIO implementation of mock HTTP server
class MockNIOHttpServer: MockNIOBaseServer, MockHttpServer {
    
    private let responseFactory: ResponseFactory
    private var httpHandlers: [MockNIOHTTPHandler]
    private var router = MockNIOHTTPRouter()
    private var middleware = [Middleware]()
    private var routeMiddleware: MockRoutesMiddleware?
    var notFoundHandler: HandlerClosure?
    
    init(responseFactory: ResponseFactory) {
        self.responseFactory = responseFactory
        self.httpHandlers = []
        super.init()
    }
    
    func start(_ port: Int, forceIPv4: Bool, priority: DispatchQoS.QoSClass) throws -> Void {
        try start(port) { (channel) -> EventLoopFuture<Void> in
            channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                let httpHandler = MockNIOHTTPHandler(responseFactory: self.responseFactory,
                                                      router: self.router,
                                                      middleware: self.middleware,
                                                      notFoundHandler: self.notFoundHandler)
                self.httpHandlers.append(httpHandler)
                return channel.pipeline.addHandler(httpHandler)
            }
        }
    }
    
    func register(route: MockHTTPRoute, handler: HandlerClosure?) {
        if let urlPath = route.urlPath, urlPath.isEmpty {
            return
        }
        self.router.register(route: route, handler: handler)
    }
    
    func add(middleware: Middleware) {
        self.middleware.append(middleware)
    }
    
    func replaceMiddleware(with middleware: [Middleware]) {
        self.middleware = middleware
        for httpHandler in self.httpHandlers {
            httpHandler.replaceMiddleware(with: middleware)
        }
    }
    
    func has<T>(middlewareOfType type: T.Type) -> Bool where T: Middleware {
        return (self.middleware ?? []).contains { $0 is T }
    }
}

struct MockNIOHTTPRequest: MockHttpRequest {
    var eventLoop: EventLoop
    var path: String
    var queryParams: [(String, String)]
    var method: String
    var headers: [String : String]
    var body: [UInt8]
    var address: String?
    var params: [String : String]
}

struct RouteHandlerMapping {
    let route: MockHTTPRoute
    let handler: HandlerClosure
}

struct MockNIOHTTPRouter: MockHttpRouter {
    private var routes = [MockHTTPMethod: [RouteHandlerMapping]]()
    
    var requiresRouteMiddleware: Bool {
        !routes.isEmpty
    }
    
    func handlerForMethod(_ method: String, path: String, params: [String:String], headers: [String:String], requestBody: [UInt8]) -> HandlerClosure? {
        guard let httpMethod = MockHTTPMethod(rawValue: method.uppercased()) else { return nil }
        let methodRoutes = routes[httpMethod] ?? [RouteHandlerMapping]()
        for mapping in methodRoutes {
            let result = mapping.route.matches(method: httpMethod, path: path, params: params, headers: headers, requestBody: requestBody.count > 0 ? requestBody : nil)
            if result {
                return mapping.handler
            }
        }
        return nil
    }
    
    mutating func register(route: MockHTTPRoute, handler: HandlerClosure?) {
        guard let method = route.method else { return }
        var methodRoutes = routes[method] ?? [RouteHandlerMapping]()
        if methodRoutes.contains() { $0.route == route } {
            methodRoutes = methodRoutes.filter({ $0.route != route })
        }
        if let handler = handler {
            methodRoutes.append(RouteHandlerMapping(route: route, handler: handler))
        }
        routes[method] = methodRoutes
    }
}
