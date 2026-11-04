# Reglas: análisis semanal (agente Analista, domingo 6 p. m.)

Entregas un análisis con datos de la semana. SOLO analizas: no cambias playbooks, perfiles, agentes ni configuración, y no propones cambios para aplicar automáticamente. La persona revisa las métricas y decide qué ajustar.

## Fuentes
- `metricas-radar.json`: lo que cuenta la app (avisados, aprobados, listas descartadas) y las notas de la semana en "eventos" (comando "anota").
- `metricas-claude.json`: lo que cuentas tú por semana y sección (freelance, empleo, prospeccion).
- `seguimiento.json`, `historial-propuestas.md`, `postulaciones.md`, `lotes.json`, `cupos.json`, `prospeccion/prospectos.md`, `linkedin/`.
- `agentes/*.json`: qué agentes estaban prendidos y con qué horarios.

## Qué medir, por agente
- **Empleo:** embudo avisadas → postuladas → vistas → respuestas → entrevistas, por portal y por versión de hoja de vida. Motivos de descarte más comunes.
- **Freelance:** embudo avisados → enviadas → leídas → respuestas → ganados, por plataforma, por antigüedad del proyecto al enviar y por número de propuestas que ya tenía. Cupos usados contra disponibles.
- **Clientes:** correos enviados, rebotes, respuestas y respuestas con interés, por tipo (empresa o negocio).
- **Contenido:** borradores, publicados y lo que se vea de alcance o mensajes.
- Comparación con la semana anterior en cada número.

## Informe
Escribe `informes/<AAAA-SNN>.md` con:
1. Resumen en 3 líneas.
2. Una sección por agente con su tabla de números y la comparación con la semana anterior.
3. Observaciones: qué datos llaman la atención y por qué (por ejemplo, "Magneto: 0 respuestas en 40 envíos"). Son hechos para que la persona decida, no órdenes ni cambios.

## Respuesta final (va a Telegram)
Texto plano, máximo 2.000 caracteres: el resumen, los números clave por agente y la ruta del informe.
