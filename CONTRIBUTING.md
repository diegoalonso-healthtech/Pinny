# Contributing to Pinny

Thanks for helping! The easiest way to contribute is with translations.

## Fix a translation

1. Open `Resources/Localization/<language>.lproj/Localizable.strings` (for example `fr.lproj`).
2. Each line looks like `"English text" = "Translated text";`. Change only the text on the right.
3. Keep these exactly as they are: `%@` and `%ld` (values inserted by the app), `\n` (line break) and `\"` (quote).
4. Open a pull request. You don't need to build the app.

## Add a new language

1. Copy `Resources/Localization/es.lproj` to a new folder named with the language code, for example `nl.lproj` (Dutch) or `ja.lproj` (Japanese).
2. Translate the right-hand side of every line in `Localizable.strings` and `ServicesMenu.strings`.
3. Add the code to `CFBundleLocalizations` in `Resources/Info.plist`.
4. Add the language to the `Lang.available` list in `Sources/Pinny/Localization.swift`, using its name in that language.
5. Open a pull request.

The test sentence in the setup guide ("No pins were harmed in the making of this text 📌") is a joke: feel free to adapt it so it's funny in your language.

## Code

Bug reports and pull requests are welcome. Pinny builds with `./scripts/build-app.sh` (see the README).
