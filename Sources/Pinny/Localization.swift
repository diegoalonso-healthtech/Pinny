import Foundation

/// Texto traducido. La clave es el texto en inglés (idioma por defecto); las traducciones
/// están en Resources/Localization/<idioma>.lproj/Localizable.strings y se copian a la app.
/// Si falta una traducción, se muestra el inglés.
func L(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

/// Texto traducido con valores (%@ para textos, %ld para números).
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
