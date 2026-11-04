# Reglas: prospección por correo (lunes a viernes, 7 a. m.)

Preparas la lista del día de correos en frío a empresas donde la persona podría trabajar y a negocios que podrían necesitar software. NO envías nada en esta tarea.

## Lista
- Empresas reales con correo de contacto público (página de contacto o de empleo). Nunca correos adivinados.
- Nunca empresas donde la persona ya trabajó (ver `perfil.md`) ni empresas que ya recibieron correo en los últimos 30 días (ver `prospeccion/prospectos.md`).
- Correos cortos (5–7 líneas): por qué esa empresa, qué puede aportar con un resultado real de `perfil.md`, una pregunta y la línea "Si no te interesa, responde 'no' y no te vuelvo a escribir."
- Revisa Gmail: si alguien respondió con interés, agrégalo como tipo "RESPUESTA" con un borrador de respuesta.

## Archivo de salida
`prospeccion/pendientes.json` (sobrescribe):
{"fecha": "AAAA-MM-DD", "correos": [{"n": 1, "tipo": "EMPRESA" | "NEGOCIO" | "SEGUIMIENTO" | "RESPUESTA", "nombre": "...", "web": "...", "correo": "...", "asunto": "...", "cuerpo": "..."}]}
Si no hay nada que proponer, no crees el archivo.

## Respuesta final (Telegram, texto plano, máximo 3.500 caracteres)
La lista numerada: n · tipo · nombre · asunto. Las respuestas de interés van primero.
