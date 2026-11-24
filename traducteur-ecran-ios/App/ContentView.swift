import ReplayKit
import SwiftUI
import Translation

struct ContentView: View {
    @Environment(Modele.self) private var modele
    @State private var telechargement: TranslationSession.Configuration?

    var body: some View {
        @Bindable var modele = modele

        NavigationStack {
            List {
                Section {
                    switch modele.etatLangues {
                    case .verification:
                        Label("Vérification…", systemImage: "hourglass")
                    case .installees:
                        Label("Français et japonais installés", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .aTelecharger:
                        Button {
                            telechargement = .init(source: Traducteur.source, target: Traducteur.cible)
                        } label: {
                            Label("Télécharger français + japonais", systemImage: "arrow.down.circle")
                        }
                    }
                } header: {
                    Text("1. Langues (hors ligne)")
                }

                Section {
                    ApercuFenetre(fenetre: modele.fenetre)
                        .aspectRatio(FenetreFlottante.taille.width / FenetreFlottante.taille.height,
                                     contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))

                    Button {
                        modele.fenetre.basculer()
                    } label: {
                        Label(modele.fenetreActive ? "Fermer la fenêtre flottante" : "Ouvrir la fenêtre flottante",
                              systemImage: "pip")
                    }
                    .disabled(!modele.fenetre.estSupportee)

                    Toggle("Afficher aussi le français", isOn: $modele.afficherFrancais)
                } header: {
                    Text("2. Fenêtre flottante")
                } footer: {
                    Text("Elle reste par-dessus les autres applis. Tu peux la déplacer, l'agrandir en pinçant, ou la cacher sur le bord.")
                }

                Section {
                    HStack(spacing: 16) {
                        BoutonCapture()
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(modele.captureActive ? Color.red : Color.accentColor))
                        VStack(alignment: .leading) {
                            Text(modele.captureActive ? "Capture en cours" : "Démarrer la capture")
                                .font(.headline)
                            Text("Touche le rond, choisis « Traducteur FR→JA » puis « Commencer la diffusion ».")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("3. Capture de l'écran")
                }

                if let erreur = modele.erreur {
                    Section {
                        Label(erreur, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }

                if !modele.paires.isEmpty {
                    Section("Dernières traductions") {
                        ForEach(Array(modele.paires.enumerated()), id: \.offset) { _, paire in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(paire.ja).font(.body.weight(.semibold))
                                Text(paire.fr).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Écran FR → JA")
        }
        .translationTask(telechargement) { session in
            do {
                try await session.prepareTranslation()
                modele.signalerErreur(nil)
            } catch {
                modele.signalerErreur("Téléchargement interrompu : \(error.localizedDescription)")
            }
            await modele.verifierLangues()
            telechargement = nil
        }
    }
}

/// Bouton système qui ouvre le choix « Diffusion de l'écran » sur notre extension.
struct BoutonCapture: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let vue = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 52, height: 52))
        vue.preferredExtension = (Bundle.main.bundleIdentifier ?? "") + ".broadcast"
        vue.showsMicrophoneButton = false
        for case let bouton as UIButton in vue.subviews {
            bouton.imageView?.tintColor = .white
        }
        return vue
    }

    func updateUIView(_ vue: RPSystemBroadcastPickerView, context: Context) {}
}
