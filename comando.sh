source synopsys_tools.sh;
rm -rfv `ls |grep -v ".*\.sv\|.*\.sh"`;
vcs -Mupdate test_bench.sv  -o salida -full64 -debug_all -sverilog -l log_test +lint=TFIPC-L;

# ── Ejecución — modificar los plusargs aquí para cambiar el escenario ────────
# Escenario activo: prueba general con defaults
./salida
 
# ── Otros escenarios (descomentar el deseado y comentar el anterior) ─────────
 
# Overflow:
./salida +peso_lectura=0 +peso_escritura=100 +peso_lectura_escritura=0 +peso_reset=0 \
         +n_trans_min=20 +n_trans_max=40 +retardo_min=1 +retardo_max=2
 
# Underflow:
./salida +peso_lectura=100 +peso_escritura=0 +peso_lectura_escritura=0 +peso_reset=0
 
# Alta frecuencia de resets:
./salida +peso_reset=60 +peso_lectura=15 +peso_escritura=15 +peso_lectura_escritura=10
 
# Solo lectura-escritura simultánea:
./salida +peso_lectura=0 +peso_escritura=0 +peso_lectura_escritura=100 +peso_reset=0 \
         +retardo_min=8 +retardo_max=20
 
# Datos de valores específicos (bordes y potencias de 2):
./salida +datos_validos=0,1,2,127,128,32767,32768,65534,65535
 
# Rango continuo acotado (solo valores entre 100 y 200):
./salida +dato_min=100 +dato_max=200