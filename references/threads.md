# Hilos narrativos sin resolver

Detecta promesas, preguntas y tensiones planteadas que no encuentran cierre. Útil para escritores que quieren saber qué quedó colgando antes del final.

## Tipos de hilos

### 1. Preguntas abiertas

Preguntas formuladas en el texto (no en diálogo casual de cortesía) que apuntan a información futura.

Heurística: oración que termina en `?` (o `¿...?`) y contiene marcadores epistémicos:

```
ES: "qué/quién/cuándo/dónde/por qué/cómo (será|sería|habrá|hizo|haría)"
EN: "what/who/when/where/why/how (will|would|could|did|had)"
```

Ejemplo capturado:
> ¿Quién había dejado la carta sobre la mesa?

El extractor busca si esa pregunta se responde en capítulos posteriores. Heurística básica: query FTS5 con NEAR de los sustantivos clave en el resto del manuscrito.

### 2. Promesas / juramentos / planes

```
ES: "(prometió|juró|se prometió|decidió que) ", "voy a", "algún día", "cuando vuelva"
EN: "(promised|swore|vowed|decided to) ", "I'll", "someday", "when I return"
```

Ejemplo:
> Marta se prometió que volvería a buscar el cuaderno.

Cierre esperado: el evento prometido aparece o se rechaza explícitamente más adelante.

### 3. Objetos introducidos con énfasis (Chekhov's gun)

Heurística: objeto descrito con detalle visual, mencionado solo en 1 escena y nunca más. El extractor cruza `entities.tsv` (tipo=object) con frecuencia: si freq=1-2 y la primera mención tiene >30 palabras de descripción a su alrededor, es candidato a Chekhov's gun no disparada.

### 4. Personajes introducidos sin reaparecer

Personaje con dialog tag (entró en scene como locutor) cuya frecuencia total es 1-2 menciones. Sospechoso de ser hilo abandonado.

## Salida: `threads.tsv`

```
type	line	chapter	excerpt	resolved	resolution_line	resolution_chapter	confidence
question	1843	Cap 2	¿Quién dejó la carta?	yes	8920	Cap 12	high
promise	2105	Cap 2	Marta se prometió volver al pueblo	yes	15203	Cap 18	high
promise	3402	Cap 3	juró encontrarla	no	-	-	-
object	450	Cap 1	pistola en el cajón (12 palabras descripción)	no	-	-	medium
character	890	Cap 1	—gritó Mateo	no	-	-	low
```

`confidence`:
- `high`: cierre textual claro (mismas palabras clave, pronombre directo, contexto coherente)
- `medium`: posible cierre pero ambiguo
- `low`: ningún match razonable encontrado — probablemente abandonado

## Modo de uso

```bash
bash scripts/extract-threads.sh "$WORK"
```

Reporta solo los `resolved=no`:

```
Hilos sin resolver: 7

🧵 PROMESA — Capítulo 3, línea 3402
> "juró encontrarla antes del invierno"
No detecté cierre. ¿Es deliberado o quedó colgando?

🧵 OBJETO — Capítulo 1, línea 450
> "una pistola descansaba en el cajón..."
Mencionado solo en Cap 1. Si es Chekhov's gun, no se dispara.

🧵 PERSONAJE — Capítulo 1, línea 890
> "—Lo mismo de siempre —gritó Mateo, dando un portazo."
Mateo aparece solo en Cap 1. Si es relevante, falta arco.
```

## Cierre falso vs cierre real

Distinguir es difícil sin LLM. Heurísticas que el extractor aplica:

- **Match de objeto**: el objeto reaparece en escena con interacción (sujeto/objeto directo de verbo de acción) → cierre alto
- **Match de personaje**: nombre reaparece con dialog tag o como sujeto → cierre alto
- **Match de promesa**: el verbo prometido (volver, buscar, encontrar) aparece junto al sujeto en pasado → cierre alto
- **Match solo léxico**: la palabra aparece pero sin acción → cierre medio. Reporta y deja al escritor decidir.

## Edge cases

- **Preguntas retóricas**: "¿Quién no ha sentido eso alguna vez?" — el extractor las filtra si detecta marcadores ("alguna vez", "alguien", "nadie"). Imperfecto.
- **Series de novelas**: hilos puede cerrarse en libro 2 o 3. Si el manuscrito apunta a saga (carpeta con varios `.md`), el extractor busca cierre en todos los archivos.
- **Estructura de bucle / non-linear**: si la novela termina donde empieza, los hilos del prólogo pueden cerrarse en el último capítulo. El extractor revisa toda la longitud, no solo capítulos posteriores.
- **Promesas implícitas**: "se quedó mirando el horizonte" puede sugerir un viaje futuro nunca cumplido. El extractor no captura esto. Solo promesas explícitas.

## Limitaciones

Reporta al usuario al entregar:

> Este análisis encuentra hilos por matching léxico, no comprensión semántica. Falsos positivos esperables: preguntas retóricas, objetos decorativos. Falsos negativos: hilos resueltos con paráfrasis fuerte. Trata el output como checklist editorial, no diagnóstico definitivo.
