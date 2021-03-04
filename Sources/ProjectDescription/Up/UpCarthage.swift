import Foundation

/// Up that updates Carthage dependencies that need to be updated
class UpCarthage: Up {
    /// The platforms Carthage dependencies should be updated for.
    let platforms: [Platform]

    /// Indicates whether Carthage produces XCFrameworks or regular frameworks.
    let useXCFrameworks: Bool
    
    /// Indicates whether Carthage rebuilds the dependency from source instead of using downloaded binaries when possible.
    let noUseBinaries: Bool

    /// Initializes the Carthage up.
    ///
    /// - Parameter platforms: The platforms Carthage dependencies should be updated for.
    /// - Parameter useXCFrameworks: Indicates whether Carthage produces XCFrameworks or regular frameworks.
    /// - Parameter noUseBinaries: Indicates whether Carthage rebuilds the dependency from source instead of using downloaded binaries when possible.
    init(platforms: [Platform], useXCFrameworks: Bool, noUseBinaries: Bool) {
        self.platforms = platforms
        self.useXCFrameworks = useXCFrameworks
        self.noUseBinaries = noUseBinaries
        super.init()
    }

    public enum CodingKeys: String, CodingKey {
        case type
        case platforms
        case useXCFrameworks
        case noUseBinaries
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        platforms = try container.decode([Platform].self, forKey: .platforms)
        useXCFrameworks = try container.decode(Bool.self, forKey: .useXCFrameworks)
        noUseBinaries = try container.decode(Bool.self, forKey: .noUseBinaries)
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("carthage", forKey: .type)
        try container.encode(platforms, forKey: .platforms)
        try container.encode(useXCFrameworks, forKey: .useXCFrameworks)
        try container.encode(noUseBinaries, forKey: .noUseBinaries)
    }

    override func equals(_ other: Up) -> Bool {
        guard let otherUpCarthage = other as? UpCarthage else { return false }
        return
            platforms == otherUpCarthage.platforms &&
            useXCFrameworks == otherUpCarthage.useXCFrameworks
    }
}
