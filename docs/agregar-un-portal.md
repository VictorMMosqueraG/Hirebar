# Cómo agregar un portal

Un portal nuevo es un archivo nuevo en `Sources/HirebarSources/` más una línea en el catálogo.

## Freelance

1. Crea `MiPortalSource.swift` con un `struct` que cumpla `ListingSource`:

```swift
public struct MiPortalSource: ListingSource {
    public let id = "miportal"
    public let name = "Mi Portal"

    public init() {}

    public func search(skip: Set<String>, profile: SearchProfile) async -> SourceResult {
        // lee la página o API pública, usa FreelanceClassifier.classify(...)
        // y devuelve Hit con id "mp:<id del proyecto>"
    }
}
```

2. Agrégalo a `Catalog.freelance` en `ListingSource.swift`.
3. Agrega su `id` a `Config.freelanceSources` y su título a `StatusMenu.sourceTitles`.

## Empleo

Igual, pero cumpliendo `JobSource`. Además de `search`, puedes definir:

| Miembro | Para qué |
|---|---|
| `hitPrefix` | Prefijo de los ids (por ejemplo `"mp"` para `mp:123`). Obligatorio. |
| `descriptionCheck(for:)` | Qué página leer antes de avisar. `.skip` si la búsqueda ya revisó todo. |
| `descriptionText(from:)` | Solo el texto de la oferta, sin menús ni "ofertas similares". |
| `location(from:)` | Ubicación de la oferta, si el portal la muestra. |
| `staleReason(page:)` | Motivo para descartar una oferta vieja. |
| `requiresRemoteInDescription` | `true` si el portal no marca la modalidad. |

Agrégalo a `Catalog.jobs`, a `Config.jobSources` y a `StatusMenu.sourceTitles`.

## Reglas

- Solo páginas o APIs públicas, sin iniciar sesión.
- Pausa entre peticiones (`Net.pause`) para no cargar al portal.
- Las palabras de búsqueda van en `search-profile.json`, no en el código.
- Agrega una prueba del parser con un trozo de HTML o JSON de ejemplo.
