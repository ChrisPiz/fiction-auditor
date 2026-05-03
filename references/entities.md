# Extracción de entidades

Construye candidatos de personajes, lugares y objetos sin LLM. Usa señales léxicas deterministas: capitalización, frecuencia, dialog tags, posesivos.

**No es NER perfecto.** Es un filtro de candidatos. Reporta con frecuencia y muestras — el escritor confirma cuáles son entidades reales.

## Algoritmo

Tres señales combinadas:

### 1. Capitalización + frecuencia

Palabras que empiezan con mayúscula y NO están al inicio de oración. Filtra por frecuencia ≥ umbral (default 3 menciones).

```bash
# Pseudocódigo — implementado en scripts/extract-entities.sh
python3 -c '
import re, sys
from collections import Counter
text = open(sys.argv[1]).read()
# Tokenizar respetando puntuación de cierre
tokens = re.findall(r"(?<=[\s,;:¿¡(\"\x27—–-])([A-ZÁÉÍÓÚÑ][a-záéíóúñ]+)", " " + text)
# Filtrar palabras función capitalizadas (inicio de oración)
counts = Counter(tokens)
for word, n in counts.most_common():
    if n >= 3:
        print(f"{n}\t{word}")
' "$WORK/manuscript.txt"
```

Stopwords capitalizadas que descartar (ES): `Y, O, El, La, Los, Las, Un, Una, Pero, Que, Como, Si, No, Cuando, Donde, Mientras`. (EN: `The, And, Or, But, If, When, Where, While, He, She, It, They`). El script las filtra.

### 2. Dialog tags

Patrones donde un nombre actúa como locutor:

```
ES: "—dijo NOMBRE", "—preguntó NOMBRE", "—susurró NOMBRE"
EN: "NAME said", "NAME asked", "NAME whispered"
```

Regex bilingüe en `references/patterns-bilingual.md`. Alta precisión: si NOMBRE aparece como dialog tag, casi seguro es personaje (no lugar/objeto).

### 3. Posesivos y descriptores familiares

```
ES: "su (madre|padre|hermano|hermana|hijo|hija|tío|tía|primo|prima) NOMBRE"
EN: "his/her (mother|father|brother|sister|son|daughter|uncle|aunt|cousin) NAME"
```

Útil para construir grafo de relaciones automáticamente.

## Salida: `entities.tsv`

```
freq	name	type	first_chapter	first_line	dialog_tag_count	relation_hints
47	Marta	character	1	23	18	hermana de Elena
31	Elena	character	2	1843	12	hermana de Marta
24	Madrid	place	1	45	0	-
12	Pueblo	place	3	3502	0	-
8	carta	object	2	1843	0	-
```

`type` heurístico:
- `character` si dialog_tag_count > 0 OR aparece tras "señor/señora/Sr./Sra./don/doña"
- `place` si aparece tras "en/desde/hacia/hasta/a" + capitalizada y dialog_tag_count = 0
- `object` si aparece como sustantivo común frecuente que el autor capitalizó (ej: "el Manuscrito", "la Carta")
- `unknown` si no encaja

El escritor revisa y corrige.

## Atributos por entidad

Para una entidad confirmada, extrae afirmaciones donde es sujeto o tema:

```bash
bash scripts/fts-query.sh "$WORK" 'NEAR("Elena" "años" OR "edad" OR "tenía", 10)'
bash scripts/fts-query.sh "$WORK" 'NEAR("Elena" "ojos" OR "pelo" OR "alto" OR "alta", 10)'
bash scripts/fts-query.sh "$WORK" 'NEAR("Elena" "madre" OR "padre" OR "hermana", 10)'
```

Categorías típicas a poblar para el bible:
- Edad / fecha de nacimiento
- Apariencia (ojos, pelo, altura, marcas distintivas)
- Relaciones (familia, parejas, amistades, enemigos)
- Profesión / rol
- Origen geográfico
- Hobbies / hábitos / tics
- Objeto/lugar significativo

## Bible auto-generado

`templates/bible.md` es el scaffold. Por cada entidad confirmada:

```markdown
## Elena

- **Tipo:** personaje
- **Primera mención:** Capítulo 2, línea 1843
- **Frecuencia:** 31 menciones

### Atributos detectados

| Atributo | Valor citado | Cap | Línea |
|---|---|---|---|
| Edad | "tenía 28 años" | 2 | 1855 |
| Pelo | "pelo castaño y corto" | 4 | 230 |
| Hermana de | Marta | 7 | 88 |

### Citas clave (top 5 por relevancia)

[snippets de fts-query]
```

El skill genera el bible y lo guarda en `$WORK/bible.md`. El escritor lo abre, edita lo que falta, y vuelve. En conversaciones futuras, el bible es input adicional para auditoría — lee `$WORK/bible.md` antes de extraer atributos para evitar duplicar trabajo.

## Edge cases

- **Apodos**: "Marta" y "Martita" cuentan como entidades distintas. Pregunta al escritor si quiere fusionarlos. Si sí, agrega aliases manuales en `$WORK/aliases.tsv` (`canonical<TAB>alias1<TAB>alias2`) y los scripts las normalizan en queries posteriores.
- **Nombres compuestos**: "María Elena" — el extractor los detecta si el regex captura bigramas capitalizados. Implementado en `extract-entities.sh`.
- **Apellidos solos**: "—gritó Sánchez" — entran como entidad separada. Si "Marta Sánchez" aparece junto en el texto, el script intenta colapsar.
- **Personajes mencionados pero ausentes**: alguien hablado en tercera persona pero nunca presente físicamente. El extractor los lista igual; el escritor decide.

## Limitaciones

- No hace coreference. "Ella" tras "Elena" no se cuenta como mención de Elena.
- No detecta personajes referidos solo por descripción ("el viejo del faro").
- En primera persona, el narrador a veces no es nombrado — el extractor no lo detecta.

Reporta estas limitaciones al usuario al entregar el bible.
