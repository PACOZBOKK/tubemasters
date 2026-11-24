import Foundation
import Translation

/// Traduction japonais → français, entièrement sur l'iPhone (framework Translation d'Apple).
@MainActor
final class Traducteur {
    static let source = Locale.Language(identifier: "ja")
    static let cible = Locale.Language(identifier: "fr")

    private var session: TranslationSession?
    private var cache: [String: String] = [:]

    static func languesInstallees() async -> Bool {
        let statut = await LanguageAvailability().status(from: source, to: cible)
        return statut == .installed
    }

    func traduire(_ textes: [String]) async throws -> [String] {
        let manquants = Array(Set(textes.filter { cache[$0] == nil }))

        if !manquants.isEmpty {
            if session == nil {
                session = try TranslationSession(installedSource: Self.source, target: Self.cible)
            }
            let requetes = manquants.enumerated().map { index, texte in
                TranslationSession.Request(sourceText: texte, clientIdentifier: String(index))
            }
            let reponses = try await session!.translations(from: requetes)

            if cache.count > 800 { cache.removeAll() }
            for reponse in reponses {
                if let id = reponse.clientIdentifier, let index = Int(id), index < manquants.count {
                    cache[manquants[index]] = reponse.targetText
                }
            }
        }
        return textes.map { cache[$0] ?? $0 }
    }

    func reinitialiser() {
        session = nil
    }
}
