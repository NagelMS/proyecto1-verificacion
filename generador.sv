//////////////////////////////////////////////////////////////////////////////////////////////////
// Generador: maneja secuencias de transacciones para el escenario de prueba.               //
//    caso_general:      Cantidad aleatoria de transacciones con tipo, dato y retardo        //
//                       completamente aleatorios. Reset ocurre con baja probabilidad (5%).  //
//    llenado_aleatorio: N escrituras seguidas de N lecturas (N aleatorio).                  //
//////////////////////////////////////////////////////////////////////////////////////////////////

class generador #(parameter width = 16, parameter depth = 8);
  trans_fifo_mbx       gen_agent_mbx;
  comando_test_gen_mbx test_gen_mbx;
  instrucciones_gen instruccion;
  trans_fifo #(.width(width)) transaccion;

  function new;
  endfunction

  task run;
    int n_trans, mx_ret;
    $display("[%g]  El generador fue inicializado", $time);
    forever begin
      #1
      if (test_gen_mbx.num() > 0) begin
        $display("[%g]  Generador: se recibe instruccion", $time);
        test_gen_mbx.get(instruccion);
        case (instruccion)

          caso_general: begin
            n_trans = $urandom_range(depth, 4*depth); // cantidad aleatoria
            mx_ret  = $urandom_range(2, 8);           // retardo máximo aleatorio
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

          llenado_aleatorio: begin
            n_trans = $urandom_range(1, depth); // entre 1 y depth escrituras+lecturas
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

        endcase
      end
    end
  endtask
endclass
