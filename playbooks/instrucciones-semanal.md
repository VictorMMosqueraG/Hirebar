# Reglas: informe semanal (domingo 6 p. m.)

Cierra la semana con datos, no con impresiones.

## Fuentes
- `metricas-radar.json`: lo que cuenta la app (avisados, aprobados, listas descartadas).
- `metricas-claude.json`: lo que cuentas tú (enviadas, descartadas, seguimientos, respuestas, ganados).
- `seguimiento.json`, `historial-propuestas.md`, `postulaciones.md`, `lotes.json`, `cupos.json`.
- Las notas de la semana en `metricas-radar.json` > "eventos" (comando "anota").

## Informe
Escribe `informes/<AAAA-SNN>.md` con: embudo por canal (avisadas → enviadas → leídas → respuestas → entrevistas o proyectos), qué funcionó, qué no, y 3 decisiones concretas para la próxima semana.

## Ajustes propuestos
Escribe `ajustes-propuestos.json` (lista; si no hay nada que ajustar, escribe []):
[{"titulo": "Quitar Magneto", "detalle": "0 respuestas en 40 envíos; se apaga en search-profile.json"}]
Solo propones: no cambies ningún archivo de configuración. La persona aprueba desde Telegram.

## Respuesta final (va a Telegram)
Texto plano, máximo 2.000 caracteres: números clave de la semana y las 3 decisiones.
