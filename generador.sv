//////////////////////////////////////////////////////////////////////////////////////////////////
// Generador: Este bloque se encarga de manejar secuencias de transacciones para establecer  //
// un escenario de prueba. Genera objetos trans_fifo y los envía al agente para que éste     //
// los encamine al driver y al scoreboard.                                                    //
//    llenado_aleatorio:   N escrituras seguidas de N lecturas.                               //
//    trans_aleatoria:     Una transacción completamente aleatoria.                           //
//    trans_especifica:    Una transacción con parámetros fijos (casos de esquina).           //
//    sec_trans_aleatorias: Secuencia de N transacciones aleatorias.                          //
//////////////////////////////////////////////////////////////////////////////////////////////////

class generador #(parameter width = 16, parameter depth = 8);
  trans_fifo_mbx       gen_agent_mbx; // Mailbox del generador al agente
  comando_test_gen_mbx test_gen_mbx;  // Mailbox del test al generador
  int num_transacciones;              // Número de transacciones por secuencia
  int max_retardo;                    // Retardo máximo por transacción
  int ret_spec;                       // Retardo para trans_especifica
  tipo_trans       tpo_spec;          // Tipo para trans_especifica
  bit [width-1:0]  dto_spec;          // Dato para trans_especifica
  instrucciones_gen instruccion;
  trans_fifo #(.width(width)) transaccion;

  function new;
    num_transacciones = 2;
    max_retardo = 10;
  endfunction

  task run;
    $display("[%g]  El generador fue inicializado", $time);
    forever begin
      #1
      if (test_gen_mbx.num() > 0) begin
        $display("[%g]  Generador: se recibe instruccion", $time);
        test_gen_mbx.get(instruccion);
        case (instruccion)
          llenado_aleatorio: begin
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              transaccion.randomize();
              transaccion.tipo = escritura;
              transaccion.print("Generador: transaccion escritura creada");
              gen_agent_mbx.put(transaccion);
            end
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              transaccion.randomize();
              transaccion.tipo = lectura;
              transaccion.print("Generador: transaccion lectura creada");
              gen_agent_mbx.put(transaccion);
            end
          end
          trans_aleatoria: begin
            transaccion = new;
            transaccion.max_retardo = max_retardo;
            transaccion.randomize();
            transaccion.print("Generador: transaccion aleatoria creada");
            gen_agent_mbx.put(transaccion);
          end
          trans_especifica: begin
            transaccion = new;
            transaccion.tipo    = tpo_spec;
            transaccion.dato    = dto_spec;
            transaccion.retardo = ret_spec;
            transaccion.print("Generador: transaccion especifica creada");
            gen_agent_mbx.put(transaccion);
          end
          sec_trans_aleatorias: begin
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion = new;
              transaccion.max_retardo = max_retardo;
              transaccion.randomize();
              transaccion.print("Generador: transaccion en secuencia creada");
              gen_agent_mbx.put(transaccion);
            end
          end
        endcase
      end
    end
  endtask
endclass
