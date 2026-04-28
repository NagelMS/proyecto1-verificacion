source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh;
rm -rfv `ls |grep -v ".*\.sv\|.*\.sh"`;

# ── Parámetros de compilación ─────────────────────────────────────────────────
# MODO_PARAMETROS: "default" usa los valores fijos de abajo.
#                  "random"  elige ancho y profundidad al azar entre opciones válidas.
MODO_PARAMETROS="default"

FIFO_WIDTH_DEFAULT=16
FIFO_DEPTH_DEFAULT=256

if [ "$MODO_PARAMETROS" = "random" ]; then
  WIDTHS=(8 16 32 64)
  DEPTHS=(4 8 16 32 64 128 256 512 1024 2048 4096)
  FIFO_WIDTH=${WIDTHS[$RANDOM % ${#WIDTHS[@]}]}
  FIFO_DEPTH=${DEPTHS[$RANDOM % ${#DEPTHS[@]}]}
else
  FIFO_WIDTH=$FIFO_WIDTH_DEFAULT
  FIFO_DEPTH=$FIFO_DEPTH_DEFAULT
fi

echo "Parámetros de compilación: width=${FIFO_WIDTH}  depth=${FIFO_DEPTH} ──"

vcs -Mupdate test_bench.sv -o salida -full64 -debug_all -sverilog -l log_test +lint=TFIPC-L \
    +define+FIFO_WIDTH=${FIFO_WIDTH}+FIFO_DEPTH=${FIFO_DEPTH};

# ── Ejecución — modificar los plusargs aquí para cambiar el escenario ────────
# Escenario activo: prueba general con defaults
./salida +ntb_random_seed_automatic
 
# -----------------------------------------------------------------------------
# CASO 1 — Llenado con máxima alternancia de patrones (0s, 5s, As, Fs)
#   Escribe exactamente depth=8 veces con los patrones 0x0000, 0x5555, 0xAAAA
#   y 0xFFFF intercalados para maximizar la alternancia de bits 0→1→0.
#   Sin lecturas ni resets. Retardo fijo de 1 ciclo.
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=0           +peso_escritura=100        \
#  +peso_lectura_escritura=0 +peso_reset=0              \
#  +n_trans_min=8            +n_trans_max=8             \
#  +datos_validos=0,21845,43690,65535                   \
#  +retardo_min=1            +retardo_max=1
 
# -----------------------------------------------------------------------------
# CASO 2 — Overflow
#   Solo escrituras en cantidad mayor que depth (entre 12 y 20).
#   Retardos mínimos para la mayor presión posible sobre la FIFO llena.
#   Datos en todo el rango.
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=0           +peso_escritura=100        \
#  +peso_lectura_escritura=0 +peso_reset=0              \
#  +n_trans_min=12           +n_trans_max=20            \
#  +dato_min=0               +dato_max=65535            \
#  +retardo_min=1            +retardo_max=2
 
# -----------------------------------------------------------------------------
# CASO 3 — Underflow
#   Solo lecturas sobre una FIFO que comienza vacía.
#   El checker registra cada intento como underflow.
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=100         +peso_escritura=0          \
#  +peso_lectura_escritura=0 +peso_reset=0              \
#  +n_trans_min=8            +n_trans_max=16            \
#  +dato_min=0               +dato_max=65535            \
#  +retardo_min=2            +retardo_max=5
 
# -----------------------------------------------------------------------------
# CASO 4 — Pop y Push simultáneo — carga BAJA
#   Solo lectura_escritura con retardos largos (baja densidad de eventos).
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=0           +peso_escritura=0          \
#  +peso_lectura_escritura=100 +peso_reset=0            \
#  +n_trans_min=8            +n_trans_max=12            \
#  +dato_min=0               +dato_max=65535            \
#  +retardo_min=10           +retardo_max=20
 
# -----------------------------------------------------------------------------
# CASO 5 — Pop y Push simultáneo — carga MEDIA
#   Solo lectura_escritura con retardos medios.
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=0           +peso_escritura=0          \
#  +peso_lectura_escritura=100 +peso_reset=0            \
#  +n_trans_min=8            +n_trans_max=16            \
#  +dato_min=0               +dato_max=65535            \
#  +retardo_min=4            +retardo_max=8
 
# -----------------------------------------------------------------------------
# CASO 6 — Pop y Push simultáneo — carga ALTA
#   Solo lectura_escritura con retardos mínimos (máxima densidad de eventos).
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=0           +peso_escritura=0          \
#  +peso_lectura_escritura=100 +peso_reset=0            \
#  +n_trans_min=16           +n_trans_max=32            \
#  +dato_min=0               +dato_max=65535            \
#  +retardo_min=1            +retardo_max=2
 
# -----------------------------------------------------------------------------
# CASO 7 — Reset con FIFO llena
#   Pesos sesgados a escritura para mantener la FIFO llena entre resets.
#   Alta proporción de resets para que la mayoría ocurran con FIFO saturada.
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=5           +peso_escritura=45         \
#  +peso_lectura_escritura=0 +peso_reset=50             \
#  +n_trans_min=16           +n_trans_max=24            \
#  +dato_min=0               +dato_max=65535            \
#  +retardo_min=1            +retardo_max=3
 
# -----------------------------------------------------------------------------
# CASO 8 — Reset con FIFO vacía
#   Solo resets, sin ninguna escritura previa. La FIFO siempre está vacía
#   cuando llega el reset.
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=0           +peso_escritura=0          \
#  +peso_lectura_escritura=0 +peso_reset=100            \
#  +n_trans_min=8            +n_trans_max=16            \
#  +dato_min=0               +dato_max=65535            \
#  +retardo_min=2            +retardo_max=6
 
# -----------------------------------------------------------------------------
# CASO 9 — Reset con FIFO a la mitad (depth/2 = 4 entradas ocupadas)
#   Escrituras > lecturas para mantener ocupación media antes de cada reset.
#   Reset frecuente (peso 40) para que la mayoría ocurran con FIFO semi-llena.
# -----------------------------------------------------------------------------
#./salida \
#  +peso_lectura=15          +peso_escritura=45         \
#  +peso_lectura_escritura=0 +peso_reset=40             \
#  +n_trans_min=12           +n_trans_max=20            \
#  +dato_min=0               +dato_max=65535            \
#  +retardo_min=2            +retardo_max=5