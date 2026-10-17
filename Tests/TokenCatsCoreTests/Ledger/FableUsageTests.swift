import Foundation
import Testing
@testable import TokenCatsCore

struct FableUsageTests {
    @Test func readsFablePercentFromClaudeUsageCommand() {
        let output = #"{"type":"result","is_error":false,"usage":{"input_tokens":0,"output_tokens":0},"result":"Current session: 4% used\nCurrent week (all models): 1% used\nCurrent week (Fable): 38% used · resets Oct 24 at 3pm (Asia/Seoul)"}"#
        #expect(FableUsageParser.percent(from: Data(output.utf8)) == 38)
    }

    @Test func doesNotSubstituteAllModelUsageWhenFableIsMissing() {
        let output = #"{"type":"result","is_error":false,"result":"Current week (all models): 72% used"}"#
        #expect(FableUsageParser.percent(from: Data(output.utf8)) == nil)
        #expect(FableUsageParser.percent(from: Data(#"{"type":"result","is_error":true,"result":"Current week (Fable): 38% used"}"#.utf8)) == nil)
    }
}
