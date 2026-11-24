import Foundation

/// Ce que l'extension de capture a lu à l'écran.
struct TexteDetecte: Codable, Equatable {
    var blocs: [String]
    var captureActive: Bool
    var date: Date
}

/// Échange de données entre l'extension de capture et l'application,
/// via le conteneur partagé (App Group) et une notification Darwin.
enum Partage {
    static let nomNotification = "traducteurecran.nouveau-texte" as CFString

    static var groupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""
    }

    static var fichier: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("texte-detecte.json")
    }

    static func ecrire(_ texte: TexteDetecte) {
        guard let fichier, let donnees = try? JSONEncoder().encode(texte) else { return }
        try? donnees.write(to: fichier, options: .atomic)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(nomNotification), nil, nil, true
        )
    }

    static func lire() -> TexteDetecte? {
        guard let fichier, let donnees = try? Data(contentsOf: fichier) else { return nil }
        return try? JSONDecoder().decode(TexteDetecte.self, from: donnees)
    }
}
