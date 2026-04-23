////////////////////////////////////////////////////////////////////////////////////////////////////
// Generador: maneja secuencias de transacciones para el escenario de prueba.                   //
//                                                                                              //
//  caso_general:       Transacciones con tipo, dato y retardo completamente aleatorios.        //
//  llenado_aleatorio:  N escrituras seguidas de N lecturas (N aleatorio).                      //
//  patron_alternancia: Llena la FIFO con 0x0000, 0x5555, 0xAAAA, 0xFFFF intercalados.         //
//  overflow_test:      Escribe depth+extra elementos para forzar condición de overflow.        //
//  underflow_test:     Lee con la FIFO vacía para forzar condición de underflow.               //
//  simultaneous_test:  Pop y push simultáneos en régimen bajo, medio o alto.                   //
//  reset_llena:        Reset cuando la FIFO está completamente llena.                          //
//  reset_vacia:        Reset cuando la FIFO está completamente vacía.                          //
//  reset_mitad:        Reset cuando la FIFO tiene depth/2 elementos.                           //
////////////////////////////////////////////////////////////////////////////////////////////////////
 
class generador #(parameter width = 16, parameter depth = 8);
  fifo_pkg #(.width(width))::mbx_t gen_agent_mbx;
  comando_test_gen_mbx test_gen_mbx;
  instrucciones_gen    instruccion;
  trans_fifo #(.width(width)) transaccion;
 
  function new;
  endfunction
 
  // -----------------------------------------------------------------------
  // Tarea auxiliar: crea una transaccion de escritura con dato y retardo fijos
  // -----------------------------------------------------------------------
  task automatic crear_escritura(bit [width-1:0] dato_val, int ret);
    transaccion = new;
    transaccion.tipo        = escritura;
    transaccion.dato        = dato_val;
    transaccion.retardo     = ret;
    transaccion.max_retardo = ret + 1;
    transaccion.print("Generador: escritura creada");
    gen_agent_mbx.put(transaccion);
  endtask
 
  // -----------------------------------------------------------------------
  // Tarea auxiliar: crea una transaccion de lectura con retardo fijo
  // -----------------------------------------------------------------------
  task automatic crear_lectura(int ret);
    transaccion = new;
    transaccion.tipo        = lectura;
    transaccion.dato        = 0;
    transaccion.retardo     = ret;
    transaccion.max_retardo = ret + 1;
    transaccion.print("Generador: lectura creada");
    gen_agent_mbx.put(transaccion);
  endtask
 
  // -----------------------------------------------------------------------
  // Tarea auxiliar: crea una transaccion de reset con retardo fijo
  // -----------------------------------------------------------------------
  task automatic crear_reset(int ret);
    transaccion = new;
    transaccion.tipo        = reset;
    transaccion.dato        = 0;
    transaccion.retardo     = ret;
    transaccion.max_retardo = ret + 1;
    transaccion.print("Generador: reset creado");
    gen_agent_mbx.put(transaccion);
  endtask
 
  // -----------------------------------------------------------------------
  // Tarea auxiliar: crea una transaccion lectura_escritura con retardo fijo
  // -----------------------------------------------------------------------
  task automatic crear_lect_escr(bit [width-1:0] dato_val, int ret);
    transaccion = new;
    transaccion.tipo        = lectura_escritura;
    transaccion.dato        = dato_val;
    transaccion.retardo     = ret;
    transaccion.max_retardo = ret + 1;
    transaccion.print("Generador: lectura_escritura creada");
    gen_agent_mbx.put(transaccion);
  endtask
 
  // =========================================================================
  task run;
    int n_trans, mx_ret, extra;
    $display("[%g]  El generador fue inicializado", $time);
    forever begin
      #1
      if (test_gen_mbx.num() > 0) begin
        $display("[%g]  Generador: se recibe instruccion", $time);
        test_gen_mbx.get(instruccion);
        case (instruccion)
 
          // ------------------------------------------------------------------
          // CASO GENERAL: aleatorio puro
          // ------------------------------------------------------------------
          caso_general: begin
            n_trans = $urandom_range(depth, 4*depth);
            mx_ret  = $urandom_range(2, 8);
            $display("[%g]  Generador: caso_general n_trans=%0d max_retardo=%0d",
                     $time, n_trans, mx_ret);
            for (int i = 0; i < n_trans; i++) begin
              transaccion = new;
              transaccion.max_retardo = mx_ret;
              void'(transaccion.randomize());
              transaccion.print("Generador: caso_general - transaccion creada");
              gen_agent_mbx.put(transaccion);
            end
          end
 
          // ------------------------------------------------------------------
          // LLENADO ALEATORIO: N escrituras -> N lecturas
          // ------------------------------------------------------------------
          llenado_aleatorio: begin
            n_trans = $urandom_range(1, depth);
            mx_ret  = $urandom_range(2, 8);
            $display("[%g]  Generador: llenado_aleatorio n_trans=%0d max_retardo=%0d",
                     $time, n_trans, mx_ret);
            for (int i = 0; i < n_trans; i++) begin
              transaccion = new;
              transaccion.max_retardo = mx_ret;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: llenado_aleatorio - escritura creada");
              gen_agent_mbx.put(transaccion);
            end
            for (int i = 0; i < n_trans; i++) begin
              transaccion = new;
              transaccion.max_retardo = mx_ret;
              void'(transaccion.randomize());
              transaccion.tipo = lectura;
              transaccion.print("Generador: llenado_aleatorio - lectura creada");
              gen_agent_mbx.put(transaccion);
            end
          end
 
          // ------------------------------------------------------------------
          // PATRON ALTERNANCIA:
          //   Llena la FIFO con los patrones 0x0000, 0x5555, 0xAAAA, 0xFFFF
          //   intercalados posicion a posicion para maximizar la alternancia
          //   de bits adyacentes dentro de la FIFO. Luego la vacía completa.
          //
          //   Plusarg opcional: +pa_ciclos=N   (cuántas veces repetir, default 2)
          // ------------------------------------------------------------------
          patron_alternancia: begin
            int n_ciclos;
            bit [width-1:0] patrones[4];
 
            // Construir los 4 patrones para el ancho parametrizado
            for (int b = 0; b < width; b++) begin
              patrones[0][b] = 1'b0;                        // 0x0000...
              patrones[1][b] = (b % 2 == 0) ? 1'b1 : 1'b0; // 0x5555...
              patrones[2][b] = (b % 2 == 1) ? 1'b1 : 1'b0; // 0xAAAA...
              patrones[3][b] = 1'b1;                        // 0xFFFF...
            end
 
            if (!$value$plusargs("pa_ciclos=%d", n_ciclos))
              n_ciclos = 2;
 
            $display("[%g]  Generador: patron_alternancia depth=%0d ciclos=%0d",
                     $time, depth, n_ciclos);
 
            for (int c = 0; c < n_ciclos; c++) begin
              // Llenar la FIFO con patrones ciclando entre los 4
              for (int i = 0; i < depth; i++) begin
                crear_escritura(patrones[i % 4], 1);
              end
              // Vaciar la FIFO completamente
              for (int i = 0; i < depth; i++) begin
                crear_lectura(1);
              end
            end
          end
 
          // ------------------------------------------------------------------
          // OVERFLOW:
          //   Escribe depth + extra transacciones para provocar que el DUT
          //   intente escribir con la FIFO ya llena.
          //   Luego vacía la FIFO para dejar el ambiente limpio.
          //
          //   Plusarg opcional: +overflow_extra=N   (escrituras extra, default 4)
          // ------------------------------------------------------------------
          overflow_test: begin
            if (!$value$plusargs("overflow_extra=%d", extra))
              extra = 4;
 
            $display("[%g]  Generador: overflow_test depth=%0d extra=%0d",
                     $time, depth, extra);
 
            // Llenar la FIFO hasta capacity
            for (int i = 0; i < depth; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: overflow_test - llenando");
              gen_agent_mbx.put(transaccion);
            end
 
            // Intentar escribir más allá del límite
            for (int i = 0; i < extra; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: overflow_test - escritura en overflow");
              gen_agent_mbx.put(transaccion);
            end
 
            // Vaciar la FIFO para dejar el ambiente limpio
            for (int i = 0; i < depth; i++) begin
              crear_lectura(1);
            end
          end
 
          // ------------------------------------------------------------------
          // UNDERFLOW:
          //   Intenta leer 'extra' veces con la FIFO vacía.
          //   Luego escribe y lee depth/2 elementos para verificar recuperación.
          //
          //   Plusarg opcional: +underflow_extra=N  (lecturas de más, default 4)
          // ------------------------------------------------------------------
          underflow_test: begin
            if (!$value$plusargs("underflow_extra=%d", extra))
              extra = 4;
 
            $display("[%g]  Generador: underflow_test (FIFO vacia, %0d lecturas extra)",
                     $time, extra);
 
            // Intentar leer con la FIFO vacía
            for (int i = 0; i < extra; i++) begin
              crear_lectura(1);
            end
 
            // Verificar recuperación: escribir y leer depth/2 datos
            $display("[%g]  Generador: underflow_test - verificando recuperacion", $time);
            for (int i = 0; i < depth/2; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: underflow_test - escritura recuperacion");
              gen_agent_mbx.put(transaccion);
            end
            for (int i = 0; i < depth/2; i++) begin
              crear_lectura(1);
            end
          end
 
          // ------------------------------------------------------------------
          // SIMULTANEOUS (pop y push al mismo tiempo):
          //   Genera 'sim_n' transacciones lectura_escritura. El retardo entre
          //   cada una depende del régimen seleccionado:
          //     bajo  -> retardo fijo = 1 ciclo
          //     medio -> retardo aleatorio entre 3 y 5 ciclos
          //     alto  -> retardo aleatorio entre 7 y 9 ciclos
          //
          //   Plusarg: +sim_regimen=bajo|medio|alto   (default: bajo)
          //   Plusarg: +sim_n=N                       (cant. transacciones, default: depth)
          // ------------------------------------------------------------------
          simultaneous_test: begin
            string regimen_str;
            int ret_val, n_sim;
 
            if (!$value$plusargs("sim_regimen=%s", regimen_str))
              regimen_str = "bajo";
 
            if (!$value$plusargs("sim_n=%d", n_sim))
              n_sim = depth;
 
            $display("[%g]  Generador: simultaneous_test regimen=%s n=%0d",
                     $time, regimen_str, n_sim);
 
            // Pre-llenar la FIFO a la mitad para que las lecturas sean válidas
            for (int i = 0; i < depth/2; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: simultaneous_test - pre-llenado");
              gen_agent_mbx.put(transaccion);
            end
 
            // Generar las lectura_escritura simultáneas
            for (int i = 0; i < n_sim; i++) begin
              if (regimen_str == "bajo")
                ret_val = 1;
              else if (regimen_str == "medio")
                ret_val = $urandom_range(3, 5);
              else // alto
                ret_val = $urandom_range(7, 9);
 
              transaccion = new;
              transaccion.tipo        = lectura_escritura;
              transaccion.max_retardo = ret_val + 1;
              void'(transaccion.randomize());
              transaccion.tipo    = lectura_escritura;
              transaccion.retardo = ret_val;
              transaccion.print("Generador: simultaneous_test - lect_escr creada");
              gen_agent_mbx.put(transaccion);
            end
          end
 
          // ------------------------------------------------------------------
          // RESET CON FIFO LLENA:
          //   Llena la FIFO completamente con datos aleatorios, aplica reset,
          //   y luego verifica que la FIFO opera correctamente tras el reset.
          //
          //   Plusarg activador: +reset_llena
          // ------------------------------------------------------------------
          reset_llena: begin
            $display("[%g]  Generador: reset_llena - llenando hasta depth=%0d",
                     $time, depth);
 
            for (int i = 0; i < depth; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: reset_llena - escritura");
              gen_agent_mbx.put(transaccion);
            end
 
            crear_reset(1);
            $display("[%g]  Generador: reset_llena - reset aplicado con FIFO llena", $time);
 
            // Verificar funcionamiento post-reset
            for (int i = 0; i < depth/2; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: reset_llena - verificacion post-reset");
              gen_agent_mbx.put(transaccion);
            end
            for (int i = 0; i < depth/2; i++) begin
              crear_lectura(1);
            end
          end
 
          // ------------------------------------------------------------------
          // RESET CON FIFO VACÍA:
          //   Aplica reset directamente sin haber escrito ningún dato.
          //   Luego verifica que la FIFO opera correctamente tras el reset.
          //
          //   Plusarg activador: +reset_vacia
          // ------------------------------------------------------------------
          reset_vacia: begin
            $display("[%g]  Generador: reset_vacia - reset con FIFO vacia", $time);
 
            crear_reset(1);
 
            // Verificar funcionamiento post-reset
            for (int i = 0; i < depth/2; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: reset_vacia - verificacion post-reset");
              gen_agent_mbx.put(transaccion);
            end
            for (int i = 0; i < depth/2; i++) begin
              crear_lectura(1);
            end
          end
 
          // ------------------------------------------------------------------
          // RESET CON FIFO A LA MITAD:
          //   Escribe exactamente depth/2 elementos y luego aplica reset.
          //   Luego verifica que la FIFO opera correctamente tras el reset.
          //
          //   Plusarg activador: +reset_mitad
          // ------------------------------------------------------------------
          reset_mitad: begin
            $display("[%g]  Generador: reset_mitad - llenando %0d elementos (mitad)",
                     $time, depth/2);
 
            for (int i = 0; i < depth/2; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: reset_mitad - escritura");
              gen_agent_mbx.put(transaccion);
            end
 
            crear_reset(1);
            $display("[%g]  Generador: reset_mitad - reset aplicado con FIFO a la mitad",
                     $time);
 
            // Verificar funcionamiento post-reset
            for (int i = 0; i < depth/2; i++) begin
              transaccion = new;
              transaccion.tipo        = escritura;
              transaccion.max_retardo = 3;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: reset_mitad - verificacion post-reset");
              gen_agent_mbx.put(transaccion);
            end
            for (int i = 0; i < depth/2; i++) begin
              crear_lectura(1);
            end
          end
 
        endcase
      end
    end
  endtask
endclass
