// WidgetKit integration for widget timeline reload
#if canImport(WidgetKit)
import WidgetKit
#endif
import Foundation
import Dispatch
import React

@objc(FavoritesBridge)
final class FavoritesBridge: NSObject, RCTBridgeModule {
  @objc static func moduleName() -> String! { "FavoritesBridge" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  private let queue = DispatchQueue(label: "FavoritesBridge.queue", qos: .utility)

  @objc(saveFavorites:resolver:rejecter:)
  func saveFavorites(_ dtosJson: String,
                     resolver resolve: @escaping RCTPromiseResolveBlock,
                     rejecter reject: @escaping RCTPromiseRejectBlock) {
    queue.async {
      do {
        guard let data = dtosJson.data(using: .utf8) else {
          reject("INVALID_JSON", "Failed to encode JSON string", nil); return
        }
        if data.isEmpty {
          reject("EMPTY_PAYLOAD", "Favorites payload was an empty string", nil); return
        }
        NSLog("🧩 FavoritesBridge.saveFavorites bytes=%ld", data.count)

        // Decode RN payload to DTOs (tolerant to `type`/`kind`), then normalize by re-encoding.
        let dtos = try JSONDecoder().decode([FavoriteDTO].self, from: data)
        let normalized = try JSONEncoder().encode(dtos) // FavoriteStopDTO encodes `kind`

        // Decode normalized JSON into domain model
        let favorites = try JSONDecoder().decode([Favorite].self, from: normalized)

        // Persist + refresh widget
        Task { @MainActor in
          FavoritesStore.shared.replaceAll(with: favorites)
          #if canImport(WidgetKit)
          WidgetCenter.shared.reloadTimelines(ofKind: "ctaTimes")
          #endif
          resolve(NSNull())
        }
      } catch {
        // Extra diagnostics to help JS-side debugging
        if let json = try? JSONSerialization.jsonObject(with: dtosJson.data(using: .utf8) ?? Data()) as? [Any] {
          NSLog("🧩 FavoritesBridge.saveFavorites JSON array count=%ld", json.count)
        }
        reject("SAVE_ERROR", "Failed to save favorites: \(error.localizedDescription)", error)
      }
    }
  }
}
