import Foundation

/// Kurzform für lokalisierte Texte. Die Strings liegen in
/// Resources/<sprache>.lproj/Localizable.strings (Deutsch und Englisch).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
