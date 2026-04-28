////////////////////////////////////////////////////////////////////////////////////////////
// Generador: produce transacciones aleatorias hacia el agente.                          //
//                                                                                        //
// Existe un único escenario de prueba. Todos los parámetros de aleatorización se        //
// definen exclusivamente desde plusargs en comando.sh.                                   //
//                                                                                        //
// ── Plusargs de cantidad de transacciones ────────────────────────────────────────── //
//                                                                                        //
//   +n_trans_min=<N>   Mínimo de transacciones a generar   (default: depth   =  8)     //
//   +n_trans_max=<N>   Máximo de transacciones a generar   (default: 4*depth = 32)     //
//                                                                                        //
// Los parámetros de tipo, retardo y dato se controlan desde interface_transactions.sv   //
// mediante sus propios plusargs (ver ese archivo para la lista completa).               //
////////////////////////////////////////////////////////////////////////////////////////////
 
class generador #(parameter width = 16, parameter depth = 8);
  trans_fifo_mbx gen_agent_mbx;
  trans_fifo #(.width(width)) transaccion;
 
  function new;
  endfunction
 
  task run;
    int n_trans;
    int n_trans_min, n_trans_max;
 
    // Leer rango de cantidad de transacciones desde plusargs
    if (!$value$plusargs("n_trans_min=%d", n_trans_min)) n_trans_min = depth;
    if (!$value$plusargs("n_trans_max=%d", n_trans_max)) n_trans_max = 4 * depth;
 
    $display("[%g]  Generador inicializado — n_trans en [%0d, %0d]",
             $time, n_trans_min, n_trans_max);
 
    // Generar el lote de transacciones
    n_trans = $urandom_range(n_trans_min, n_trans_max);
    $display("[%g]  Generador: generando %0d transacciones", $time, n_trans);
 
    for (int i = 0; i < n_trans; i++) begin
      transaccion = new();                  // lee todos los plusargs en el constructor
      void'(transaccion.randomize());       // aplica constraints definidos por plusargs
      transaccion.print("Generador: transaccion creada");
      gen_agent_mbx.put(transaccion);
    end
 
    $display("[%g]  Generador: lote de %0d transacciones enviado", $time, n_trans);
  endtask
endclass