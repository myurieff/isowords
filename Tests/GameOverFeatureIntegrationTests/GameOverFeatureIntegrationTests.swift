import ComposableArchitecture
import DatabaseClient
import GameOverFeature
import IntegrationTestHelpers
import SharedModels
import SiteMiddleware
import XCTest

class GameOverFeatureIntegrationTests: XCTestCase {
  func testSubmitSoloScore() {
    let ranks: [TimeScope: LeaderboardScoreResult.Rank] = [
      .allTime: .init(outOf: 100, rank: 10000),
      .lastWeek: .init(outOf: 10, rank: 1000),
      .lastDay: .init(outOf: 1, rank: 100),
    ]

    var serverEnvironment = ServerEnvironment.failing
    serverEnvironment.database.fetchPlayerByAccessToken = { _ in
      .init(value: .blob)
    }
    serverEnvironment.database.fetchLeaderboardSummary = {
      .init(value: ranks[$0.timeScope]!)
    }
    serverEnvironment.database.submitLeaderboardScore = {
      .init(
        value: .init(
          createdAt: .mock,
          dailyChallengeId: $0.dailyChallengeId,
          gameContext: .solo,
          gameMode: $0.gameMode,
          id: .init(rawValue: UUID()),
          language: $0.language,
          moves: $0.moves,
          playerId: $0.playerId,
          puzzle: $0.puzzle,
          score: $0.score
        )
      )
    }
    serverEnvironment.dictionary.contains = { _, _ in true }
    serverEnvironment.router = .test

    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient = .init(
      middleware: siteMiddleware(environment: serverEnvironment),
      router: .test
    )
    environment.database.playedGamesCount = { _ in .init(value: 0) }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettings = .none

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .mock,
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    store.send(.onAppear)

    store.receive(.delayedOnAppear) {
      $0.isViewEnabled = true
    }
    store.receive(.submitGameResponse(.success(.solo(.init(ranks: ranks))))) {
      $0.summary = .leaderboard(ranks)
    }
  }
}
