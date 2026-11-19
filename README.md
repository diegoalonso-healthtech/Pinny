<p align="center"><img src="assets/logo.png" alt="Pinny" width="560"></p>

# Pinny

**Lo que copias, a mano. Lo que importa, clavado.**

Gestor de portapapeles de código abierto para macOS con **historial, pines, carpetas de pines, menú rápido con submenús y Servicios**.

> Estado: **v0.3.11 (antes ClipPin), en pruebas.** Solo texto. Sincronización en la nube, traducción al inglés y CI, previstos para v0.4.

## Qué hace

- Guarda el historial de texto copiado (por defecto los 20 últimos elementos no anclados; ampliable en Ajustes hasta 2000).
- **Pines** que no se borran nunca solos, ordenables, agrupables en **carpetas** (un nivel).
- **Menú rápido (⌃⌥V por defecto)**: un menú nativo en la posición del cursor, en cualquier app:

  ```
  Pines      >  📁 Carpeta 1  >  texto
                               >  texto
                 texto suelto
  Recientes  >  últimos 10
  ```
  Al elegir un elemento se pega en la app activa.
- **Panel con buscador (⌃⌥⇧V por defecto)**: ↑ ↓ para moverte, Intro para elegir, ⌘1…⌘9 para elegir directamente, Esc para cerrar. Desde aquí anclas, mueves pines, creas y gestionas carpetas.
- **Tecla + clic derecho (experimental, opcional):** con ⌘ (configurable) pulsada, el clic derecho muestra el menú de Pinny con Pines › carpetas › textos y Recientes en cualquier app. Se activa desde la guía de bienvenida o en Ajustes. Sin la tecla, el clic derecho funciona como siempre.
- **Servicios** (clic derecho → Servicios): *Pinny: Pines*, *Pinny: Recientes*, *Pinny: Buscar en todo*.
- Icono en la barra de menús con los mismos Pines y Recientes (elegir = copiar).
- **Privacidad:** ignora lo que los gestores de contraseñas marcan como oculto, una lista de apps ignoradas (editable) y un tamaño máximo por elemento.
- Ajustes: límite de historial, atajos, apps ignoradas, abrir al iniciar sesión.
- Al pegar con los atajos o el menú rápido, se restaura después lo que tenías copiado.
- Todo es local: `~/Library/Application Support/Pinny/store.json` (carpeta 700, archivo 600). Sin red.
- **Copia de seguridad:** en cada arranque se guarda `store.backup.json`. Si `store.json` se daña, Pinny lo aparta como `store.corrupt-<fecha>.json`, recupera la copia y te avisa.

## ¿Venías de ClipPin?

Pinny es el nuevo nombre de ClipPin. La primera vez que abres Pinny copia tu historial, pines, carpetas y ajustes de ClipPin (sin borrar nada de ClipPin). Desinstala ClipPin antes, conservando los datos, para que no haya dos apps vigilando el portapapeles: icono de ClipPin → *Desinstalar ClipPin…* sin marcar la casilla de borrar datos. Como Pinny es una app nueva para macOS, tendrás que volver a dar el permiso de Accesibilidad.

## Compilar

Requisitos: Apple silicon, macOS 14 o superior, Xcode o Command Line Tools (`xcode-select --install`).

```sh
./scripts/build-app.sh
cp -R build/Pinny.app /Applications/
open /Applications/Pinny.app
```

Como la firma por defecto es ad-hoc, la primera vez macOS puede pedir abrirla con clic derecho → Abrir.

### Evitar que macOS pida de nuevo Accesibilidad tras cada compilación

Con firma ad-hoc, cada recompilación cuenta como una app distinta. Crea un certificado autofirmado (Llavero → menú Llavero → Asistente de Certificados → Crear un certificado → Tipo: *Firma de código*) y compila con:

```sh
SIGN_IDENTITY="Nombre de tu certificado" ./scripts/build-app.sh
```

## Crear el instalador (.dmg)

```sh
brew install create-dmg      # una sola vez (código abierto)
./scripts/build-app.sh
./scripts/make-dmg.sh        # → build/Pinny-<versión>.dmg
```

El DMG muestra la ventana «Arrastra Pinny a Aplicaciones». Sin `create-dmg` se genera un DMG sencillo, sin fondo. Los diseños originales del icono y del fondo están en `assets/` (SVG).

Como la app no está notarizada por Apple, al abrirla por primera vez tras descargarla macOS mostrará un aviso. Se permite una vez en Ajustes del Sistema → Privacidad y seguridad → «Abrir igualmente».

## Activar los Servicios

Al abrir Pinny por primera vez aparece una **guía de configuración** en tres pasos: dar el permiso (con el aviso del propio macOS), activar opcionalmente tecla + clic derecho y una **prueba real**: copias una frase y la pegas en un cuadro; el paso se pone en verde solo cuando llega. La guía vuelve sola al frente cuando sales de Ajustes del Sistema. Puedes volver a abrirla desde el icono de la barra de menús → *Guía de configuración…*. A mano:


1. Abre Pinny (aparece un pin en la barra de menús).
2. Ajustes del Sistema → Teclado → Atajos de teclado → Servicios → Texto → marca los tres que empiezan por **Pinny:**.
3. Si no aparecen, ejecuta y reabre la app:

   ```sh
   /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f /Applications/Pinny.app
   /System/Library/CoreServices/pbs -update
   ```

## Permiso de Accesibilidad

Para pegar con los atajos y el menú rápido, Pinny necesita Ajustes del Sistema → Privacidad y seguridad → Accesibilidad (en macOS 27 este apartado ha cambiado de nombre: *Device Control and Data Access* en inglés). Sin él, el elemento elegido queda en el portapapeles y lo pegas tú con ⌘V.

## Desinstalar

Tres opciones:

- Desde la app: icono de la barra de menús → **Desinstalar Pinny…** (o en Ajustes). Puedes marcar si quieres borrar también tu historial, pines y ajustes.
- Desde Terminal, conservando tus datos: `./scripts/uninstall.sh`
- Desde Terminal, borrándolo todo: `./scripts/uninstall.sh --purge` (añade `--yes` para no pedir confirmación).

Cierra la app, la borra de `/Applications` (o `~/Applications`), quita su permiso de Accesibilidad y refresca los Servicios. Los datos están en `~/Library/Application Support/Pinny`.

## Si el permiso está activado pero no funciona

Con firma ad-hoc, cada recompilación cuenta como una app distinta: el interruptor sigue activado en Ajustes del Sistema, pero ya no vale. En la guía de bienvenida o en Ajustes pulsa **Reparar permiso** (borra el permiso guardado y lo vuelve a pedir), o firma con un certificado propio (ver *Compilar*).

## Limitaciones conocidas

- Los Servicios solo aparecen en apps que los soportan; las basadas en Electron (como Claude de escritorio) normalmente no los muestran. Para esas apps, usa el menú rápido o el panel.
- macOS no admite submenús en Servicios y sus entradas son fijas: no pueden listar cada pin. Para eso está la opción de tecla + clic derecho.
- La app en primer plano se usa como aproximación de «la app que ha copiado» para la lista de apps ignoradas.
- «Abrir al iniciar sesión» puede no funcionar con firma ad-hoc o fuera de `/Applications`.
- Solo texto plano.

## Licencia

MIT
