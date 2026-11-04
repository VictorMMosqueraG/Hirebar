# Reglas: enviar los correos de prospección aprobados

1. Lee `prospeccion/aprobados.json` ({"aprobados": "todos"} o una lista de números "n") y `prospeccion/pendientes.json`. Envía solo los aprobados, exactamente con el destinatario, asunto y cuerpo de la lista, desde el Gmail de la persona en Chrome.
2. Nunca agregues destinatarios ni cambies el texto.
3. Registra cada envío en `prospeccion/prospectos.md` (fecha, empresa, correo, tipo).
4. Al terminar, deja `prospeccion/pendientes.json` como {} y `prospeccion/aprobados.json` vacío, para que no se envíe dos veces.
5. Suma en `metricas-claude.json`, semana actual, sección "prospeccion": `enviados_empresas`, `enviados_negocios`, `seguimientos`.

Respuesta final (Telegram, texto plano, máximo 800 caracteres): "Enviados: N (empresas X, negocios Y, seguimientos Z)" y, si alguno falló, cuál y por qué.
