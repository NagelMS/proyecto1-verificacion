//////////////////////////////////////////////////////////////////////////////////////////////////
// Agente/Generador: Este bloque se encarga de generar las secuencias de eventos para el driver //
// En este ejemplo se generarán 2 tipos de secuencias:                                          //
//    llenado_vaciado: En esta se genera un número parametrizable de tarnsacciones de lecturas  //
//                     y escrituras para llenar y vaciar la fifo.                               //
//    Aleatoria: En esta se generarán transacciones totalmente aleatorias                       //
//    Específica: en este tipo se generan trasacciones semi específicas para casos esquina      // 
//////////////////////////////////////////////////////////////////////////////////////////////////

class generador #(parameter width = 16, parameter depth = 8);
  trans_fifo_mbx gen_agent_mbx;          // Mailbox del generador al agente
  comando_test_gen_mbx test_gen_mbx;    // Mailbox del test al generador
  int num_transacciones;                 // Número de transacciones para las funciones del generador
  int max_retardo;                       // retardo máximo en la transacción
  int ret_spec;                          // retardo específico
  tipo_trans tpo_spec; 
  bit [width-1:0] dto_spec;
  instrucciones_gen instruccion;      // para guardar la última instruccion leída
  trans_fifo #(.width(width)) transaccion;
   
  function new;
    num_transacciones = 2;
    max_retardo = 10;
  endfunction

  task run;
    $display("[%g]  El generador fue inicializado",$time);
    forever begin
      #1
      if(test_gen_mbx.num() > 0)begin
        $display("[%g]  Generador: se recibe instruccion",$time);
        test_gen_mbx.get(instruccion);
        case(instruccion)
          llenado_aleatorio: begin  // Esta instruccion genera num_transacciones escrituras seguidas del mismo número de lecturas
            for(int i = 0; i < num_transacciones;i++) begin
              transaccion =new;
              transaccion.max_retardo = max_retardo;
              transaccion.randomize();
              tpo_spec = escritura;
              transaccion.tipo = tpo_spec;
              transaccion.print("Generador: transacción creada");
              gen_agent_mbx.put(transaccion);
            end
            for(int i=0; i<num_transacciones;i++) begin
              transaccion =new;
              transaccion.randomize();
              tpo_spec = lectura;
              transaccion.tipo = tpo_spec;
              transaccion.print("Generador: transacción creada");
              gen_agent_mbx.put(transaccion);
            end
          end
          trans_aleatoria: begin  // Esta instrucción genera una transaccion aleatoria
            transaccion =new;
            transaccion.max_retardo = max_retardo;
            transaccion.randomize();
            transaccion.print("Generador: transacción creada");
            gen_agent_mbx.put(transaccion);
          end
          trans_especifica: begin  // Esta instrucción genera una transacción específica
            transaccion =new;
            transaccion.tipo = tpo_spec;
            transaccion.dato = dto_spec;
            transaccion.retardo = ret_spec;
            transaccion.print("Generador: transacción creada");
            gen_agent_mbx.put(transaccion);
          end
          sec_trans_aleatorias: begin // Esta instrucción genera una secuencia de instrucciones aleatorias
            for(int i=0; i<num_transacciones;i++) begin
            transaccion =new;
            transaccion.max_retardo = max_retardo;
            transaccion.randomize();
            transaccion.print("Generador: transacción creada");
            gen_agent_mbx.put(transaccion);
            end
          end
        endcase
      end
    end
  endtask
endclass

class agent #(parameter  width = 16, parameter depth = 8);
  trans_fifo_mbx agent_drv_mbx;
  trans_fifo_mbx agent_scrb_mbx;
  trans_fifo_mbx gen_agent_mbx;
  trans_fifo #(.width(width)) transaccion;

  task run;
  $display("[%g]  El agente fue inicializado", $time);
  forever  begin
    #1
    if(gen_agent_mbx.num() > 0) begin
      $display("[%g]  Agente: se recibe instruccion desde generador",$time);
      gen_agent_mbx.get(transaccion);
      agent_scrb_mbx.put(transaccion);
      $display("[%g]  Agente: se entrega instruccion al scoreboard",$time);
      agent_drv_mbx.put(transaccion);
      $display("[%g]  Agente: se entrega instruccion al driver",$time);
    end
  end
  endtask
endclass