import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Fenêtre flottante (Picture in Picture) qui reste par-dessus les autres applis.
/// On y « joue » une vidéo d'une seule image : le texte japonais dessiné.
@MainActor
final class FenetreFlottante: NSObject {
    let calque = AVSampleBufferDisplayLayer()
    private var controleur: AVPictureInPictureController?
    private var imageActuelle: UIImage?
    private var minuterie: Timer?
    var surChangement: ((Bool) -> Void)?

    static let taille = CGSize(width: 1080, height: 720)

    override init() {
        super.init()
        calque.videoGravity = .resizeAspect

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let source = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: calque, playbackDelegate: self)
        let controleur = AVPictureInPictureController(contentSource: source)
        controleur.delegate = self
        controleur.canStartPictureInPictureAutomaticallyFromInline = true
        controleur.requiresLinearPlayback = true
        self.controleur = controleur

        // Ré-affiche régulièrement l'image pour que la fenêtre ne se vide jamais.
        minuterie = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.envoyerImageActuelle() }
        }
    }

    var estSupportee: Bool { controleur != nil }
    var estActive: Bool { controleur?.isPictureInPictureActive ?? false }

    func afficher(_ image: UIImage) {
        imageActuelle = image
        envoyerImageActuelle()
    }

    func basculer() {
        guard let controleur else { return }
        if controleur.isPictureInPictureActive {
            controleur.stopPictureInPicture()
        } else {
            envoyerImageActuelle()
            controleur.startPictureInPicture()
        }
    }

    private func envoyerImageActuelle() {
        guard let image = imageActuelle, let echantillon = Self.echantillon(depuis: image) else { return }
        let rendu = calque.sampleBufferRenderer
        if rendu.status == .failed { rendu.flush() }
        rendu.enqueue(echantillon)
    }

    /// Convertit une image en échantillon vidéo affichable immédiatement.
    private static func echantillon(depuis image: UIImage) -> CMSampleBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        let largeur = cgImage.width, hauteur = cgImage.height

        var tampon: CVPixelBuffer?
        let attributs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
        ]
        guard CVPixelBufferCreate(kCFAllocatorDefault, largeur, hauteur, kCVPixelFormatType_32BGRA,
                                  attributs as CFDictionary, &tampon) == kCVReturnSuccess,
              let tampon else { return nil }

        CVPixelBufferLockBaseAddress(tampon, [])
        let contexte = CGContext(
            data: CVPixelBufferGetBaseAddress(tampon), width: largeur, height: hauteur,
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(tampon),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        contexte?.draw(cgImage, in: CGRect(x: 0, y: 0, width: largeur, height: hauteur))
        CVPixelBufferUnlockBaseAddress(tampon, [])

        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: tampon,
                                                           formatDescriptionOut: &format) == noErr,
              let format else { return nil }

        var horaire = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )
        var echantillon: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: tampon,
                                                       formatDescription: format, sampleTiming: &horaire,
                                                       sampleBufferOut: &echantillon) == noErr,
              let echantillon else { return nil }

        if let pieces = CMSampleBufferGetSampleAttachmentsArray(echantillon, createIfNecessary: true),
           CFArrayGetCount(pieces) > 0 {
            let dico = unsafeBitCast(CFArrayGetValueAtIndex(pieces, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dico,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return echantillon
    }
}

extension FenetreFlottante: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ c: AVPictureInPictureController) {
        Task { @MainActor in self.surChangement?(true) }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ c: AVPictureInPictureController) {
        Task { @MainActor in self.surChangement?(false) }
    }
}

extension FenetreFlottante: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController, setPlaying playing: Bool) {}

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ c: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity) // flux « en direct »
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ c: AVPictureInPictureController) -> Bool {
        false
    }

    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController,
                                                didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    nonisolated func pictureInPictureController(_ c: AVPictureInPictureController,
                                                skipByInterval skipInterval: CMTime,
                                                completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

/// Vue SwiftUI qui contient le calque vidéo (obligatoire pour lancer le PiP).
struct ApercuFenetre: UIViewRepresentable {
    let fenetre: FenetreFlottante

    final class Vue: UIView {
        var calque: CALayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                if let calque { layer.addSublayer(calque) }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            calque?.frame = bounds
        }
    }

    func makeUIView(context: Context) -> Vue {
        let vue = Vue()
        vue.backgroundColor = .black
        vue.calque = fenetre.calque
        return vue
    }

    func updateUIView(_ vue: Vue, context: Context) {}
}

/// Dessine les traductions dans une image pour la fenêtre flottante.
enum Dessin {
    static func image(paires: [(fr: String, ja: String)], afficherFrancais: Bool, captureActive: Bool) -> UIImage {
        let taille = FenetreFlottante.taille
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: taille, format: format).image { ctx in
            UIColor(white: 0.07, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: taille))

            let marge: CGFloat = 36
            let largeur = taille.width - marge * 2

            guard !paires.isEmpty else {
                let message = captureActive ? "フランス語のテキストを待っています…\nEn attente de texte français…"
                                            : "Lance la capture d'écran dans l'appli\nキャプチャを開始してください"
                let attributs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 40, weight: .semibold),
                    .foregroundColor: UIColor(white: 0.75, alpha: 1),
                ]
                (message as NSString).draw(with: CGRect(x: marge, y: marge, width: largeur, height: taille.height),
                                           options: .usesLineFragmentOrigin, attributes: attributs, context: nil)
                return
            }

            // On réduit la police jusqu'à ce que tout tienne (ou au minimum lisible).
            var corps: CGFloat = 46
            var blocs = construire(paires, corps: corps, afficherFrancais: afficherFrancais)
            while corps > 24 && hauteurTotale(blocs, largeur: largeur) > taille.height - marge * 2 {
                corps -= 3
                blocs = construire(paires, corps: corps, afficherFrancais: afficherFrancais)
            }

            var y = marge
            for bloc in blocs {
                let h = ceil(bloc.boundingRect(with: CGSize(width: largeur, height: .greatestFiniteMagnitude),
                                               options: .usesLineFragmentOrigin, context: nil).height)
                if y + h > taille.height - marge / 2 { break }
                bloc.draw(with: CGRect(x: marge, y: y, width: largeur, height: h),
                          options: .usesLineFragmentOrigin, context: nil)
                y += h + corps * 0.5
            }
        }
    }

    private static func construire(_ paires: [(fr: String, ja: String)], corps: CGFloat,
                                   afficherFrancais: Bool) -> [NSAttributedString] {
        paires.map { paire in
            let texte = NSMutableAttributedString()
            if afficherFrancais {
                texte.append(NSAttributedString(string: paire.fr + "\n", attributes: [
                    .font: UIFont.systemFont(ofSize: corps * 0.55),
                    .foregroundColor: UIColor(white: 0.6, alpha: 1),
                ]))
            }
            texte.append(NSAttributedString(string: paire.ja, attributes: [
                .font: UIFont.systemFont(ofSize: corps, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]))
            return texte
        }
    }

    private static func hauteurTotale(_ blocs: [NSAttributedString], largeur: CGFloat) -> CGFloat {
        blocs.reduce(0) { total, bloc in
            total + ceil(bloc.boundingRect(with: CGSize(width: largeur, height: .greatestFiniteMagnitude),
                                           options: .usesLineFragmentOrigin, context: nil).height) + 20
        }
    }
}
