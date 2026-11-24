import Foundation
import Observation
import UIKit

/// Cœur de l'appli : reçoit le texte lu par l'extension, le traduit,
/// et met à jour la fenêtre flottante.
@MainActor
@Observable
final class Modele {
    enum EtatLangues { case verification, installees, aTelecharger }

    private(set) var paires: [(fr: String, ja: String)] = []
    private(set) var captureActive = false
    private(set) var fenetreActive = false
    private(set) var etatLangues: EtatLangues = .verification
    private(set) var erreur: String?
    var afficherFrancais = true {
        didSet { redessiner() }
    }

    @ObservationIgnored let fenetre = FenetreFlottante()
    @ObservationIgnored private let traducteur = Traducteur()
    @ObservationIgnored private var derniersBlocs: [String] = []
    @ObservationIgnored private var traductionEnCours = false
    @ObservationIgnored private var aRelire = false

    init() {
        fenetre.surChangement = { [weak self] active in self?.fenetreActive = active }
        ecouterExtension()
        redessiner()
        Task { await verifierLangues() }
        recharger()
    }

    func verifierLangues() async {
        etatLangues = await Traducteur.languesInstallees() ? .installees : .aTelecharger
        if etatLangues == .installees {
            traducteur.reinitialiser()
            derniersBlocs = []
            recharger()
        }
    }

    func signalerErreur(_ message: String?) {
        erreur = message
    }

    // MARK: - Réception du texte

    private func ecouterExtension() {
        let observateur = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), observateur,
            { _, observateur, _, _, _ in
                guard let observateur else { return }
                let modele = Unmanaged<Modele>.fromOpaque(observateur).takeUnretainedValue()
                Task { @MainActor in modele.recharger() }
            },
            Partage.nomNotification, nil, .deliverImmediately
        )
    }

    func recharger() {
        // Une seule traduction à la fois ; on relira le fichier à la fin.
        guard !traductionEnCours else { aRelire = true; return }
        guard let texte = Partage.lire() else { return }

        captureActive = texte.captureActive
        guard texte.blocs != derniersBlocs else { redessiner(); return }
        derniersBlocs = texte.blocs

        guard !texte.blocs.isEmpty else {
            paires = []
            redessiner()
            return
        }
        guard etatLangues == .installees else {
            erreur = "Télécharge d'abord le français et le japonais (étape 1)."
            return
        }

        traductionEnCours = true
        Task {
            defer {
                traductionEnCours = false
                if aRelire { aRelire = false; recharger() }
            }
            do {
                let japonais = try await traducteur.traduire(texte.blocs)
                paires = Array(zip(texte.blocs, japonais)).map { (fr: $0.0, ja: $0.1) }
                erreur = nil
                redessiner()
            } catch {
                self.erreur = "Traduction impossible : \(error.localizedDescription)"
                traducteur.reinitialiser()
            }
        }
    }

    private func redessiner() {
        fenetre.afficher(Dessin.image(paires: paires, afficherFrancais: afficherFrancais,
                                      captureActive: captureActive))
    }
}
