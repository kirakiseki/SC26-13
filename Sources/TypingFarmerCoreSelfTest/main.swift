import Foundation
import TypingFarmerCore

testDefaultStateIncludesOneDog()
testKeyInputAdvancesOnlyMatchingPlot()
testUnmappedKeyOnlyUpdatesStats()
testHarvestMatureKeyAddsCoinsAndResetsPlot()
testMatureHarvestCandidateDoesNotMutateState()
testMatureHarvestCandidateCanExcludePendingKeys()
testAdoptPetSpendsCoinsAndAllowsRepeats()
testLegacyGameStateMigratesDefaultDog()
testCannotUnlockCropWithoutEnoughCoins()
testUnlockCropSpendsCoins()
testDailyStatsStaySeparatedByDate()
testGameStateEncodingOmitsWindowSettings()
testPomodoroStartPauseAndReset()
testPomodoroCompletesOneSessionAndStops()
testChangingDurationClampsAndResets()

print("TypingFarmerCoreSelfTest passed")

private func testDefaultStateIncludesOneDog() {
    let state = GameState.defaultState()

    precondition(state.adoptedPets.count == 1)
    precondition(state.adoptedPets.first?.definitionID == "dog")
}

private func testKeyInputAdvancesOnlyMatchingPlot() {
    var engine = FarmEngine(state: .defaultState())
    let date = Date(timeIntervalSince1970: 1_735_689_600)
    let aCode = 0
    let sCode = 1

    engine.apply(InputEvent(kind: .keyboard, timestamp: date, count: 5, keyCode: aCode, keyLabel: "A"))

    let aPlot = engine.state.keyPlots.first { $0.keyCode == aCode }
    let sPlot = engine.state.keyPlots.first { $0.keyCode == sCode }
    precondition(aPlot?.progress == 5)
    precondition(sPlot?.progress == 0)
    precondition(aPlot?.lastHitAt == date)
    precondition(engine.todayStats(now: date).keyboardCount == 5)
}

private func testUnmappedKeyOnlyUpdatesStats() {
    var engine = FarmEngine(state: .defaultState())
    let originalPlots = engine.state.keyPlots
    let date = Date(timeIntervalSince1970: 1_735_689_600)

    engine.apply(InputEvent(kind: .keyboard, timestamp: date, count: 3, keyCode: 999, keyLabel: nil))

    precondition(engine.state.keyPlots == originalPlots)
    precondition(engine.todayStats(now: date).keyboardCount == 3)
}

private func testHarvestMatureKeyAddsCoinsAndResetsPlot() {
    var state = GameState.defaultState()
    guard let index = state.keyPlots.firstIndex(where: { $0.keyCode == 0 }) else {
        preconditionFailure("Default keyboard must include A.")
    }
    let keyID = state.keyPlots[index].keyID
    state.keyPlots[index].progress = 24
    var engine = FarmEngine(state: state)

    let earned = engine.harvest(keyID: keyID)

    precondition(earned == 8)
    precondition(engine.state.coins == 8)
    precondition(engine.state.keyPlots[index].progress == 0)
}

private func testMatureHarvestCandidateDoesNotMutateState() {
    var state = GameState.defaultState()
    guard let index = state.keyPlots.firstIndex(where: { $0.keyCode == 0 }) else {
        preconditionFailure("Default keyboard must include A.")
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
        preconditionFailure("Default keyboard must include A and S.")
    }
    state.keyPlots[firstIndex].progress = 24
    state.keyPlots[secondIndex].progress = 24
    let engine = FarmEngine(state: state)

    let candidate = engine.firstMatureHarvestCandidate(excluding: [state.keyPlots[firstIndex].keyID])

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
        precondition(decoded.adoptedPets.map(\.definitionID) == ["dog"])
    } catch {
        preconditionFailure("Legacy GameState should migrate default dog: \(error)")
    }
}

private func testCannotUnlockCropWithoutEnoughCoins() {
    var engine = FarmEngine(state: .defaultState())

    let unlocked = engine.unlockCrop(id: "tomato")

    precondition(!unlocked)
    precondition(!engine.state.unlockedCropIDs.contains("tomato"))
}

private func testUnlockCropSpendsCoins() {
    var state = GameState.defaultState()
    state.coins = 50
    var engine = FarmEngine(state: state)

    let unlocked = engine.unlockCrop(id: "tomato")

    precondition(unlocked)
    precondition(engine.state.unlockedCropIDs.contains("tomato"))
    precondition(engine.state.coins == 0)
}

private func testDailyStatsStaySeparatedByDate() {
    var engine = FarmEngine(state: .defaultState())
    let dayOne = Date(timeIntervalSince1970: 1_735_689_600)
    let dayTwo = Date(timeIntervalSince1970: 1_735_776_000)

    engine.apply(InputEvent(kind: .keyboard, timestamp: dayOne, count: 3, keyCode: 0, keyLabel: "A"))
    engine.apply(InputEvent(kind: .mouse, timestamp: dayTwo, count: 4))

    precondition(engine.todayStats(now: dayOne).keyboardCount == 3)
    precondition(engine.todayStats(now: dayOne).mouseCount == 0)
    precondition(engine.todayStats(now: dayTwo).keyboardCount == 0)
    precondition(engine.todayStats(now: dayTwo).mouseCount == 4)
}

private func testGameStateEncodingOmitsWindowSettings() {
    do {
        let data = try JSONEncoder().encode(GameState.defaultState())
        let json = String(decoding: data, as: UTF8.self)
        precondition(!json.contains("windowSettings"))
    } catch {
        preconditionFailure("GameState should encode without app window settings: \(error)")
    }
}

private func testPomodoroStartPauseAndReset() {
    var timer = PomodoroTimerModel(settings: PomodoroSettings(durationMinutes: 1))

    timer.start()
    precondition(timer.isRunning)

    timer.pause()
    precondition(!timer.isRunning)

    timer.reset()
    precondition(timer.remainingSeconds == 60)
}

private func testPomodoroCompletesOneSessionAndStops() {
    var timer = PomodoroTimerModel(settings: PomodoroSettings(durationMinutes: 1))

    timer.start()
    let completed = timer.advance(seconds: 60)

    precondition(completed == 1)
    precondition(!timer.isRunning)
    precondition(timer.remainingSeconds == 60)
}

private func testChangingDurationClampsAndResets() {
    var timer = PomodoroTimerModel(settings: PomodoroSettings(durationMinutes: 25))

    timer.setDurationMinutes(0)
    precondition(timer.durationMinutes == 1)
    precondition(timer.remainingSeconds == 60)

    timer.setDurationMinutes(240)
    precondition(timer.durationMinutes == 180)
    precondition(timer.remainingSeconds == 10_800)
}
