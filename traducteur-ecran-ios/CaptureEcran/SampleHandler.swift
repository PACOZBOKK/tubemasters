import CoreMedia
import ReplayKit
import Vision

/// Extension « Diffusion de l'écran » : reçoit les images de tout l'écran,
/// lit le texte japonais avec Vision et l'envoie à l'application.
/// Une extension de diffusion est limitée à ~50 Mo de mémoire : on analyse
/// au plus une image à la fois, et seulement toutes les `intervalle` secondes.
final class SampleHandler: RPBroadcastSampleHandler {
    private let intervalle: TimeInterval = 0.8
    private let file = DispatchQueue(label: "ocr", qos: .userInitiated)
    private let verrou = NSLock()
    private var occupe = false
    private var dernierPassage = Date.distantPast
    private var derniersBlocs: [String] = []

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        Partage.ecrire(TexteDetecte(blocs: [], captureActive: true, date: Date()))
    }

    override func broadcastFinished() {
        Partage.ecrire(TexteDetecte(blocs: [], captureActive: false, date: Date()))
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with type: RPSampleBufferType) {
        guard type == .video else { return }

        verrou.lock()
        let maintenant = Date()
        guard !occupe, maintenant.timeIntervalSince(dernierPassage) >= intervalle,
              let image = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            verrou.unlock()
            return
        }
        occupe = true
        dernierPassage = maintenant
        verrou.unlock()

        let orientation = Self.orientation(de: sampleBuffer)
        file.async { [weak self] in
            guard let self else { return }
            autoreleasepool { self.analyser(image, orientation: orientation) }
            self.verrou.lock()
            self.occupe = false
            self.verrou.unlock()
        }
    }

    // MARK: - Lecture du texte

    private struct Ligne {
        var texte: String
        var cadre: CGRect // coordonnées Vision : 0…1, origine en bas à gauche
    }

    private func analyser(_ image: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let requete = VNRecognizeTextRequest()
        requete.recognitionLevel = .accurate
        requete.recognitionLanguages = ["ja-JP"]
        requete.usesLanguageCorrection = true
        requete.minimumTextHeight = 0.01

        let analyseur = VNImageRequestHandler(cvPixelBuffer: image, orientation: orientation, options: [:])
        do { try analyseur.perform([requete]) } catch { return }

        let lignes: [Ligne] = (requete.results ?? []).compactMap { observation in
            guard let candidat = observation.topCandidates(1).first, candidat.confidence >= 0.4 else { return nil }
            let texte = candidat.string.trimmingCharacters(in: .whitespacesAndNewlines)
            // On ne garde que le japonais : l'heure, les icônes et notre propre
            // fenêtre (en français) sont ainsi ignorées.
            guard Self.contientJaponais(texte) else { return nil }
            return Ligne(texte: texte, cadre: observation.boundingBox)
        }

        let blocs = Array(Self.regrouper(lignes).prefix(40))
        guard blocs != derniersBlocs else { return }
        derniersBlocs = blocs
        Partage.ecrire(TexteDetecte(blocs: blocs, captureActive: true, date: Date()))
    }

    /// Regroupe les lignes proches en paragraphes pour une traduction plus naturelle.
    private static func regrouper(_ lignes: [Ligne]) -> [String] {
        let triees = lignes.sorted { $0.cadre.maxY > $1.cadre.maxY } // du haut vers le bas
        var blocs: [String] = []
        var precedente: Ligne?

        for ligne in triees {
            if let p = precedente, var dernier = blocs.popLast() {
                let ecart = p.cadre.minY - ligne.cadre.maxY
                let memeColonne = abs(p.cadre.minX - ligne.cadre.minX) < 0.12
                if memeColonne && ecart >= -p.cadre.height * 0.3 && ecart < p.cadre.height * 0.9 {
                    dernier += ligne.texte // le japonais s'écrit sans espaces
                    blocs.append(dernier)
                } else {
                    blocs.append(dernier)
                    blocs.append(ligne.texte)
                }
            } else {
                blocs.append(ligne.texte)
            }
            precedente = ligne
        }
        return blocs
    }

    private static func contientJaponais(_ texte: String) -> Bool {
        texte.unicodeScalars.contains { s in
            (0x3040...0x30FF).contains(s.value)    // hiragana, katakana
                || (0x4E00...0x9FFF).contains(s.value) // kanji
                || (0xFF00...0xFFEF).contains(s.value) // pleine chasse
        }
    }

    private static func orientation(de sampleBuffer: CMSampleBuffer) -> CGImagePropertyOrientation {
        guard let valeur = CMGetAttachment(sampleBuffer,
                                           key: RPVideoSampleOrientationKey as CFString,
                                           attachmentModeOut: nil) as? NSNumber,
              let orientation = CGImagePropertyOrientation(rawValue: valeur.uint32Value) else {
            return .up
        }
        return orientation
    }
}
