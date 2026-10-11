// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import Foundation

extension Bundle {
    var releaseVersionNumber: String? { infoDictionary?["CFBundleShortVersionString"] as? String }
    var buildVersionNumber: String? { infoDictionary?["CFBundleVersion"] as? String }
}
