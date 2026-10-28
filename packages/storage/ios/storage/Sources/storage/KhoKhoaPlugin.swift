import Flutter
import Foundation
import Security

/// Khoá CSDL (SEC-APP-STORAGE): 32 byte ngẫu nhiên giữ trong Keychain với
/// `AfterFirstUnlockThisDeviceOnly` - không đồng bộ iCloud, không theo bản sao
/// lưu sang máy khác. Thư mục dữ liệu nằm trong Application Support, gắn cờ
/// loại khỏi backup.
public class KhoKhoaPlugin: NSObject, FlutterPlugin {
  private static let dichVu = "com.tsudev.laban.csdl"
  private static let taiKhoan = "khoa_csdl_v1"
  private static let doDaiKhoa = 32
  private let hang = DispatchQueue(label: "la_ban.luu_tru")

  public static func register(with registrar: FlutterPluginRegistrar) {
    let kenh = FlutterMethodChannel(name: "la_ban/luu_tru", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(KhoKhoaPlugin(), channel: kenh)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "layKhoaCsdl":
      hang.async {
        let kq: Any
        do {
          kq = FlutterStandardTypedData(bytes: try Self.layKhoaCsdl())
        } catch {
          kq = FlutterError(code: "khoa.loi", message: String(describing: type(of: error)), details: nil)
        }
        DispatchQueue.main.async { result(kq) }
      }
    case "thuMucDuLieu":
      do {
        result(try Self.thuMucDuLieu())
      } catch {
        result(FlutterError(code: "thuMuc.loi", message: nil, details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private enum Loi: Error {
    case keychain(OSStatus)
    case ngauNhien
  }

  private static func layKhoaCsdl() throws -> Data {
    let tim: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: dichVu,
      kSecAttrAccount as String: taiKhoan,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var ra: CFTypeRef?
    let tt = SecItemCopyMatching(tim as CFDictionary, &ra)
    if tt == errSecSuccess, let du = ra as? Data, du.count == doDaiKhoa {
      return du
    }
    if tt != errSecItemNotFound && tt != errSecSuccess {
      throw Loi.keychain(tt)
    }
    // Chưa có (hoặc hỏng): sinh mới. Keychain còn sau khi gỡ app trên iOS,
    // nhưng CSDL cũ đã mất cùng app nên dùng lại khoá cũng vô hại.
    var khoa = Data(count: doDaiKhoa)
    let sinh = khoa.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, doDaiKhoa, $0.baseAddress!)
    }
    guard sinh == errSecSuccess else { throw Loi.ngauNhien }
    SecItemDelete([
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: dichVu,
      kSecAttrAccount as String: taiKhoan,
    ] as CFDictionary)
    let them: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: dichVu,
      kSecAttrAccount as String: taiKhoan,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecAttrSynchronizable as String: false,
      kSecValueData as String: khoa,
    ]
    let ghi = SecItemAdd(them as CFDictionary, nil)
    guard ghi == errSecSuccess else { throw Loi.keychain(ghi) }
    return khoa
  }

  private static func thuMucDuLieu() throws -> String {
    var url = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
    ).appendingPathComponent("la_ban", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    var gt = URLResourceValues()
    gt.isExcludedFromBackup = true
    try url.setResourceValues(gt)
    return url.path
  }
}
