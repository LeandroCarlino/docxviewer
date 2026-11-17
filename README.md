# DocxViewer

Visor ligero de documentos de Word para Windows 11, sin Office ni Microsoft Store.

- Abre `.docx` con su formato: colores, alineación, tablas, imágenes y saltos de página.
- Los `.doc` antiguos (Word 97-2003) se muestran como texto, con las tablas de precios alineadas.
- Vista paginada como Word, búsqueda con `Ctrl+F`, zoom y tema claro/oscuro.
- Impresión con **1 / 2 / 4 páginas por hoja**, numeración «Página X de Y» y exportación a PDF.
- Respeta el tamaño de página real (A4, Carta, legal) y sus márgenes.

## Requisitos

- Windows 10/11 con Microsoft Edge (o Chrome).
- [Node.js](https://nodejs.org) 20 o superior, solo para compilar.

## Usar

1. Ejecuta `install.cmd` (no necesita administrador).
2. Clic derecho en un `.docx` o `.doc` → **Abrir con** → **DocxViewer**
   → marcar **Usar siempre para abrir…**.

## Compilar el ejecutable único

```
npm install
node tools/build-sea.js
```

Genera `build\sea\DocxViewer.exe`, un ejecutable autocontenido de ~96 MB que ya no
necesita Node.js instalado. Incluye Node, el servidor local, la interfaz y las librerías.

## Desarrollo

```
node app.js "documento.docx"
```

o `probar.cmd "documento.docx"` (abre la app sin empaquetar).

## Cómo funciona

| Parte | Tecnología |
| --- | --- |
| `.docx` | [docx-preview](https://github.com/VolodymyrBaydalka/docxjs) |
| `.doc` (texto) | [word-extractor](https://www.npmjs.com/package/word-extractor) |
| Ventana | Edge/Chrome en modo aplicación (`--app`) |
| Servidor local | Node (`127.0.0.1`, puerto aleatorio, se apaga al cerrar) |
| Empaquetado | Node SEA + esbuild + postject |

Si un `.docx` no trae los saltos de página que guarda Word, se repagina con un motor
propio para que la impresión no recorte contenido.

## Limitaciones

- Es un visor, no un editor: no modifica el documento.
- No reproduce cuadros de texto flotantes, ecuaciones complejas ni objetos incrustados.
- Los `.doc` se muestran como texto (el formato binario antiguo no conserva el diseño).

## Estructura

```
app.js                 Servidor local
public/index.html      Interfaz, paginación e impresión
public/*.js            Librerías web incluidas
tools/build-sea.js     Compila el .exe único
tools/gen-icon.ps1     Genera el icono
tools/crear-prueba*.py Documentos de prueba
install.cmd            Registra la app en Windows (HKCU)
uninstall.cmd          Quita el registro
```

## Licencia

MIT © 2026 Leandro Carlino — ver [LICENSE](LICENSE).

Incluye librerías de terceros con sus propias licencias; sus avisos están en
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
