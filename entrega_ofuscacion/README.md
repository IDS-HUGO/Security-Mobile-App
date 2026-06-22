# Práctica de ofuscación de código — Entregables

Carpeta de entrega de la práctica **"Ofuscación de código en aplicaciones móviles"**
sobre el proyecto Flutter `appmobile_security`.

## Contenido de esta carpeta

| Archivo | Descripción |
|---|---|
| `reporte_ofuscacion.tex` | Documento de investigación + práctica en LaTeX (portada, marco teórico, práctica, tabla comparativa, conclusiones y preguntas de reflexión). |
| `README.md` | Esta guía (procedimiento y qué capturas tomar). |
| `analisis/` | Salidas reales del análisis con JADX (listas de clases normal vs. ofuscada). |
| `capturas/` | **Coloca aquí tus capturas de pantalla** (ver lista abajo). |

> Los **archivos de configuración** usados por la práctica están en el propio
> proyecto (no se duplican aquí):
> - `android/app/build.gradle.kts` — activación condicional de R8.
> - `android/app/proguard-rules.pro` — reglas `-keep`.

## 1. Compilar el reporte LaTeX

```bash
cd entrega_ofuscacion
pdflatex reporte_ofuscacion.tex
pdflatex reporte_ofuscacion.tex   # 2.ª pasada para el índice y referencias cruzadas
```

Antes de compilar, edita en el `.tex` los datos de la portada (universidad,
matrícula, docente): están como comandos `\newcommand` al inicio del archivo.

## 2. Generar las dos versiones del APK

### Versión NORMAL (sin ofuscar)

```powershell
flutter clean
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

### Versión OFUSCADA (R8 + ofuscación de Dart)

```powershell
# PowerShell (Windows)
$env:ORG_GRADLE_PROJECT_obfuscate="true"
flutter build apk --release --obfuscate --split-debug-info=build/symbols
$env:ORG_GRADLE_PROJECT_obfuscate=$null   # limpiar la variable
```

```bash
# Bash (Linux/macOS)
ORG_GRADLE_PROJECT_obfuscate=true \
  flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

> Renombra cada APK para no confundirlas, p. ej. `app-normal.apk` y
> `app-ofuscada.apk`, antes de analizarlas.

## 3. Analizar los APK

### JADX (decompilar a Java)

```powershell
# CLI (genera código fuente reconstruido en una carpeta)
C:\Users\<tu_usuario>\tools\jadx\bin\jadx.bat -d salida_normal   app-normal.apk
C:\Users\<tu_usuario>\tools\jadx\bin\jadx.bat -d salida_ofuscada app-ofuscada.apk

# GUI (para tomar capturas del árbol de clases)
C:\Users\<tu_usuario>\tools\jadx\bin\jadx-gui.bat
```

### APKTool (estructura, smali y recursos)

```bash
apktool d app-normal.apk   -o apktool_normal
apktool d app-ofuscada.apk -o apktool_ofuscada
```

### Bytecode Viewer

Abrir el `.apk` desde la interfaz gráfica y comparar los decompiladores
(CFR / Procyon / Fernflower) y la vista smali.

## 4. Capturas de pantalla a incluir (entregable)

Guárdalas en `capturas/` y enlázalas en el `.tex` (hay recuadros marcados):

1. `01_gradle_config.png` — `build.gradle.kts` mostrando `isMinifyEnabled`.
2. `02_build_output.png` — salida de `flutter build apk` (ambas versiones).
3. `03_jadx_normal.png` — árbol de clases de la APK **normal** en JADX.
4. `04_jadx_ofuscada.png` — árbol de clases de la APK **ofuscada** en JADX.
5. `05_tamanos.png` — tamaños de ambos APK en el explorador de archivos.
6. (Opcional) `06_apktool.png`, `07_bytecodeviewer.png`.

## 5. Resumen de la comparación (datos medidos en esta práctica)

| Criterio | APK normal | APK ofuscada |
|---|---|---|
| Tamaño del APK | 53.28 MB | 46.65 MB (−6.63 MB, ~12.4%) |
| Archivos `.dex` | 2 (12.80 MB) | 1 (2.57 MB, ~80% menos) |
| Clases (JADX) | 3 529 | 1 587 (~55% menos) |
| `mapping.txt` (R8) | no se genera | 124 011 líneas, 3 559 clases |
| Nombres de clases | descriptivos | `a.a`, `b.q`, `p2.d`… |
| Símbolos Dart en `libapp.so` | visibles (`grep`) | 0 coincidencias |
| Lógica de negocio | fácil de leer | difícil de reconstruir |

Detalle completo en la carpeta [`analisis/`](analisis/):
`comparacion.txt`, `ejemplos_renombrado.txt`, `mapping.txt`,
`clases_normal.txt`, `clases_ofuscada.txt`.
