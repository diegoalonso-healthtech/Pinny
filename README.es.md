<p align="center"><img src="assets/logo.png" alt="Pinny" width="560"></p>

<p align="center"><b>Gestor de portapapeles para macOS</b><br>
 Apple silicon · macOS 14 o posterior · Gratis y de código abierto</p>

<p align="center"><a href="../../releases/latest"><b>⬇ Descarga el último .dmg de Pinny</b></a>: listo para usar, sin compilar nada</p>

<p align="center"><a href="README.md">English</a> · <b>Español</b></p>

# Pinny para macOS

**Lo que copias, a mano. Lo que importa, clavado.**

Pinny es un gestor de portapapeles gratuito y de código abierto **solo para macOS** (no funciona en Windows, Linux, iPhone ni iPad). Guarda tu historial de copias, te deja **anclar** lo importante, ordenar los pines en **carpetas** y pegarlos en cualquier app desde un menú rápido, un buscador o el clic derecho.

> Versión **1.0.0**. Solo texto. Sincronización cifrada e interfaz en inglés, previstas para próximas versiones.

## Qué hace

- **Historial** de todo lo que copias (por defecto los 20 últimos, ampliable hasta 2000).
- **Pines** que no caducan nunca, ordenables y agrupables en **carpetas**.
- **Menú rápido (⌃⌥V)** en la posición del cursor, en cualquier app:

  ```
  Pines      ›  📁 Carpeta 1  ›  texto
                              ›  texto
                 pin suelto
  Recientes  ›  últimos 10
  ```
  Eliges un elemento y Pinny lo pega en la app activa.
- **Buscador (⌃⌥⇧V):** ↑ ↓ para moverte, Intro para pegar, ⌘1…⌘9 para los nueve primeros, Esc para cerrar. Desde aquí gestionas pines y carpetas.
- **Tecla + clic derecho (opcional):** con ⌘ pulsada (configurable), el clic derecho abre el menú de Pinny en cualquier app, incluso en las que no admiten los Servicios de macOS. Sin la tecla, el clic derecho funciona como siempre.
- **Servicios de macOS:** *Pinny: Pines*, *Pinny: Recientes* y *Pinny: Buscar en todo*, en clic derecho → Servicios.
- **Respeta tu portapapeles:** después de pegar un pin, se restaura lo que tenías copiado.
- **Privacidad ante todo:** todo se queda en tu Mac (`~/Library/Application Support/Pinny`, con permisos solo para tu usuario). Sin red. Ignora lo que los gestores de contraseñas marcan como oculto, las apps que elijas y los elementos demasiado grandes.
- **Datos a salvo:** copia de seguridad automática en cada arranque; si el archivo de datos se daña, se aparta y nunca se sobrescribe.
- **Guía de configuración** con prueba de pegado real, apertura al iniciar sesión y desinstalador integrado.

## Instalar

**Solo para macOS.** Necesitas un Mac con Apple silicon (M1 o posterior) y macOS 14 Sonoma o posterior.

### Opción 1: descargar la app ya compilada (recomendado)

Sin Xcode, sin Terminal y sin compilar. Cada versión incluye el instalador listo:

1. Entra en [**Releases**](../../releases/latest) y descarga `Pinny-<versión>.dmg`.
2. Ábrelo y arrastra **Pinny** a **Aplicaciones**.
3. Abre Pinny desde Aplicaciones.

Pinny todavía no está notarizada por Apple, así que la primera vez macOS la bloqueará. Ve a Ajustes del Sistema → Privacidad y seguridad y pulsa **Abrir igualmente** (solo una vez).

### Opción 2: compilar desde el código

Necesitas Xcode o las Command Line Tools (`xcode-select --install`).

```sh
./scripts/build-app.sh
cp -R build/Pinny.app /Applications/
open /Applications/Pinny.app
```

Para crear el instalador (`build/Pinny-<versión>.dmg`):

```sh
brew install create-dmg   # una sola vez
./scripts/make-dmg.sh
```

Consejo: con la firma ad-hoc por defecto, macOS trata cada recompilación como una app nueva y el permiso de Accesibilidad deja de funcionar. Para evitarlo, firma con un certificado de firma de código autofirmado creado en Acceso a Llaveros:

```sh
SIGN_IDENTITY="Nombre de tu certificado" ./scripts/build-app.sh
```

## Primer arranque

Una guía te lleva por tres pasos:

1. **Permiso:** Pinny necesita Accesibilidad para pegar en otras apps (en macOS 27 se llama *Device Control and Data Access*). El botón abre el aviso del propio macOS.
2. **Menú con clic derecho (opcional):** activa tecla + clic derecho y elige la tecla.
3. **Pruébalo:** copia una frase de prueba y pégala en un cuadro. El paso se pone en verde cuando llega.

Puedes volver a abrir la guía desde el icono de la barra de menús → *Guía de configuración…*.

**¿El permiso está activado pero no funciona?** Pulsa **Reparar permiso** en la guía o en Ajustes: borra el permiso guardado y lo vuelve a pedir.

## Desinstalar

- Desde la app: icono de la barra de menús → **Desinstalar Pinny…** Puedes elegir si conservas o borras tu historial, pines y ajustes.
- Desde Terminal: `./scripts/uninstall.sh` (conserva tus datos) o `./scripts/uninstall.sh --purge` (lo borra todo).

## Limitaciones conocidas

- Solo texto (todavía sin imágenes ni archivos).
- Los Servicios de macOS solo aparecen en las apps que los admiten; las basadas en Electron normalmente no. Ahí usa el menú rápido o tecla + clic derecho.
- macOS fija las entradas de Servicios, así que no pueden listar cada pin. Para eso está el menú con clic derecho.
- *Abrir al iniciar sesión* puede no funcionar con firma ad-hoc o fuera de `/Applications`.

## Licencia

[MIT](LICENSE)
