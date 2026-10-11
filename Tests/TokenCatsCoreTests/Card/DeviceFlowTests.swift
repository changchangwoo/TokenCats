import Foundation
import Testing
@testable import TokenCatsCore

private actor Sleeps {
    var seconds: [Int] = []
    func add(_ value: Int) { seconds.append(value) }
}

private let start = Date(timeIntervalSince1970: 1_800_000_000)
private let codeBody = #"{"device_code":"dev123","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":900,"interval":5}"#

private func flow(_ script: [String: [(Int, String)]], sleeps: Sleeps) -> (DeviceFlow, FakeTransport) {
    let transport = FakeTransport(script)
    return (DeviceFlow(clientID: "Iv1.abc", transport: transport, sleep: { await sleeps.add($0) }, now: { start }), transport)
}

struct DeviceFlowTests {
    @Test func startAsksForACode() async throws {
        let (device, transport) = flow(["POST /login/device/code": [(200, codeBody)]], sleeps: Sleeps())
        let code = try await device.start()
        #expect(code == DeviceCode(deviceCode: "dev123", userCode: "ABCD-1234",
                                   verificationURI: URL(string: "https://github.com/login/device")!,
                                   interval: 5, expiresIn: 900))
        #expect(transport.sent[0].url?.host == "github.com")
        #expect(String(decoding: transport.sent[0].httpBody ?? Data(), as: UTF8.self) == "client_id=Iv1.abc")
        #expect(transport.sent[0].value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func pollsUntilTheUserApproves() async throws {
        let sleeps = Sleeps()
        let (device, transport) = flow(["POST /login/oauth/access_token": [
            (200, #"{"error":"authorization_pending"}"#),
            (200, #"{"error":"authorization_pending"}"#),
            (200, #"{"access_token":"ghu_x","token_type":"bearer","scope":""}"#),
        ]], sleeps: sleeps)
        let token = try await device.poll(DeviceCode(deviceCode: "dev123", userCode: "ABCD-1234",
                                                     verificationURI: URL(string: "https://github.com/login/device")!,
                                                     interval: 5, expiresIn: 900))
        #expect(token == UserToken(accessToken: "ghu_x", expiresAt: nil))
        #expect(await sleeps.seconds == [5, 5, 5])
        #expect(String(decoding: transport.sent[0].httpBody ?? Data(), as: UTF8.self)
                == "client_id=Iv1.abc&device_code=dev123&grant_type=urn:ietf:params:oauth:grant-type:device_code")
    }

    @Test func slowDownWaitsLonger() async throws {
        let sleeps = Sleeps()
        let (device, _) = flow(["POST /login/oauth/access_token": [
            (200, #"{"error":"slow_down","interval":10}"#),
            (200, #"{"access_token":"ghu_x","expires_in":28800}"#),
        ]], sleeps: sleeps)
        let token = try await device.poll(DeviceCode(deviceCode: "d", userCode: "u",
                                                     verificationURI: URL(string: "https://github.com/login/device")!,
                                                     interval: 5, expiresIn: 900))
        #expect(await sleeps.seconds == [5, 10])
        #expect(token.expiresAt == start.addingTimeInterval(28_800))
    }

    @Test(arguments: [("access_denied", DeviceFlowError.denied), ("expired_token", .expired),
                      ("device_flow_disabled", .disabled), ("incorrect_client_credentials", .unexpected("incorrect_client_credentials"))])
    func stopsOnFinalErrors(error: String, expected: DeviceFlowError) async {
        let (device, _) = flow(["POST /login/oauth/access_token": [(200, #"{"error":"\#(error)"}"#)]], sleeps: Sleeps())
        await #expect(throws: expected) {
            try await device.poll(DeviceCode(deviceCode: "d", userCode: "u",
                                             verificationURI: URL(string: "https://github.com/login/device")!,
                                             interval: 5, expiresIn: 900))
        }
    }

    @Test func expiredTokensNeedReconnecting() {
        #expect(!UserToken(accessToken: "a", expiresAt: nil).isExpired(now: start))
        #expect(UserToken(accessToken: "a", expiresAt: start.addingTimeInterval(-1)).isExpired(now: start))
        #expect(!UserToken(accessToken: "a", expiresAt: start.addingTimeInterval(60)).isExpired(now: start))
    }
}
