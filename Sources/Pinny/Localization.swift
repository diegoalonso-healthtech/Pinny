import Foundation

/// Idioma de la interfaz. Por defecto «auto»: el idioma del Mac.
/// Las traducciones están en Resources/Localization/<código>.lproj/Localizable.strings.
enum Lang {
    /// Idiomas disponibles: código del .lproj y nombre en su propio idioma.
    static let available: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("it", "Italiano"),
        ("pt-BR", "Português (Brasil)")
    ]

    /// De dónde se leen los textos. `.main` = automático (lo decide macOS).
    static var bundle: Bundle = .main

    /// Cambia el idioma al momento, sin reiniciar la app.
    static func apply(_ code: String) {
        if code != "auto",
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let selected = Bundle(path: path) {
            bundle = selected
        } else {
            bundle = .main
        }
    }
}

/// Texto traducido. La clave es el texto en inglés; si falta la traducción, sale en inglés.
func L(_ key: String) -> String {
    Lang.bundle.localizedString(forKey: key, value: key, table: nil)
}

/// Texto traducido con valores (%@ para textos, %ld para números).
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
