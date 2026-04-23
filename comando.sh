source synopsys_tools.sh;
rm -rfv `ls |grep -v ".*\.sv\|.*\.sh"`;
vcs -Mupdate test_bench.sv  -o salida -full64 -debug_all -sverilog -l log_test +lint=TFIPC-L;

# Correr cada caso de esquina
./salida +patron_alternancia +pa_ciclos=3
./salida +overflow_test +overflow_extra=6
./salida +underflow_test +underflow_extra=4
./salida +simultaneous_test +sim_regimen=bajo
./salida +simultaneous_test +sim_regimen=medio +sim_n=20
./salida +simultaneous_test +sim_regimen=alto
./salida +reset_llena
./salida +reset_vacia
./salida +reset_mitad
