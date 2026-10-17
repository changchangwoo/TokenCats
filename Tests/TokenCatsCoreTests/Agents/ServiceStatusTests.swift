import Foundation
import Testing
@testable import TokenCatsCore

struct ServiceStatusTests {
    @Test func readsOnlyThePublishedCodexComponent() async {
        let transport = FakeTransport(["GET /api/v2/summary.json": [(200, #"{"status":{"indicator":"major"},"components":[{"name":"Codex in ChatGPT Desktop","status":"degraded_performance"},{"name":"Responses","status":"operational"}]}"#)]])
        #expect(await ServiceStatusClient(transport: transport).codex() == .incident("Codex in ChatGPT Desktop"))
        #expect(transport.sent.first?.url?.host == "status.openai.com")
    }

    @Test func unrelatedOpenAIIncidentDoesNotMarkCodexAsDown() async {
        let transport = FakeTransport(["GET /api/v2/summary.json": [(200, #"{"status":{"indicator":"major"},"components":[{"name":"Codex in ChatGPT Desktop","status":"operational"},{"name":"Responses","status":"major_outage"}]}"#)]])
        #expect(await ServiceStatusClient(transport: transport).codex() == .operational)
    }

    @Test func reportsOnlyRelevantClaudeOutages() async {
        let transport = FakeTransport(["GET /api/v2/summary.json": [(200, #"{"status":{"indicator":"major"},"components":[{"name":"Claude Code","status":"operational"},{"name":"Claude API (api.anthropic.com)","status":"degraded_performance"},{"name":"claude.ai","status":"major_outage"}]}"#)]])
        let status = await ServiceStatusClient(transport: transport).claudeCode()
        #expect(status == .incident("Claude API (api.anthropic.com)"))
        #expect(transport.sent.first?.url?.host == "status.claude.com")
    }

    @Test func ignoresUnrelatedIncidentsAndHandlesBadResponses() async {
        let unrelated = FakeTransport(["GET /api/v2/summary.json": [(200, #"{"status":{"indicator":"major"},"components":[{"name":"Claude Code","status":"operational"},{"name":"Claude API (api.anthropic.com)","status":"operational"},{"name":"claude.ai","status":"major_outage"}]}"#)]])
        #expect(await ServiceStatusClient(transport: unrelated).claudeCode() == .operational)
        let invalid = FakeTransport(["GET /api/v2/summary.json": [(503, "unavailable")]])
        #expect(await ServiceStatusClient(transport: invalid).claudeCode() == .unavailable)
    }
}
