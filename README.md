![Trama — auditor de continuidad narrativa para manuscritos](assets/header.png)

# Trama

> *Trama* en español tiene doble sentido: el argumento de la historia + el hilo transversal del tejido. Ambos hay que auditar para que la novela sostenga.

Auditor de continuidad para tu novela. Le apuntas al manuscrito y te responde preguntas sobre lo que ya escribiste, con **citas exactas** (capítulo, línea, texto verbatim).

---

## ¿Qué te ayuda a hacer?

- **Recordar todo lo que dijiste sobre un personaje, lugar u objeto** sin releer el manuscrito completo.
- **Detectar contradicciones**: ¿la edad de Marta cuadra entre los capítulos? ¿el color de ojos cambió? ¿la cronología es coherente con los saltos de tiempo?
- **Construir tu character bible automáticamente** a partir del texto: personajes, relaciones familiares, atributos detectados.
- **Encontrar hilos sin cerrar**: promesas que un personaje hizo y nunca cumplió, preguntas planteadas y nunca respondidas, objetos introducidos con énfasis que nunca volvieron a aparecer (Chekhov's gun sin disparar).
- **Mapear la línea temporal** del manuscrito y verificar que los saltos cuadren con la edad de los personajes y las estaciones.
- **Comparar versiones**: cada vez que terminás un capítulo, podés ver qué cambió desde la última auditoría — qué hilos nuevos abriste, cuáles cerraste.

Funciona con manuscritos en **español e inglés**. Soporta sagas multi-volumen y libros largos.

## ¿Qué NO hace?

- Escribir, generar, continuar o reescribir prosa
- Sugerir tramas, personajes o desarrollos
- Criticar la calidad de tu escritura
- Reemplazar a un editor humano de desarrollo

Es un **auditor literal**, no un colaborador creativo. Solo te dice lo que ya está en tu texto.

---

## Funcionalidades

| Capacidad | Detalle |
|---|---|
| 🔍 **Búsqueda con citas** | Todas las menciones de un personaje, lugar u objeto, con texto verbatim + capítulo + línea. Búsquedas sub-ms incluso en libros de 500k palabras. |
| 📖 **Character bible automatizado** | Extrae personajes, lugares y objetos del texto. Detecta relaciones familiares, atributos, frecuencia de aparición. Genera un scaffold markdown editable que podés completar. |
| ⚠️ **Auditoría de atributos** | Detecta contradicciones explícitas: edad, ojos, pelo, altura, profesión, relaciones. Atribuye cada claim al dueño correcto (filtra "ojos de Elena" cuando Marta también está en el contexto). Excluye flashbacks ("cuando tenía 12 años") del audit principal. |
| ⏰ **Línea temporal** | Extrae 8 tipos de marcador: fechas absolutas, saltos relativos, días de la semana, estaciones, edades, próximos días, hedge temporal. Cruza con el audit para validar coherencia (¿la edad cuadra con los meses transcurridos?). |
| 🧵 **Hilos narrativos** | Detecta preguntas abiertas, promesas (`prometió`, `juró`, `voy a`), personajes huérfanos (aparecen una vez con diálogo y no vuelven), objetos introducidos con énfasis y nunca usados. Marca cuáles se cerraron y cuáles no. |
| 🔁 **Auditoría recurrente** | Cada vez que ejecutás una auditoría, Trama guarda un snapshot. Después podés comparar runs y ver qué cambió: entidades nuevas, hilos cerrados, hilos persistentes, cambios de frecuencia. |
| 🧠 **Sagas grandes** | Para manuscritos >150k palabras o multi-volumen, orquesta análisis paralelo por arco/personaje/dimensión. Agrega los hallazgos en un reporte único. |
| 📁 **Multi-formato** | Lee `.txt`, `.md`, `.docx`, `.rtf`, o carpetas con varios archivos en orden alfabético. |
| 🌐 **Bilingüe ES/EN** | Detecta el idioma automáticamente. Patrones específicos para capítulos, marcadores temporales, dialog tags y atributos en cada idioma. |
| 🗺️ **Mapeo línea → capítulo** | Toda cita lleva capítulo + línea. Encontrás el pasaje exacto sin abrir el manuscrito. |
| 🔍 **Búsqueda con acentos** | `anos` encuentra `años`, `marta` encuentra `Marta`. No te preocupes por mayúsculas ni tildes. |
| 🔄 **Auto-update** | Te avisa cuando hay nuevas versiones disponibles en GitHub (máximo una vez al día). |

---

## Instalación

Trama funciona en **[Claude Code](https://claude.com/claude-code)** (CLI de Anthropic). Es la única manera de usarlo con todas sus capacidades.

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/ChrisPiz/trama.git ~/.claude/skills/trama
```

Listo. La próxima vez que abras `claude` en una terminal, Trama está disponible. Mismo plan Pro/Max que ya pagás — sin costo extra.

> ⚠️ **Claude Desktop / Claude.ai web** funcionan en modo limitado (auditor one-shot, sin historial entre sesiones). Ver [DETAILS.md](DETAILS.md) para detalles.

---

## Formatos soportados

| Formato | Notas |
|---------|-------|
| `.txt`, `.md` | Lectura directa |
| `.docx` | Vía pandoc o python-docx |
| `.rtf` | Vía pandoc o textutil (macOS) |
| Carpeta con varios archivos | Concatena en orden alfabético — útil para sagas con un archivo por libro |

Para **Pages** o **Google Docs**: exportá primero a Word o Markdown.

**PDF no está soportado** — la extracción tiene demasiada pérdida para mantener citas exactas. Si tu manuscrito está solo en PDF, exportá a Word primero.

---

## Dónde quedan los archivos

Trama crea una carpeta `trama-doc/` **al lado de tu manuscrito**, no en una carpeta oculta. Si auditás `/Users/yo/Documents/novela.docx`:

```
/Users/yo/Documents/
├── novela.docx              ← tu manuscrito
└── trama-doc/
    └── novela/              ← workspace, todo visible aquí
        ├── manuscript.txt   # versión normalizada del texto
        ├── chapters.tsv     # mapa de capítulos
        ├── entities.tsv     # personajes/lugares/objetos detectados
        ├── timeline.tsv     # marcadores temporales
        ├── threads.tsv      # hilos sin resolver
        ├── runs/            # snapshots por fecha
        └── audit-log.tsv    # historial de auditorías
```

Lo abrís en Finder, lo versionás con git junto al libro, lo compartís con tu editor — está donde esperás encontrarlo, no escondido.

---

## Cómo se usa

Una vez instalado, hablale a Claude Code en lenguaje natural:

```
Tú:    Audita /Users/yo/Documents/mi-novela.docx

Claude: ✓ Manuscrito listo: 87.432 palabras, 18 capítulos.
        ¿Qué quieres revisar?

Tú:    ¿Qué he dicho sobre Elena?

Claude: Sobre Elena: 7 menciones en 5 capítulos.

        Capítulo 1 — línea 5
        > Su madre Elena entró en la cocina sin tocar.

        Capítulo 4 — línea 230
        > Los ojos verdes de Elena la miraban con preocupación.

        [...]

Tú:    ¿La edad de Marta es consistente?

Claude: 🟡 edad de Marta — 3 afirmaciones, severidad=soft

        L23 · Capítulo 2: La carta
          [34] > Marta tenía 34 años cuando empezó todo.
        L1843 · Capítulo 5: La carta
          [36] > Marta tenía ahora 36 años.

        Δt narrativo entre citas: ~3 años. Diferencia de edad: 2 años.
        Posiblemente coherente, depende del salto narrativo.
```

---

## Limitaciones honestas

- **Pronombres no resueltos**: "Ella entró" después de "Elena llegó" probablemente refiere a Elena, pero Trama no resuelve pronombres. Te pide confirmación si es relevante.
- **Inconsistencias implícitas**: subtexto, tono, atmósfera quedan fuera. Solo detecta contradicciones explícitas con citas directas.
- **Prosa muy metafórica**: puede haber falsos positivos en marcadores temporales ("hace mil años que no te veo"). Te muestra el match crudo y dejás vos que decida.
- **Personajes referidos solo por descripción** ("el viejo del faro") no aparecen en el extractor.
- **Apodos**: "Marta" y "Martita" cuentan como entidades distintas. Podés registrarlos manualmente como aliases para que se fusionen.
- **Manuscritos sin marcadores de capítulo**: las citas usan solo número de línea.
- **Cambios deliberados** (un personaje envejece entre tomos, cambia de profesión): podés registrarlos como excepciones para que el audit los respete.

Trama te dice qué encontró, qué no encontró, y qué no puede saber. Nunca infla certezas.

---

## Más detalles

¿Querés saber cómo correrlo en cron, qué hace en Claude.ai vs Claude Code, qué archivos crea por dentro, o cómo configurar variables de entorno? → Ver [DETAILS.md](DETAILS.md).

---

## Licencia

MIT. Ver [LICENSE](LICENSE).
