import Foundation
import WatchConnectivity
import WelloKit

/// Pont WatchConnectivity côté Watch : reçoit le mirroir d'état (`applicationContext`) et envoie
/// les prises (`transferUserInfo`, file à livraison garantie même iPhone injoignable).
///
/// `@unchecked Sendable` : `WCSession` est thread-safe ; l'unique état mutable (`onSnapshot`) est
/// fixé une fois au démarrage.
final class WatchConnectivityClient: NSObject, @unchecked Sendable {
    /// Branché par le `WatchStore` : appelé à chaque snapshot reçu de l'iPhone.
    var onSnapshot: (@Sendable (WatchSyncSnapshot) -> Void)?

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

    /// Envoie une prise à l'iPhone (mise en file si injoignable).
    func envoyer(_ prise: PriseWatch) {
        session?.transferUserInfo(prise.dictionnaire())
    }
}

extension WatchConnectivityClient: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        // Au démarrage, l'iPhone a peut-être déjà déposé un applicationContext : le consommer.
        let ctx = session.receivedApplicationContext
        if let snap = WatchSyncSnapshot(dictionnaire: ctx) { onSnapshot?(snap) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        if let snap = WatchSyncSnapshot(dictionnaire: context) { onSnapshot?(snap) }
    }
}
