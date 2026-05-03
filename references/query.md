# Respondiendo preguntas del usuario

Este módulo cubre el caso más común: el usuario pregunta algo concreto sobre el manuscrito y esperas dar respuesta con citas.

## Patrón estándar

1. **Identifica el sujeto de la query** (entidad, atributo, escena, palabra clave)
2. **Construye query FTS5** con NEAR si hay dos términos relacionados
3. **Limita resultados** (default 30, ofrece "ver más" si hay >30)
4. **Mapea cada hit a su capítulo** vía `chapter-of-line.sh`
5. **Cita textual** — nunca parafrasees el manuscrito
6. **Si la respuesta requiere síntesis**, sintetiza tú con tus citas como base, marca claramente qué es cita y qué es interpretación tuya

## Ejemplos

### "¿Qué dije sobre Elena?"

```bash
bash scripts/fts-query.sh "$WORK" 'Elena' 30
```

Reporta menciones agrupadas por capítulo. Si son >50, muestra primeras 30 + count y ofrece filtrar por atributo.

### "¿Qué profesión tiene Marta?"

```bash
bash scripts/fts-query.sh "$WORK" 'NEAR("Marta" "trabajaba" OR "era" OR "profesión" OR "oficio", 12)'
```

Filtra hits donde "Marta" es sujeto, no objeto de oración. Cita las afirmaciones encontradas.

### "Encuentra la primera escena con Elena y Marta juntas"

```bash
bash scripts/fts-query.sh "$WORK" 'NEAR("Elena" "Marta", 30)' 5
```

Ordenado por línea (no por bm25). El primer resultado es la primera co-ocurrencia.

### "¿Cuántas veces aparece la palabra 'silencio'?"

FTS5 cuenta:

```bash
sqlite3 "$WORK/fts5.db" "SELECT COUNT(*) FROM paragraphs WHERE paragraphs MATCH 'silencio';"
```

Reporta el número y los primeros 5 ejemplos con cita.

### "Busca la frase 'el rojo del atardecer'"

```bash
bash scripts/fts-query.sh "$WORK" '"el rojo del atardecer"'
```

Comillas dobles = frase exacta. Útil cuando el escritor recuerda parcialmente y quiere localizar la cita original.

## Formato de respuesta

Sigue el formato del SKILL.md raíz. Resumen:

```
Sobre **Elena**: 7 menciones en 5 capítulos.

**Capítulo 2 — línea 1843**
> Elena entró sin llamar, como siempre.

**Capítulo 4 — línea 230**
> Elena le había escrito esa mañana.

[...]
```

**Reglas:**
- Texto entre `>` exacto, sin reformatear
- Capítulo + línea siempre
- Si hay >30 hits, muestra los primeros 30 + count y pregunta si quiere filtrar
- Si hay 0 hits, dilo claramente y sugiere variantes (synonyms, lematización manual, búsqueda fuzzy)

## Cuando la query es ambigua

Si el usuario pregunta algo abierto ("¿qué tal va el primer acto?", "¿cómo está caracterizado el villano?"), pide concreción antes de buscar:

> "Para auditar eso necesito un foco. Algunas opciones:
> - Personajes que aparecen en el primer acto (caps 1-N)
> - Atributos del villano según el manuscrito
> - Hilos abiertos al final del primer acto
> - Marcadores temporales del arco
>
> ¿Cuál prefieres? O dime tú con más detalle qué quieres ver."

Nunca inventes un análisis sin citas. Si no puedes citar, no respondas.

## Synthesis multi-hit

Cuando 5-10 hits sobre el mismo tema se acumulan, sintetiza explícitamente:

```
Sobre el pueblo (12 menciones):

**Atributos consistentes:**
- Costero (Cap 1 L23, Cap 7 L1843, Cap 14 L4502)
- Tiene faro (Cap 1 L45, Cap 9 L2103)
- Población pequeña (Cap 3 L890: "no llegan a quinientos")

**Variaciones:**
- Cap 1 lo llama "pueblo blanco". Cap 11 dice "casas de piedra gris". Posible drift descriptivo.

**Citas representativas:**
[3-5 mejores quotes con cap+línea]
```

Marca claramente "atributos" (resumen tuyo) vs "citas" (texto del autor).

## Búsqueda fuzzy

FTS5 con `tokenize='unicode61 remove_diacritics 2'` ya normaliza acentos. Para variantes morfológicas (singular/plural, conjugaciones), usa OR con stem manual:

```bash
'(amaba OR amó OR amar OR amaría)'
```

O activa búsqueda de prefijo:

```bash
'ama*'   # amaba, amaron, amante, amargo (cuidado con falsos positivos)
```

Para typos posibles, sugiere al usuario usar `iconv` + `grep -i` directo si FTS5 no acierta.

## Performance

- Query típica FTS5: 1-10ms en 200k palabras
- `chapter-of-line.sh` lookup: <1ms (binary search en chapters.tsv)
- Reporte completo a usuario (con formateo + 30 citas): <100ms

Si una query toma >1s, algo está mal — probablemente FTS5 no se construyó. Verifica `$WORK/fts5.db` existe y tiene tabla `paragraphs`.
