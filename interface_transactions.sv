//////////////////////////////////////////////////////////////
// Definición del tipo de transacciones posibles en la fifo //
//////////////////////////////////////////////////////////////

typedef enum { lectura, escritura, lectura_escritura, reset } tipo_trans;

/////////////////////////////////////////////////////////////////////////////////////////
// Transacción: representa las transacciones que entran y salen de la FIFO.            //
//                                                                                     //
// Todos los parámetros de aleatorización se controlan desde plusargs en comando.sh.   //
// Si no se pasa un plusarg se usa el valor por defecto original.                      //
//                                                                                     //
// ── Plusargs disponibles ────────────────────────────────────────────────────────── //
//                                                                                     //
//  Retardo entre transacciones:                                                       //
//    +retardo_min=<N>              Mínimo ciclos de retardo        (default: 1)       //
//    +retardo_max=<N>              Máximo ciclos de retardo        (default: 10)      //
//                                                                                     //
//  Conjunto de datos válidos (dos modos, mutuamente excluyentes):                     //
//                                                                                     //
//    Modo rango (default):                                                             //
//      +dato_min=<N>               Extremo inferior del rango     (default: 0)        //
//      +dato_max=<N>               Extremo superior del rango     (default: 2^w - 1)  //
//      El constructor rellena el array con todos los enteros en [dato_min, dato_max]. //
//                                                                                     //
//    Modo lista (tiene prioridad si se pasa):                                         //
//      +datos_validos=<N>,<N>,...  Lista de valores discretos separados por coma.     //
//      Permite escoger valores específicos no necesariamente contiguos.               //
//      Ejemplo: +datos_validos=0,255,1024,65535                                       //
//      Cuando se usa este plusarg, dato_min y dato_max se ignoran.                    //
//                                                                                     //
//  Distribución de tipos de transacción (pesos enteros proporcionales):               //
//    +peso_lectura=<N>             (default: 30)                                      //
//    +peso_escritura=<N>           (default: 30)                                      //
//    +peso_lectura_escritura=<N>   (default: 30)                                      //
//    +peso_reset=<N>               (default: 10)                                      //
//    Poner un peso en 0 excluye completamente ese tipo.                               //
//                                                                                     //
// ── Ejemplos de uso en comando.sh ───────────────────────────────────────────────── //
//                                                                                     //
//  # Overflow (solo escrituras, retardos mínimos):                                    //
//  ./salida +peso_lectura=0 +peso_escritura=100 \                                     //
//           +peso_lectura_escritura=0 +peso_reset=0 \                                 //
//           +retardo_min=1 +retardo_max=2 +n_trans_min=20 +n_trans_max=30             //
//                                                                                     //
//  # Datos de valores específicos (ej. bordes y potencias de 2):                      //
//  ./salida +datos_validos=0,1,2,127,128,254,255                                      //
//                                                                                     //
//  # Rango continuo acotado:                                                          //
//  ./salida +dato_min=100 +dato_max=200                                               //
//                                                                                     //
/////////////////////////////////////////////////////////////////////////////////////////

class trans_fifo #(parameter width = 16);
  rand int             retardo;    // retardo en ciclos antes de ejecutar la transacción
  rand bit [width-1:0] dato;       // dato de entrada al DUT
  bit  [width-1:0]     dato_leido; // dato de salida del DUT (no aleatorio)
  int                  tiempo;
  rand tipo_trans      tipo;

  // Rangos de retardo leídos desde plusargs
  int retardo_min, retardo_max;

  // Datos: dos constraints mutuamente excluyentes, activados desde el constructor.
  //
  //   +datos_validos=v0,v1,...  → c_dato_lista ON,  c_dato_rango OFF
  //                                valores discretos no contiguos
  //   +dato_min=N +dato_max=M   → c_dato_rango ON,  c_dato_lista OFF
  //                                rango continuo [N:M]
  //   (ninguno)                 → c_dato_rango ON  con [0 : 2^width-1]
  //
  // El constructor activa el modo correcto con constraint_mode().
  // Externamente el comportamiento es un caso general único.
  bit [width-1:0] dato_min_r, dato_max_r;   // usados por c_dato_rango
  bit [width-1:0] datos_lista[$];           // usados por c_dato_lista

  // Pesos de tipo leídos desde plusargs
  int peso_lectura, peso_escritura, peso_lectura_escritura, peso_reset;

  // ------------------------------------------------------------------
  // Constraint de retardo: [retardo_min, retardo_max]
  // ------------------------------------------------------------------
  constraint c_retardo {
    retardo >= retardo_min;
    retardo <= retardo_max;
  }

  // ------------------------------------------------------------------
  // Constraint modo rango: dato en [dato_min_r, dato_max_r].
  // Activo por defecto. El solver trabaja con los bounds directamente —
  // sin arrays, sin loops.
  // ------------------------------------------------------------------
  constraint c_dato_rango {
    dato >= dato_min_r;
    dato <= dato_max_r;
  }

  // ------------------------------------------------------------------
  // Constraint modo lista: dato elegido entre valores discretos.
  // Desactivado por defecto. Se activa solo con +datos_validos.
  // ------------------------------------------------------------------
  constraint c_dato_lista {
    dato inside {datos_lista};
  }

  // ------------------------------------------------------------------
  // Constraint de tipo: distribución weighted por pesos desde plusargs.
  // Peso = 0 excluye ese tipo de la aleatorización.
  // ------------------------------------------------------------------
  constraint c_tipo {
    tipo dist {
      lectura           := peso_lectura,
      escritura         := peso_escritura,
      lectura_escritura := peso_lectura_escritura,
      reset             := peso_reset
    };
  }

  // ------------------------------------------------------------------
  // Constructor: lee plusargs y activa el constraint de dato correcto.
  //
  //   +datos_validos=v0,v1,...  → c_dato_lista ON,  c_dato_rango OFF
  //   +dato_min=N +dato_max=M   → c_dato_rango ON,  c_dato_lista OFF
  //   (ninguno)                 → c_dato_rango ON  con [0 : 2^width-1]
  // ------------------------------------------------------------------
  function new(int ret=0, bit[width-1:0] dto=0, int tmp=0, tipo_trans tpo=lectura);
    string           lista_str;
    string           token;
    int              coma_pos;
    longint lval;

    this.retardo    = ret;
    this.dato       = dto;
    this.dato_leido = 0;
    this.tiempo     = tmp;
    this.tipo       = tpo;
    this.datos_lista.delete();

    // ── Retardo ──────────────────────────────────────────────────────
    if (!$value$plusargs("retardo_min=%d", this.retardo_min)) this.retardo_min = 1;
    if (!$value$plusargs("retardo_max=%d", this.retardo_max)) this.retardo_max = 10;

    // ── Modo de dato ──────────────────────────────────────────────────
    if ($value$plusargs("datos_validos=%s", lista_str)) begin
      // Modo lista: parsear "v0,v1,..." y cargar datos_lista[]
      c_dato_rango.constraint_mode(0);
      c_dato_lista.constraint_mode(1);
      while (lista_str.len() > 0) begin
        coma_pos = -1;
        for (int i = 0; i < lista_str.len(); i++) begin
          if (lista_str[i] == ",") begin coma_pos = i; break; end
        end
        if (coma_pos >= 0) begin
          token     = lista_str.substr(0, coma_pos - 1);
          lista_str = lista_str.substr(coma_pos + 1, lista_str.len() - 1);
        end else begin
          token     = lista_str;
          lista_str = "";
        end
        lval = longint'(token.atoi());
        this.datos_lista.push_back(lval[width-1:0]);
      end
    end else begin
      // Modo rango: solo se leen los bounds, sin generar ningún array
      c_dato_lista.constraint_mode(0);
      c_dato_rango.constraint_mode(1);
      if (!$value$plusargs("dato_min=%d", this.dato_min_r)) this.dato_min_r = '0;
      if (!$value$plusargs("dato_max=%d", this.dato_max_r)) this.dato_max_r = '1;
    end

    // ── Pesos de tipo ─────────────────────────────────────────────────
    if (!$value$plusargs("peso_lectura=%d",          this.peso_lectura))          this.peso_lectura          = 30;
    if (!$value$plusargs("peso_escritura=%d",         this.peso_escritura))         this.peso_escritura         = 30;
    if (!$value$plusargs("peso_lectura_escritura=%d", this.peso_lectura_escritura)) this.peso_lectura_escritura = 30;
    if (!$value$plusargs("peso_reset=%d",             this.peso_reset))             this.peso_reset             = 10;
  endfunction

  function void clean();
    this.retardo    = 0;
    this.dato       = 0;
    this.dato_leido = 0;
    this.tiempo     = 0;
    this.tipo       = lectura;
  endfunction

  function trans_fifo #(width) copy();
    trans_fifo #(width) c = new();
    c.retardo                = this.retardo;
    c.dato                   = this.dato;
    c.dato_leido             = this.dato_leido;
    c.tiempo                 = this.tiempo;
    c.tipo                   = this.tipo;
    c.retardo_min            = this.retardo_min;
    c.retardo_max            = this.retardo_max;
    c.dato_min_r             = this.dato_min_r;
    c.dato_max_r             = this.dato_max_r;
    c.datos_lista            = this.datos_lista;
    c.peso_lectura           = this.peso_lectura;
    c.peso_escritura         = this.peso_escritura;
    c.peso_lectura_escritura = this.peso_lectura_escritura;
    c.peso_reset             = this.peso_reset;
    c.c_dato_rango.constraint_mode(this.c_dato_rango.constraint_mode());
    c.c_dato_lista.constraint_mode(this.c_dato_lista.constraint_mode());
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

///////////////////////////////////////////////////////////////////////////////////////
// Clase auxiliar para obtener un typedef de mailbox parametrizado por ancho         //
///////////////////////////////////////////////////////////////////////////////////////
class fifo_pkg #(parameter width = 16);
  typedef mailbox #(trans_fifo #(width)) mbx_t;
endclass


////////////////////////////////////////////////////////////////
// Interface: Esta es la interface que se conecta con la FIFO //
////////////////////////////////////////////////////////////////

interface fifo_if #(parameter width = 16) (
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
// Objeto de transacción usado en el scoreboard   //
////////////////////////////////////////////////////

class trans_sb #(parameter width = 16);
  bit [width-1:0] dato_enviado;
  int tiempo_push;
  int tiempo_pop;
  bit completado;
  bit overflow;
  bit underflow;
  bit reset;
  int latencia;

  function void clean();
    this.dato_enviado = 0;
    this.tiempo_push  = 0;
    this.tiempo_pop   = 0;
    this.completado   = 0;
    this.overflow     = 0;
    this.underflow    = 0;
    this.reset        = 0;
    this.latencia     = 0;
  endfunction

  task calc_latencia;
    this.latencia = this.tiempo_pop - this.tiempo_push;
  endtask

  function void print(string tag);
    $display("[%g] %s dato=%h,t_push=%g,t_pop=%g,cmplt=%g,ovrflw=%g,undrflw=%g,rst=%g,ltncy=%g",
             $time, tag,
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
// Definición de estructura para generar comandos hacia el scoreboard  //
/////////////////////////////////////////////////////////////////////////
typedef enum {retardo_promedio, reporte} solicitud_sb;

///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes                                                            //
///////////////////////////////////////////////////////////////////////////////////////
// trans_fifo_mbx reemplazado por fifo_pkg #(.width(W))::mbx_t para soporte de cualquier ancho
typedef mailbox #(trans_sb)      trans_sb_mbx;
typedef mailbox #(solicitud_sb)  comando_test_sb_mbx;
