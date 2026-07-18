import Foundation
@testable import TypingFarmerCore

private let runCoreTests: Void = {
    testGameStateDefaultsAreFarmOnly()
    testGameStateDefaultsIncludeOneDog()
    testLegacyGameStateMigratesDefaultDog()
    testKeyboardInputGrowsMatchingKeyAndRecordsStats()
    testPlantUnlockHarvestAndAutoHarvestBehaviorsStayStable()
    testMatureHarvestCandidateDoesNotMutateState()
    testMatureHarvestCandidateCanExcludePendingKeys()
    testAdoptPetSpendsCoinsAndAllowsRepeats()
    testAdoptPetFailsWithoutEnoughCoins()
    testPomodoroSettingsClampAndRoundTripThroughGameState()
}()

private func testGameStateDefaultsAreFarmOnly() {
    let state = GameState.defaultState()

    precondition(state.coins == 0)
    precondition(state.unlockedCropIDs == ["wheat"])
    precondition(state.keyPlots.count == KeyboardLayout.allKeys.count)
    precondition(state.version == GameState.currentVersion)

    do {
        let data = try JSONEncoder().encode(state)
        let json = String(decoding: data, as: UTF8.self)
        precondition(!json.contains("windowSettings"))
    } catch {
        preconditionFailure("GameState should encode without app window settings: \(error)")
    }
}

private func testGameStateDefaultsIncludeOneDog() {
    let state = GameState.defaultState()

    precondition(state.adoptedPets.count == 1)
    precondition(state.adoptedPets.first?.definitionID == "dog")
}

private func testLegacyGameStateMigratesDefaultDog() {
    let json = """
    {
      "version": 2,
      "coins": 0,
      "unlockedCropIDs": ["wheat"],
      "keyPlots": [],
      "selectedCropID": "wheat",
      "tasks": [],
      "dailyStats": {},
      "pomodoroSettings": {"durationMinutes": 25}
    }
    """

    do {
        let decoded = try JSONDecoder().decode(GameState.self, from: Data(json.utf8))
        precondition(decoded.version == GameState.currentVersion)
        precondition(decoded.adoptedPets.count == 1)
        precondition(decoded.adoptedPets.first?.definitionID == "dog")
    } catch {
        preconditionFailure("Legacy GameState should migrate default dog: \(error)")
    }
}

private func testKeyboardInputGrowsMatchingKeyAndRecordsStats() {
    var engine = FarmEngine(state: .defaultState())
    let date = Date(timeIntervalSince1970: 1_735_689_600)

    engine.apply(InputEvent(kind: .keyboard, timestamp: date, count: 5, keyCode: 0, keyLabel: "A"))

    precondition(engine.state.keyPlots.first { $0.keyCode == 0 }?.progress == 5)
    precondition(engine.state.keyPlots.first { $0.keyCode == 1 }?.progress == 0)
    precondition(engine.todayStats(now: date).keyboardCount == 5)
    precondition(engine.state.keyPlots.count == KeyboardLayout.allKeys.count)
}

private func testPlantUnlockHarvestAndAutoHarvestBehaviorsStayStable() {
    var state = GameState.defaultState()
    state.coins = 50
    var engine = FarmEngine(state: state)

    precondition(engine.unlockCrop(id: "tomato"))
    precondition(engine.selectCrop(id: "tomato"))
    precondition(engine.plant(cropID: "tomato", in: "kc_0"))
    precondition(engine.state.coins == 0)
    precondition(engine.state.selectedCropID == "tomato")
    precondition(engine.state.keyPlots.first { $0.keyID == "kc_0" }?.cropID == "tomato")

    engine.apply(InputEvent(kind: .keyboard, count: 45, keyCode: 0, keyLabel: "A"))

    let result = engine.autoHarvestMaturePlot()

    precondition(result?.keyID == "kc_0")
    precondition(result?.cropID == "tomato")
    precondition(result?.coins == 18)
    precondition(engine.state.coins == 18)
    precondition(engine.state.keyPlots.first { $0.keyID == "kc_0" }?.progress == 0)
    precondition(engine.state.keyPlots.first { $0.keyID == "kc_0" }?.cropID == "tomato")
}

private func testMatureHarvestCandidateDoesNotMutateState() {
    var state = GameState.defaultState()
    guard let index = state.keyPlots.firstIndex(where: { $0.keyCode == 0 }) else {
        preconditionFailure("Expected default keyboard plot for A.")
    }
    state.keyPlots[index].progress = 24
    let engine = FarmEngine(state: state)

    let candidate = engine.firstMatureHarvestCandidate()

    precondition(candidate?.keyID == state.keyPlots[index].keyID)
    precondition(candidate?.coins == 8)
    precondition(engine.state.coins == 0)
    precondition(engine.state.keyPlots[index].progress == 24)
}

private func testMatureHarvestCandidateCanExcludePendingKeys() {
    var state = GameState.defaultState()
    guard let firstIndex = state.keyPlots.firstIndex(where: { $0.keyCode == 0 }),
          let secondIndex = state.keyPlots.firstIndex(where: { $0.keyCode == 1 }) else {
        preconditionFailure("Expected default keyboard plots for A and S.")
    }
    state.keyPlots[firstIndex].progress = 24
    state.keyPlots[secondIndex].progress = 24
    let engine = FarmEngine(state: state)
    let firstKeyID = state.keyPlots[firstIndex].keyID

    let candidate = engine.firstMatureHarvestCandidate(excluding: [firstKeyID])

    precondition(candidate?.keyID == state.keyPlots[secondIndex].keyID)
}

private func testAdoptPetSpendsCoinsAndAllowsRepeats() {
    var state = GameState.defaultState()
    state.coins = 400
    var engine = FarmEngine(state: state)

    precondition(engine.adoptPet(definitionID: "cat", adoptedAt: Date(timeIntervalSince1970: 10)))
    precondition(engine.adoptPet(definitionID: "cat", adoptedAt: Date(timeIntervalSince1970: 20)))
    precondition(engine.state.adoptedPets.map(\.definitionID) == ["dog", "cat", "cat"])
    precondition(engine.state.coins == 120)

    do {
        let data = try JSONEncoder().encode(engine.state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        precondition(decoded.adoptedPets.map(\.definitionID) == ["dog", "cat", "cat"])
    } catch {
        preconditionFailure("Adopted pets should round trip: \(error)")
    }
}

private func testAdoptPetFailsWithoutEnoughCoins() {
    var engine = FarmEngine(state: .defaultState())

    precondition(!engine.adoptPet(definitionID: "cat"))
    precondition(engine.state.adoptedPets.map(\.definitionID) == ["dog"])
}

private func testPomodoroSettingsClampAndRoundTripThroughGameState() {
    let state = GameState(pomodoroSettings: PomodoroSettings(durationMinutes: 240))

    precondition(state.pomodoroSettings.durationMinutes == 180)

    do {
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        precondition(decoded.pomodoroSettings.durationMinutes == 180)
    } catch {
        preconditionFailure("GameState pomodoro settings should round trip: \(error)")
    }
}
