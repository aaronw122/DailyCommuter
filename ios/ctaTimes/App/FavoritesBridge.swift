import Foundation

@objc(FavoritesBridge)
final class FavoritesBridge: NSObject, RCTBridgeModule {
  @objc static func moduleName() -> String! { "FavoritesBridge" }
  @objc static func requiresMainQueueSetup() -> Bool { false }

  private let store = SharedStore(groupID: "group.com.yourco.dailycommuter") // replace with yours
  private let queue = DispatchQueue(label: "FavoritesBridge.queue", qos: .utility)

  /// JS: NativeModules.FavoritesBridge.saveFavorites(JSON.stringify(favorites))
  @objc func saveFavorites(_ json: String,
                           resolver resolve: @escaping RCTPromiseResolveBlock,
                           rejecter reject: @escaping RCTPromiseRejectBlock) {
    queue.async {
      do {
        guard let data = json.data(using: .utf8) else {
          reject("INVALID_JSON", "Failed to encode JSON string", nil); return
        }
        let list = try JSONDecoder().decode([FavoriteDTO].self, from: data)
        try self.store.saveFavoritesDTO(list)
        resolve(nil)
      } catch {
        reject("SAVE_ERROR", "Failed to save favorites: \(error.localizedDescription)", error)
      }
    }
  }
}
