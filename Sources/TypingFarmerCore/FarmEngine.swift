import Foundation

public struct FarmEngine {
    public private(set) var state: GameState
    public let cropDefinitions: [CropDefinition]
    public let petDefinitions: [PetDefinition]
    private let cropsByID: [String: CropDefinition]
    private let petsByID: [String: PetDefinition]

    public init(
        state: GameState = .defaultState(),
        cropDefinitions: [CropDefinition] = CropDefinition.defaults,
        petDefinitions: [PetDefinition] = PetDefinition.defaults
    ) {
        self.state = state
        self.cropDefinitions = cropDefinitions
        self.petDefinitions = petDefinitions
        self.cropsByID = Dictionary(uniqueKeysWithValues: cropDefinitions.map { ($0.id, $0) })
        self.petsByID = Dictionary(uniqueKeysWithValues: petDefinitions.map { ($0.id, $0) })
    }

    public mutating func apply(_ event: InputEvent, calendar: Calendar = .current) {
        guard event.count > 0 else {
            return
        }

        recordStats(for: event, calendar: calendar)

        guard event.kind == .keyboard,
              let keyCode = event.keyCode,
              let index = state.keyPlots.firstIndex(where: { $0.keyCode == keyCode }) else {
            return
        }

        let plot = state.keyPlots[index]
        guard state.unlockedCropIDs.contains(plot.cropID),
              let crop = cropsByID[plot.cropID],
              plot.progress < crop.growRequirement else {
            return
        }

        state.keyPlots[index].progress = min(crop.growRequirement, plot.progress + event.count)
        state.keyPlots[index].lastHitAt = event.timestamp
    }

    @discardableResult
    public mutating func harvest(keyID: String) -> Int? {
        guard let index = state.keyPlots.firstIndex(where: { $0.keyID == keyID }),
              let crop = cropsByID[state.keyPlots[index].cropID],
              state.keyPlots[index].progress >= crop.growRequirement else {
            return nil
        }

        state.coins += crop.sellPrice
        state.keyPlots[index].progress = 0
        state.keyPlots[index].cropID = state.selectedCropID
        return crop.sellPrice
    }

    @discardableResult
    public mutating func autoHarvestMaturePlot() -> HarvestResult? {
        guard let result = firstMatureHarvestCandidate(),
              harvest(keyID: result.keyID) != nil else {
            return nil
        }

        return result
    }

    public func firstMatureHarvestCandidate(excluding excludedKeyIDs: Set<String> = []) -> HarvestResult? {
        guard let plot = state.keyPlots.first(where: { plot in
            guard !excludedKeyIDs.contains(plot.keyID) else {
                return false
            }
            guard state.unlockedCropIDs.contains(plot.cropID),
                  let crop = cropsByID[plot.cropID] else {
                return false
            }
            return plot.progress >= crop.growRequirement
        }), let crop = cropsByID[plot.cropID] else {
            return nil
        }

        return HarvestResult(
            keyID: plot.keyID,
            keyCode: plot.keyCode,
            cropID: crop.id,
            coins: crop.sellPrice
        )
    }

    @discardableResult
    public mutating func adoptPet(definitionID: String, adoptedAt: Date = Date()) -> Bool {
        guard let pet = petsByID[definitionID],
              state.coins >= pet.adoptionPrice else {
            return false
        }

        state.coins -= pet.adoptionPrice
        state.adoptedPets.append(PetState(definitionID: definitionID, adoptedAt: adoptedAt))
        return true
    }

    @discardableResult
    public mutating func unlockCrop(id: String) -> Bool {
        guard let crop = cropsByID[id],
              !state.unlockedCropIDs.contains(id),
              state.coins >= crop.unlockPrice else {
            return false
        }

        state.coins -= crop.unlockPrice
        state.unlockedCropIDs.insert(id)
        return true
    }

    @discardableResult
    public mutating func selectCrop(id: String) -> Bool {
        guard state.unlockedCropIDs.contains(id), cropsByID[id] != nil else {
            return false
        }
        state.selectedCropID = id
        return true
    }

    @discardableResult
    public mutating func plant(cropID: String, in keyID: String) -> Bool {
        guard state.unlockedCropIDs.contains(cropID),
              cropsByID[cropID] != nil,
              let index = state.keyPlots.firstIndex(where: { $0.keyID == keyID }) else {
            return false
        }

        state.keyPlots[index].cropID = cropID
        state.keyPlots[index].progress = 0
        return true
    }

    public mutating func addTask(title: String, createdAt: Date = Date()) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        state.tasks.append(FarmTask(title: trimmed, createdAt: createdAt))
    }

    @discardableResult
    public mutating func toggleTask(id: UUID) -> Bool {
        guard let index = state.tasks.firstIndex(where: { $0.id == id }) else {
            return false
        }
        state.tasks[index].isDone.toggle()
        return true
    }

    @discardableResult
    public mutating func deleteTask(id: UUID) -> Bool {
        let originalCount = state.tasks.count
        state.tasks.removeAll { $0.id == id }
        return state.tasks.count != originalCount
    }

    public mutating func recordFocusSession(at date: Date = Date(), calendar: Calendar = .current) {
        let key = DateKey.key(for: date, calendar: calendar)
        var stats = state.dailyStats[key] ?? DailyStats(dateKey: key)
        stats.focusSessions += 1
        state.dailyStats[key] = stats
    }

    public func todayStats(now: Date = Date(), calendar: Calendar = .current) -> DailyStats {
        let key = DateKey.key(for: now, calendar: calendar)
        return state.dailyStats[key] ?? DailyStats(dateKey: key)
    }

    private mutating func recordStats(for event: InputEvent, calendar: Calendar) {
        let key = DateKey.key(for: event.timestamp, calendar: calendar)
        var stats = state.dailyStats[key] ?? DailyStats(dateKey: key)
        switch event.kind {
        case .keyboard:
            stats.keyboardCount += event.count
        case .mouse:
            stats.mouseCount += event.count
        }
        state.dailyStats[key] = stats
    }
}
