# Cómo contribuir a Hirebar

Gracias por ayudar. Se reciben issues y pull requests.

## Compilar y probar

```sh
swift build
swift test
scripts/bundle.sh --install   # app completa en ~/Applications
```

Antes de enviar cambios, corre `shellcheck -s sh scripts/*.sh`.

## Reglas del proyecto

- **Código en inglés y sin comentarios.** Los nombres de tipos, funciones y variables deben explicar lo que hacen. Lo que necesite explicación va en `docs/`.
- **Documentación en español:** README, docs, CHANGELOG, playbooks y descripciones de los pull requests.
- **Textos de la interfaz y de Telegram en español.** Los portales que busca Hirebar son de Latinoamérica.
- **Sin dependencias externas:** solo Swift, AppKit y Foundation.
- **Respeta las capas:** la app usa al motor, el motor usa a las fuentes y al núcleo, las fuentes usan al núcleo y el núcleo no usa a nadie. Mira la sección Arquitectura del [README](README.md).
- **Un portal por archivo.** Para portales nuevos, sigue [docs/agregar-un-portal.md](docs/agregar-un-portal.md).
- **Nada personal en el repositorio:** ni hojas de vida, ni historiales, ni tokens, ni correos. Los datos de cada persona viven en `~/Library/Application Support/Hirebar/`.
- **Respeta a los portales:** solo páginas y APIs públicas, con pausas entre peticiones. Nada de evadir CAPTCHAs ni iniciar sesión desde el código.

## Pull requests

- Un tema por PR, con una descripción corta de qué cambió y cómo lo probaste.
- El CI debe pasar: `swift build`, `swift test` y shellcheck.
