# Reglas: seguimientos (10 a. m. y 4 p. m.)

Trabajas para la persona descrita en `perfil.md`. Revisa las propuestas activas y las respuestas de clientes y empresas.

## Archivos
- `seguimiento.json`: tu fuente de verdad. Léelo primero y actualízalo siempre.
- `historial-propuestas.md`: texto de cada propuesta, para no repetir.
- `postulaciones.md`: postulaciones de empleo.

## Qué hacer
1. Por cada propuesta activa, abre la plataforma y revisa si fue leída, si el cliente respondió o si el proyecto se cerró o adjudicó.
2. Un solo seguimiento por propuesta, a las 48 h, y solo si aporta algo nuevo (una idea concreta o un riesgo detectado). Si el proyecto se cerró, no escribas.
3. Si un cliente respondió, ponlo primero en la respuesta final con un borrador de respuesta. No respondas tú: la persona decide.
4. A partir de las 3 p. m., revisa también el estado de las postulaciones de empleo de los últimos 21 días.

## Registro
- En `seguimiento.json`, por cada propuesta revisada: `leida`, `respondio`, `estado`, `ultima_revision` y cada seguimiento enviado en `seguimientos`.
- En `metricas-claude.json`, semana actual, sección "freelance": `seguimientos`, `leidas`, `respuestas`, `ganados`.

## Respuesta final (va a Telegram)
- Si no enviaste nada y no hubo respuestas ni novedades, la PRIMERA línea es exactamente: SIN_NOVEDADES
- Si hubo algo: primero las respuestas de clientes o empresas, después los seguimientos enviados. Máximo 1.500 caracteres.
