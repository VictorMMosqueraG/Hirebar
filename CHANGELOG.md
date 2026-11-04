# Cambios

## 0.2.0 (sin publicar)

- `perfil.json` como fuente única: experiencia, logros con tecnologías, habilidades con nivel (`domino`, `conozco`, `evito`), preferencias y variantes de hoja de vida.
- Las habilidades amplían las búsquedas y los filtros de los radares sin recompilar.
- Comandos de Telegram `logro`, `trabajo`, `habilidad`, `habilidades` y `hv`.
- Tarea `perfil`: Claude actualiza el perfil y escribe una hoja de vida HTML por variante; la app crea los PDF con Chrome sin ventana y los manda por Telegram.
- Agentes independientes (Empleo, Freelance, Clientes, Contenido, Perfil y Analista), cada uno con su archivo `agentes/<id>.json`: prendido, envío automático, frecuencia de búsqueda, cupo diario y tareas con horario propio.
- Menú con un submenú por agente y comandos `agentes`, `agente <nombre> on/off`, `corre <nombre>` y `auto <agente> si/no`.
- El informe del domingo solo analiza: se quitan los ajustes propuestos y el modo `ajustes`.
- Borradores de LinkedIn martes y jueves.
- Hoja de ruta con contenido para redes, portales como archivos, cazador de clientes y registro único.

## 0.1.0 (sin publicar)

- Primera versión, separada de una herramienta privada. La parte de VPN y bastiones ahora vive en [Gatebar](https://github.com/VictorMMosqueraG/Gatebar).
- Radar freelance: Workana y Freelancer.
- Radar de empleo: LinkedIn, Get on Board, Computrabajo, elempleo y Magneto, con revisión de la descripción completa.
- Avisos y aprobación por Telegram (o ntfy), con envío automático opcional.
- Claude Code redacta y envía propuestas, postula, hace seguimientos, prospección por correo, borradores de LinkedIn e informe semanal, guiado por playbooks editables.
- Perfil de búsqueda en `search-profile.json`: palabras clave, bloqueos, salario mínimo, años y ciudad sin recompilar.
- Si la sesión de Claude Code se vence, las listas quedan guardadas para reintentar y llega un solo aviso por hora.
