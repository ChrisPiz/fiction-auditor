# Fiction Auditor

Skill de Claude Code / Anthropic que audita manuscritos de novela **existentes** en busca de continuidad, consistencia de personajes, coherencia temporal e hilos narrativos sin resolver. Responde con **citas exactas** (capítulo + línea + texto verbatim). Nunca escribe prosa por ti — es un auditor de solo lectura.

Funciona con manuscritos en español e inglés.

---

## ¿Qué hace?

- Busca todas las menciones de un personaje, lugar u objeto con citas textuales
- Detecta inconsistencias factuales (edades, colores de ojos, fechas, parentescos)
- Lista capítulos, word count global y por capítulo
- Encuentra marcadores temporales ("hace tres años", "al día siguiente", "in 1987")
- Mapea cualquier línea citada a su capítulo

## ¿Qué NO hace?

- Escribir, generar, continuar o reescribir prosa
- Sugerir tramas, personajes o desarrollos
- Criticar calidad de escritura
- Reemplazar a un editor humano para feedback de desarrollo

Es un **auditor literal**, no un colaborador creativo.

---

## Instalación

### Claude Code (skill local)

```bash
# Skill global del usuario
mkdir -p ~/.claude/skills
git clone https://github.com/ChrisPiz/fiction-auditor.git ~/.claude/skills/fiction-auditor
```

O dentro de un plugin:

```bash
git clone https://github.com/ChrisPiz/fiction-auditor.git <tu-plugin>/skills/fiction-auditor
```

### Otros entornos (Copilot CLI, Gemini CLI, etc.)

El skill es un único archivo `SKILL.md` con frontmatter YAML estándar. Cualquier harness compatible con el formato Anthropic Skills lo acepta sin modificación.

---

## Activación

El skill se activa automáticamente cuando mencionas:

- Manuscrito, novela, capítulo, escena, story bible, character bible
- "¿Qué dije sobre [personaje/lugar]?"
- "Audita mi novela", "find inconsistencies in my book"
- Consistencia temporal, edad de personaje, parentescos
- Apuntar a un archivo `.docx`, `.md`, `.txt`, `.rtf`

Activación manual en Claude Code: `Skill fiction-auditor`.

---

## Formatos soportados

| Formato | Conversor preferido | Fallback |
|---------|---------------------|----------|
| `.txt`, `.md` | `cp` directo | — |
| `.docx` | `pandoc` | `python-docx` |
| `.rtf` | `pandoc` | `textutil` (macOS) |
| Carpeta con varios | concatenación alfabética con marcadores | — |

Para Pages o Google Docs: exportar primero a Word o Markdown.

---

## Cómo trabaja por dentro

### Workspace por manuscrito

Cada manuscrito tiene su propio directorio derivado del SHA-1 de la ruta original:

```
/tmp/fiction-auditor/
└── <hash12>/
    ├── source.path        # ruta original para trazabilidad
    ├── manuscript.txt     # versión normalizada
    ├── chapters.tsv       # cache de capítulos (línea<TAB>título)
    └── wordcount.txt      # cache de word count
```

Si re-ejecutas la auditoría y el `.docx` original es más nuevo, se re-convierte automáticamente. Si no, reusa la conversión.

### Indexación

Para manuscritos típicos (80k–200k palabras) usa `grep` o `ripgrep` directo: O(n) lineal pero ~1 GB/s con SIMD, queries <100ms. Sin overhead de índice.

Para queries repetidas en la misma sesión, cachea:
- **`chapters.tsv`** — lookup O(log n) de línea → capítulo en lugar de full-scan awk
- **`wordcount.txt`** — evita recomputar `wc -w`

Para sagas grandes (>500k palabras) o uso muy intensivo, opción de indexar con SQLite FTS5 (`tokenize='unicode61 remove_diacritics 2'`) — sub-ms por query con normalización de acentos integrada. Se construye solo si lo pides.

### Citas siempre verificables

- Toda respuesta cita el texto **palabra por palabra**, nunca paráfrasis
- Toda cita lleva número de línea + capítulo
- Inconsistencias se reportan con **ambas citas** en conflicto y ⚠️
- Limitaciones (pronombres, subtexto, prosa metafórica) se reportan honestamente en vez de inventar

---

## Ejemplo de sesión

```
Tú:    Audita /Users/yo/novela.docx

Skill: ✓ Manuscrito listo: 87,432 palabras, 18 capítulos, 412 KB
       Primeros 3:
         L12   Capítulo 1: El despertar
         L1843 Capítulo 2: La carta
         L3502 Capítulo 3: Vuelta a casa
       ¿Qué quieres revisar?

Tú:    ¿Qué he dicho sobre Elena?

Skill: Sobre Elena (hermana de Marta), encontré 3 menciones:

       Capítulo 4 — línea 230
       > Elena entró sin tocar, como siempre.

       Capítulo 7 — línea 88
       > —¿Dónde está tu hermana? —preguntó.

       Capítulo 12 — línea 412
       > Elena le había escrito esa mañana.

Tú:    ¿La edad de Marta es consistente?

Skill: ⚠️ Inconsistencia detectada:

       Capítulo 3 — línea 245
       > Marta tiene 34 años y trabaja en la imprenta.

       Capítulo 11 — línea 2103
       > Marta acaba de cumplir 36 — apenas dos meses después
       > del entierro de su padre.

       Si el entierro fue en el Capítulo 5 (que está a 6 meses
       del Capítulo 3), no encajan. Revisar.
```

---

## Limitaciones honestas

- **Pronombres:** "Ella entró" tras "Elena llegó" probablemente refiere a Elena, pero `grep` solo encuentra coincidencias literales. Pide confirmación cuando sea ambiguo.
- **Inconsistencias implícitas:** subtexto, tono, atmósfera. Solo detecta contradicciones explícitas.
- **Prosa muy metafórica:** falsos positivos posibles. Confía en el escritor sobre las heurísticas.
- **Manuscritos sin marcadores de capítulo:** las citas usarán solo número de línea.
- **Manuscritos enormes (>150k palabras):** no lee archivo completo, solo `grep` con contexto. Para auditoría holística, dividir por arco narrativo.

---

## Dependencias

Solo herramientas estándar:

- `bash`, `grep`, `awk`, `sed`, `wc`, `find`, `shasum`, `iconv`
- **Opcional pero recomendado:** `pandoc` (`brew install pandoc`)
- **Opcional:** `ripgrep` (`brew install ripgrep`) — 5–10x más rápido para manuscritos grandes
- **Fallback `.docx`:** `python3` + `python-docx` (`pip install --user python-docx`)
- **Fallback `.rtf` macOS:** `textutil` (preinstalado)

El skill **nunca instala dependencias en silencio** — si falta algo, te pregunta antes.

---

## Licencia

MIT. Ver [LICENSE](LICENSE).
