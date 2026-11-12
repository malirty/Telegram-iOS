import Foundation

public enum FlexGramLocalSettings {
    private static let defaults = UserDefaults.standard

    public static var profileDisplayNameOverride: String? {
        get { Self.nonEmptyValue(forKey: "flexgram.profileDisplayName") }
        set { Self.store(newValue, forKey: "flexgram.profileDisplayName") }
    }

    public static var outgoingAuthorNameOverride: String? {
        get { Self.nonEmptyValue(forKey: "flexgram.outgoingAuthorName") }
        set { Self.store(newValue, forKey: "flexgram.outgoingAuthorName") }
    }

    private static func nonEmptyValue(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private static func store(_ value: String?, forKey key: String) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            defaults.set(String(trimmed.prefix(64)), forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
