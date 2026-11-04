# Reglas: publicación con imágenes para redes

Preparas UNA publicación para la cuenta que viene en el mensaje (su ficha trae carpeta, red, nombre, usuario, enfoque, paleta y estilo): un texto y de 3 a 6 imágenes (carrusel). NO publiques nada: la persona la aprueba desde Telegram.

En estas reglas, `<carpeta>` es la carpeta de la ficha (por ejemplo `contenido/empresa`).

## 1. El tema
- No hables de la hoja de vida de la persona, sus empleos, sus clientes, sus logros ni sus cifras. No leas `perfil.md` ni `perfil.json` para buscar tema.
- Sigue el campo "De qué habla y para quién" de la ficha. La publicación tiene que servirle a quien la lee, y así trae visibilidad y clientes.
- Si el enfoque no dice otra cosa, rota entre estos tipos de tema (primero el que menos se haya usado):
  1. Consejos de tecnología para negocios y pymes: qué automatizar, cuándo conviene un sistema a medida, cómo no perder datos, cuánto cuesta de verdad una app.
  2. Mitos y verdades del software (por ejemplo, "una web cuesta lo mismo que una app" o "la nube siempre sale más barata").
  3. Noticias o tendencias de tecnología de la semana, explicadas en palabras sencillas: qué significan para un negocio. Búscalas con WebSearch y que sean de los últimos 7 días. No inventes datos: si citas una cifra, que salga de lo que encontraste.
  4. Buenas prácticas para desarrolladores: backend, APIs, bases de datos, nube, seguridad, costos.
  5. Errores comunes que le cuestan plata a una empresa y cómo evitarlos.
  6. Preguntas que un negocio debe hacer antes de contratar un desarrollo.
- Antes de escoger, mira `<carpeta>/temas.md` y no repitas un tema de las últimas 8 publicaciones de esa cuenta. Al terminar, agrega una línea arriba: `AAAA-MM-DD · <tipo> · <tema>`.

## 2. Texto (`<carpeta>/borrador.md`)
- En español y con palabras sencillas.
- Primera línea: un gancho corto (una pregunta, un dato o una frase que choque).
- Después, 3 a 5 ideas cortas y prácticas. Termina con una pregunta o una invitación a escribir.
- LinkedIn: entre 120 y 200 palabras, sin emojis y máximo 3 hashtags al final.
- Instagram: entre 60 y 150 palabras, en párrafos cortos. Puede llevar 1 o 2 emojis si encajan, y entre 5 y 8 hashtags al final. Si la ficha trae usuario, la invitación puede ser "escríbenos al DM".
- Guarda solo el texto que se publicaría.

## 3. Imágenes (`<carpeta>/laminas/`)
- Un archivo HTML por imagen: `lamina-1.html`, `lamina-2.html`… (de 3 a 6).
- Cada una mide EXACTAMENTE 1080×1350 px: `html, body { margin: 0; width: 1080px; height: 1350px; overflow: hidden; }`.
- Todo dentro del archivo: CSS en `<style>` y dibujos o íconos en SVG escrito a mano. Nada de imágenes de internet, fotos, logos de marcas ni fuentes externas.
- Usa fuentes del sistema: `-apple-system, "Helvetica Neue", Arial, sans-serif`. Si el estilo pide serif, usa `Georgia`; si pide monoespaciada, usa `Menlo, monospace`.
- Usa SOLO los colores de la paleta de la ficha: fondo, superficie (tarjetas y bloques), acento, texto y texto secundario. Sigue el "Estilo de las imágenes" de la ficha.
- Estructura:
  - Lámina 1: portada con el gancho en letra grande.
  - Láminas del medio: una idea por lámina, con un título corto y máximo 30 palabras.
  - Última lámina: la pregunta o la invitación del final.
- En todas:
  - Texto de 44 px o más (títulos de 72 px o más) y márgenes de al menos 80 px.
  - Número de lámina abajo, del tipo "2/5".
  - Firma pequeña con el nombre de la ficha, la línea bajo el nombre y el usuario si lo hay. Si la ficha no trae nombre, no pongas firma.
- Revisa que ningún texto se salga ni quede tapado.

## 4. Si hay un cambio pedido
Si el mensaje trae un "Cambio que pidió…", aplícalo sobre el borrador anterior: el texto está en `<carpeta>/`, las imágenes anteriores en `<carpeta>/laminas-anteriores/` y el video anterior en `<carpeta>/video-anterior/`. Deja la publicación completa otra vez: texto, imágenes y video si lo lleva.

## 5. Short con voz (solo si la ficha dice "Video corto: SÍ")
Un video vertical de 20 a 40 segundos hecho para ganar seguidores en Reels, Shorts y TikTok. NO es una copia del carrusel: escoge la idea que más enganche (puede ser otro tema de la lista) y cuéntala como un video. Regístralo en `<carpeta>/temas.md` con el tipo "short".

Hirebar arma el video así: pone una voz en español a la narración de cada escena, y la escena dura lo que dura su voz. Encima dibuja subtítulos grandes palabra por palabra, en el centro de la pantalla (entre 1150 y 1450 px desde arriba). Cada escena entra con un pequeño rebote, se acerca despacio y se funde con la siguiente.

### Guion
- **Gancho (escena 1, máximo 2 segundos de voz):** una frase que frene el dedo. Puede ser una promesa ("3 señales de que tu sistema te está haciendo perder plata"), una contradicción ("Tu app no es lenta por el servidor"), un error común ("Si guardas las contraseñas así, tienes un problema") o una pregunta directa. Nada de "Hola" ni presentaciones.
- **Desarrollo:** de 3 a 5 escenas, una idea por escena, con ejemplos concretos y números si los hay (sin inventar). Cada escena dice algo nuevo; si una frase se puede quitar, quítala.
- **Cierre:** una frase que deje la idea clara y una invitación corta ("Síguenos para más", "Escríbenos 'SISTEMA' al DM"). Si se puede, que el final conecte con el inicio para que se vea otra vez.
- **Narración:** español neutro, como si se lo contaras a un amigo; frases cortas de 6 a 14 palabras; nada de siglas sin explicar. Entre 60 y 100 palabras en total. Escribe los números y símbolos como se dicen ("tres", "por ciento", "punto com") para que la voz los lea bien.

### Escenas (`<carpeta>/video/escena-N.html`, de 5 a 8)
- Cada escena mide EXACTAMENTE 1080×1920 px: `html, body { margin: 0; width: 1080px; height: 1920px; overflow: hidden; }`. Mismas reglas de archivo, fuentes y paleta que las imágenes.
- Son lo que se VE mientras la voz habla, no el texto de la voz (el subtítulo ya lo pone Hirebar). Cambia el tipo de visual en cada escena para que no se vuelva monótono:
  - una palabra o un número gigante (200 px o más);
  - emojis grandes como íconos (por ejemplo 🚨 💸 ⚡ ✅ ❌), que salen en color;
  - maquetas dibujadas con HTML y CSS: una pantalla de celular, una ventana de código con colores, un mensaje de error, un gráfico de barras, una factura, un antes y después, un ✅ contra un ❌;
  - una lista corta que se completa, o una flecha que señala el punto clave.
- Zonas: el contenido visual va entre 280 y 1120 px desde arriba. Deja libre la franja de 1150 a 1450 px (ahí van los subtítulos), los 250 px de arriba y los 420 px de abajo (ahí Instagram pone sus botones). Deja también 120 px libres a la derecha.
- La escena 1 tiene que verse llamativa incluso sin sonido: contraste fuerte, el elemento principal enorme.
- La última escena lleva el nombre y el usuario de la ficha bien visibles.

### `<carpeta>/video/guion.json`
```json
{"escenas": [
  {"archivo": "escena-1.html", "texto": "Tu app no es lenta por el servidor."},
  {"archivo": "escena-2.html", "texto": "En el noventa por ciento de los casos, el problema está en la base de datos."}
]}
```
"texto" es exactamente lo que dice la voz en esa escena (de 3 a 20 palabras).

### `<carpeta>/video/texto.md`
La descripción del video: un título que dé curiosidad en la primera línea, una o dos frases más, una invitación a comentar o a seguir la cuenta, y de 3 a 5 hashtags.
