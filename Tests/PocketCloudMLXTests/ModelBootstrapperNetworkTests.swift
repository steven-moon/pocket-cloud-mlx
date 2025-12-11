import XCTest
@testable import PocketCloudMLX
import PocketCloudCommon

@MainActor
final class ModelBootstrapperNetworkTests: XCTestCase {

    override class func setUp() {
        URLProtocol.registerClass(TestURLProtocol.self)
    }

    override class func tearDown() {
        TestURLProtocol.requestHandler = nil
        URLProtocol.unregisterClass(TestURLProtocol.self)
    }

    func testBootstrapperUsesNetworkManager() async throws {
        let expectedBody = #"{"model_type":"test"}"#.data(using: .utf8)!

        TestURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, expectedBody)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TestURLProtocol.self]

        let manager = NetworkManager.makeDefault(
            tokenLoader: { nil },
            configuration: config
        )
        let bootstrapper = ModelBootstrapper(networkManager: manager)

        let data = try await bootstrapper.fetchConfig(for: "mlx-community/Test-Model")

        XCTAssertEqual(data, expectedBody)
        XCTAssertEqual(TestURLProtocol.lastRequest?.url?.absoluteString, "https://huggingface.co/mlx-community/Test-Model/resolve/main/config.json")
    }
}

@MainActor
final class TestURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = TestURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            TestURLProtocol.lastRequest = request
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
