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

# =============================================================================
# ── Valores derivados de los parámetros de compilación ───────────────────────
# Se calculan en bash para pasarlos como plusargs en runtime.
#
#   DATO_MAX  = 2^FIFO_WIDTH - 1   valor máximo para el ancho actual
#   DEPTH_X2  = FIFO_DEPTH * 2     cota superior para casos de overflow/stress
#   DEPTH_D2  = FIFO_DEPTH / 2     mitad de la FIFO para el caso 9
#   PAT_0/5/A/F = patrones de máxima alternancia calculados para FIFO_WIDTH bits
#     0s = 000...0  (todos cero)
#     5s = 010101.. (LSB=1, bits pares encendidos)
#     As = 101010.. (complemento de 5s)
#     Fs = 111...1  (todos uno)
# =============================================================================
DATO_MAX=$(( (1 << FIFO_WIDTH) - 1 ))
DEPTH_X2=$(( FIFO_DEPTH * 2 ))
DEPTH_D2=$(( FIFO_DEPTH / 2 ))
 
PAT_0=0
PAT_F=$DATO_MAX
 
PAT_5=0
for (( b=0; b<FIFO_WIDTH; b+=2 )); do
  PAT_5=$(( PAT_5 | (1 << b) ))
done
 
PAT_A=$(( DATO_MAX & ~PAT_5 ))
 
echo "── Valores derivados: dato_max=${DATO_MAX}  depth/2=${DEPTH_D2}  depth*2=${DEPTH_X2}"
echo "── Patrones alternancia: 0s=${PAT_0}  5s=${PAT_5}  As=${PAT_A}  Fs=${PAT_F}"
 
# =============================================================================
# ── Casos de esquina — descomentar UNO para ejecutarlo ───────────────────────
# Todos los parámetros se especifican explícitamente para evitar heredar
# valores de corridas anteriores.
# =============================================================================
 
# Escenario activo: prueba general con defaults
./salida +ntb_random_seed_automatic
 
# -----------------------------------------------------------------------------
# CASO 1 — Llenado con máxima alternancia de patrones (0s, 5s, As, Fs)
#   Escribe exactamente depth veces con los 4 patrones de máxima alternancia
#   calculados dinámicamente para FIFO_WIDTH. Sin lecturas ni resets.
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=0           +peso_escritura=100        \
#  +peso_lectura_escritura=0 +peso_reset=0              \
#  +n_trans_min=${FIFO_DEPTH} +n_trans_max=${FIFO_DEPTH} \
#  +datos_validos=${PAT_0},${PAT_5},${PAT_A},${PAT_F}  \
#  +retardo_min=1            +retardo_max=1
 
# -----------------------------------------------------------------------------
# CASO 2 — Overflow
#   Solo escrituras en cantidad mayor que depth (entre depth+1 y depth*2).
#   Retardos mínimos para la mayor presión posible sobre la FIFO llena.
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=0           +peso_escritura=100        \
#  +peso_lectura_escritura=0 +peso_reset=0              \
#  +n_trans_min=$(( FIFO_DEPTH + 1 )) +n_trans_max=${DEPTH_X2} \
#  +dato_min=0               +dato_max=${DATO_MAX}      \
#  +retardo_min=1            +retardo_max=2
 
# -----------------------------------------------------------------------------
# CASO 3 — Underflow
#   Solo lecturas sobre una FIFO que comienza vacía.
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=100         +peso_escritura=0          \
#  +peso_lectura_escritura=0 +peso_reset=0              \
#  +n_trans_min=${FIFO_DEPTH} +n_trans_max=${DEPTH_X2}  \
#  +dato_min=0               +dato_max=${DATO_MAX}      \
#  +retardo_min=2            +retardo_max=5
 
# -----------------------------------------------------------------------------
# CASO 4 — Pop y Push simultáneo — carga BAJA
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=0           +peso_escritura=0          \
#  +peso_lectura_escritura=100 +peso_reset=0            \
#  +n_trans_min=${FIFO_DEPTH} +n_trans_max=$(( FIFO_DEPTH + DEPTH_D2 )) \
#  +dato_min=0               +dato_max=${DATO_MAX}      \
#  +retardo_min=10           +retardo_max=20
 
# -----------------------------------------------------------------------------
# CASO 5 — Pop y Push simultáneo — carga MEDIA
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=0           +peso_escritura=0          \
#  +peso_lectura_escritura=100 +peso_reset=0            \
#  +n_trans_min=${FIFO_DEPTH} +n_trans_max=${DEPTH_X2}  \
#  +dato_min=0               +dato_max=${DATO_MAX}      \
#  +retardo_min=4            +retardo_max=8
 
# -----------------------------------------------------------------------------
# CASO 6 — Pop y Push simultáneo — carga ALTA
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=0           +peso_escritura=0          \
#  +peso_lectura_escritura=100 +peso_reset=0            \
#  +n_trans_min=${DEPTH_X2}  +n_trans_max=$(( DEPTH_X2 * 2 )) \
#  +dato_min=0               +dato_max=${DATO_MAX}      \
#  +retardo_min=1            +retardo_max=2
 
# -----------------------------------------------------------------------------
# CASO 7 — Reset con FIFO llena
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=5           +peso_escritura=45         \
#  +peso_lectura_escritura=0 +peso_reset=50             \
#  +n_trans_min=${DEPTH_X2}  +n_trans_max=$(( DEPTH_X2 * 2 )) \
#  +dato_min=0               +dato_max=${DATO_MAX}      \
#  +retardo_min=1            +retardo_max=3
 
# -----------------------------------------------------------------------------
# CASO 8 — Reset con FIFO vacía
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=0           +peso_escritura=0          \
#  +peso_lectura_escritura=0 +peso_reset=100            \
#  +n_trans_min=${FIFO_DEPTH} +n_trans_max=${DEPTH_X2}  \
#  +dato_min=0               +dato_max=${DATO_MAX}      \
#  +retardo_min=2            +retardo_max=6
 
# -----------------------------------------------------------------------------
# CASO 9 — Reset con FIFO a la mitad (depth/2 entradas ocupadas)
# -----------------------------------------------------------------------------
#./salida +ntb_random_seed_automatic \
#  +peso_lectura=15          +peso_escritura=45         \
#  +peso_lectura_escritura=0 +peso_reset=40             \
#  +n_trans_min=${FIFO_DEPTH} +n_trans_max=${DEPTH_X2}  \
#  +dato_min=0               +dato_max=${DATO_MAX}      \
#  +retardo_min=2            +retardo_max=5