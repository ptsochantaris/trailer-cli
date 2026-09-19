import Foundation
import Testing
import TrailerJson
@testable import trailer

@Suite("GitHub payload parsing")
@MainActor
struct StatusParsingTests {
    private func entry(_ json: String) throws -> TypedJson.Entry {
        try #require(try Data(json.utf8).asTypedJson())
    }

    @Test("ISO-8601 timestamps from the API are parsed as UTC")
    func parsesTimestamps() throws {
        let date = try #require(GHDateFormatter.parseGH8601("2024-03-17T09:41:00Z"))
        #expect(date == Date(timeIntervalSince1970: 1_710_668_460))
    }

    @Test("Malformed or absent timestamps yield nil rather than a wrong date")
    func rejectsBadTimestamps() {
        #expect(GHDateFormatter.parseGH8601(nil) == nil)
        #expect(GHDateFormatter.parseGH8601("") == nil)
        #expect(GHDateFormatter.parseGH8601("not a date") == nil)
    }

    /// A StatusContext carries `createdAt`, `targetUrl` and `state` under those names.
    @Test("A StatusContext populates its date, url and state")
    func parsesStatusContext() throws {
        let node = try entry("""
        {"__typename":"StatusContext","id":"SC_1","context":"ci/build",
         "description":"Build passed","state":"SUCCESS",
         "targetUrl":"https://ci.example.com/1","createdAt":"2024-03-17T09:41:00Z"}
        """)
        let status = try #require(Status(id: "SC_1", type: "StatusContext", node: node))
        #expect(status.context == "ci/build")
        #expect(status.description == "Build passed")
        #expect(status.state == .success)
        #expect(status.targetUrl.absoluteString == "https://ci.example.com/1")
        #expect(status.createdAt == Date(timeIntervalSince1970: 1_710_668_460))
    }

    /// Regression: a CheckRun names the same concepts `startedAt`/`completedAt` and `permalink`.
    /// These were previously never read, so every check run was left at `.distantPast` with an
    /// empty target URL, which broke the ordering of `PullRequest.latestStatuses`.
    @Test("A CheckRun populates its date from startedAt and its url from permalink")
    func parsesCheckRun() throws {
        let node = try entry("""
        {"__typename":"CheckRun","id":"CR_1","name":"build (macos-latest)",
         "conclusion":"SUCCESS","startedAt":"2024-03-17T09:41:00Z",
         "completedAt":"2024-03-17T10:00:00Z",
         "permalink":"https://github.com/o/r/runs/1"}
        """)
        let status = try #require(Status(id: "CR_1", type: "CheckRun", node: node))
        #expect(status.description == "build (macos-latest)")
        #expect(status.state == .success)
        #expect(status.createdAt == Date(timeIntervalSince1970: 1_710_668_460))
        #expect(status.targetUrl.absoluteString == "https://github.com/o/r/runs/1")
        #expect(status.createdAt != .distantPast)
    }

    @Test("A CheckRun with no startedAt falls back to completedAt")
    func checkRunFallsBackToCompletedAt() throws {
        let node = try entry("""
        {"__typename":"CheckRun","id":"CR_2","name":"lint","conclusion":"FAILURE",
         "startedAt":null,"completedAt":"2024-03-17T10:00:00Z",
         "permalink":"https://github.com/o/r/runs/2"}
        """)
        let status = try #require(Status(id: "CR_2", type: "CheckRun", node: node))
        #expect(status.createdAt == Date(timeIntervalSince1970: 1_710_669_600))
        #expect(status.state == .failure)
    }

    @Test("Check run conclusions map onto status states", arguments: [
        ("SUCCESS", StatusState.success),
        ("FAILURE", StatusState.failure),
        ("NEUTRAL", StatusState.neutral),
        ("CANCELLED", StatusState.cancelled),
        ("SKIPPED", StatusState.skipped),
        ("ACTION_REQUIRED", StatusState.actionRequired)
    ])
    func conclusionMapping(_ raw: String, _ expected: StatusState) throws {
        let node = try entry("""
        {"__typename":"CheckRun","id":"CR_3","name":"x","conclusion":"\(raw)",
         "startedAt":"2024-03-17T09:41:00Z","completedAt":"2024-03-17T10:00:00Z",
         "permalink":"https://example.com"}
        """)
        let status = try #require(Status(id: "CR_3", type: "CheckRun", node: node))
        #expect(status.state == expected)
    }
}
