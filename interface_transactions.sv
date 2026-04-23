//////////////////////////////////////////////////////////////
// Definición del tipo de transacciones posibles en la fifo //
//////////////////////////////////////////////////////////////
 
typedef enum { lectura, escritura, lectura_escritura, reset} tipo_trans;
 
/////////////////////////////////////////////////////////////////////////////////////////
//Transacción: este objeto representa las transacciones que entran y salen de la fifo. //
/////////////////////////////////////////////////////////////////////////////////////////
class trans_fifo #(parameter width = 16);
  rand int retardo;          // retardo en ciclos antes de ejecutar la transacción
  rand bit[width-1:0] dato;  // dato de entrada al DUT (escritura o lectura_escritura)
  bit[width-1:0] dato_leido; // dato de salida del DUT (lectura o lectura_escritura), no aleatorio
  int tiempo;
  rand tipo_trans tipo;
  int max_retardo;
 
  constraint const_retardo {retardo < max_retardo; retardo > 0;}
 
  function new(int ret =0, bit[width-1:0] dto=0, int tmp=0, tipo_trans tpo=lectura, int mx_rtrd=10);
    this.retardo    = ret;
    this.dato       = dto;
    this.dato_leido = 0;
    this.tiempo     = tmp;
    this.tipo       = tpo;
    this.max_retardo = mx_rtrd;
  endfunction
 
  function clean;
    this.retardo    = 0;
    this.dato       = 0;
    this.dato_leido = 0;
    this.tiempo     = 0;
    this.tipo       = lectura;
  endfunction
 
  function trans_fifo copy();
    trans_fifo #(width) c = new();
    c.retardo     = this.retardo;
    c.dato        = this.dato;
    c.dato_leido  = this.dato_leido;
    c.tiempo      = this.tiempo;
    c.tipo        = this.tipo;
    c.max_retardo = this.max_retardo;
    return c;
  endfunction
 
  function void print(string tag = "");
    if (tipo == lectura_escritura)
      $display("[%g] %s Tiempo=%g Tipo=%s Retardo=%g dato_in=0x%h dato_out=0x%h",
               $time, tag, tiempo, this.tipo, this.retardo, this.dato, this.dato_leido);
    else
      $display("[%g] %s Tiempo=%g Tipo=%s Retardo=%g dato=0x%h",
               $time, tag, tiempo, this.tipo, this.retardo, this.dato);
  endfunction
endclass
 
 
////////////////////////////////////////////////////////////////
// Interface: Esta es la interface que se conecta con la FIFO //
////////////////////////////////////////////////////////////////
 
interface fifo_if #(parameter width =16) (
  input clk
);
  logic rst;
  logic pndng;
  logic full;
  logic push;
  logic pop;
  logic [width-1:0] dato_in; 
  logic [width-1:0] dato_out;
 
  endinterface
 
 
////////////////////////////////////////////////////
// Objeto de transacción usado en el scoreboard  //
////////////////////////////////////////////////////
 
class trans_sb #(parameter width=16);
  bit [width-1:0] dato_enviado;
  int tiempo_push;
  int tiempo_pop;
  bit completado;
  bit overflow;
  bit underflow;
  bit reset;
  int latencia;
  
  function clean();
    this.dato_enviado = 0;
    this.tiempo_push = 0;
    this.tiempo_pop = 0;
    this.completado = 0;
    this.overflow = 0;
    this.underflow = 0;
    this.reset = 0;
    this.latencia = 0;
  endfunction
 
  task calc_latencia;
    this.latencia = this.tiempo_pop - this.tiempo_push;
  endtask
  
  function print (string tag);
    $display("[%g] %s dato=%h,t_push=%g,t_pop=%g,cmplt=%g,ovrflw=%g,undrflw=%g,rst=%g,ltncy=%g", 
             $time,
             tag, 
             this.dato_enviado, 
             this.tiempo_push,
             this.tiempo_pop,
             this.completado,
             this.overflow,
             this.underflow,
             this.reset,
             this.latencia);
  endfunction
endclass
 
/////////////////////////////////////////////////////////////////////////
// Definición de estructura para generar comandos hacia el scoreboard //
/////////////////////////////////////////////////////////////////////////
typedef enum {retardo_promedio,reporte} solicitud_sb;
 
/////////////////////////////////////////////////////////////////////////
// Definición de estructura para generar comandos hacia el generador     //
/////////////////////////////////////////////////////////////////////////
typedef enum {
  caso_general,          // Transacciones completamente aleatorias
  llenado_aleatorio,     // N escrituras seguidas de N lecturas
  patron_alternancia,    // Llena la FIFO con 0s, 5s, As y Fs intercalados
  overflow_test,         // Escribe depth+N elementos (fuerza overflow)
  underflow_test,        // Lee con la FIFO vacía (fuerza underflow)
  simultaneous_test,     // Pop y push simultáneos con retardo bajo/medio/alto
  reset_llena,           // Reset cuando la FIFO está llena
  reset_vacia,           // Reset cuando la FIFO está vacía
  reset_mitad            // Reset cuando la FIFO está por la mitad
} instrucciones_gen;
 
///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes de tipo definido trans_fifo para comunicar las interfaces //
///////////////////////////////////////////////////////////////////////////////////////
typedef mailbox #(trans_fifo) trans_fifo_mbx;
 
///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes de tipo definido trans_fifo para comunicar las interfaces //
///////////////////////////////////////////////////////////////////////////////////////
typedef mailbox #(trans_sb) trans_sb_mbx;
 
///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes de tipo definido trans_fifo para comunicar las interfaces //
///////////////////////////////////////////////////////////////////////////////////////
typedef mailbox #(solicitud_sb) comando_test_sb_mbx;
 
///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes de tipo definido trans_fifo para comunicar las interfaces //
///////////////////////////////////////////////////////////////////////////////////////
typedef mailbox #(instrucciones_gen) comando_test_gen_mbx;