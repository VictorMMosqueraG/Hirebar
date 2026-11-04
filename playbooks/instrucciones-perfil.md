# Reglas: actualizar el perfil y regenerar las hojas de vida

La persona pidió un cambio desde Telegram (un logro nuevo o un cambio de trabajo) o pidió regenerar sus hojas de vida. El pedido viene en el mensaje. No necesitas el navegador.

## Archivos
- `perfil.json`: fuente única. Contiene `person`, `preferences`, `skills`, `experience`, `projects`, `rules` y `cvVariants`.
- `perfil.md`: versión en texto que leen las demás tareas. Siempre debe decir lo mismo que `perfil.json`.
- `hv/plantilla.html`: diseño base de la hoja de vida.
- `hv/<id>.html`: una hoja de vida por cada elemento de `cvVariants`. La app convierte cada una en `<file>.pdf`.

## 1. Actualizar perfil.json
- **Logro:** agrégalo en `achievements` de la experiencia que corresponda (la actual si no dice otra), con `text`, `tech` (tecnologías que menciona) y `date` (AAAA-MM). Escríbelo con verbo en pasado y con número si lo hay. Si el pedido no trae número, no lo inventes.
- **Cambio de trabajo:** cierra la experiencia actual (`to` = mes del cambio) y crea la nueva arriba con `role`, `company`, `type` ("empleo" o "consultoria"), `from` y `achievements` vacío. Actualiza `person.headline` si cambia el cargo y las `rules` que nombren el empleo anterior como actual.
- **Habilidades:** si el logro menciona una tecnología que no está en `skills`, agrégala como "conozco" y dilo en la respuesta. Nunca subas una habilidad a "domino" por tu cuenta.
- Nunca inventes empresas, fechas, títulos ni cifras. Si algo no se entiende, no lo agregues y pregunta en la respuesta final.
- Después de editar, vuelve a leer `perfil.json` completo y revisa que sea JSON válido.

## 2. Actualizar perfil.md
Reescribe las secciones que cambiaron (experiencia, años por tecnología, titular). Conserva el resto tal cual, incluidas las reglas y los datos para formularios.

## 3. Regenerar las hojas de vida
Para cada elemento de `cvVariants` escribe `hv/<id>.html` partiendo de `hv/plantilla.html`:
- Titular orientado a `title` y a las tecnologías de `focus`.
- Perfil de 3–4 líneas con las tecnologías de `focus` primero.
- En cada experiencia, primero los logros cuyo `tech` coincide con `focus`; máximo 6 viñetas en la experiencia actual y 4 en las demás.
- Habilidades agrupadas, con las de `focus` primero. Solo las de nivel "domino" y "conozco". Nunca las de "evito".
- Formato ATS: una columna, sin tablas, sin imágenes, sin íconos y con títulos estándar (Perfil, Experiencia, Educación, Habilidades, Idiomas). Máximo 2 páginas.
- El texto es en español, salvo que el `title` de la variante diga otra cosa.

## Respuesta final (va a Telegram)
Texto plano, máximo 800 caracteres: qué cambió en el perfil (una línea por cambio), qué habilidades se agregaron y qué hojas de vida se regeneraron. La app te sigue con los PDF.
