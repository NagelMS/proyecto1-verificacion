////////////////////////////////////////////////////////////////////////////////////////////
// Agente (Transactor): recibe transacciones del generador y las encamina tanto al       //
// driver (para estimular el DUT) como al scoreboard (para registrarlas como referencia).//
////////////////////////////////////////////////////////////////////////////////////////////

class agent #(parameter width = 16, parameter depth = 8);
  fifo_pkg #(.width(width))::mbx_t gen_agent_mbx;   // entrada: transacciones del generador
  fifo_pkg #(.width(width))::mbx_t agent_drv_mbx;   // salida: al driver para ejecutar en el DUT
  fifo_pkg #(.width(width))::mbx_t agent_scrb_mbx;  // salida: al scoreboard como base de datos

  trans_fifo #(.width(width)) transaccion;

  task run;
    $display("[%g]  El agente fue inicializado", $time);
    forever begin
      #1
      if (gen_agent_mbx.num() > 0) begin
        gen_agent_mbx.get(transaccion);
        transaccion.print("Agente: transaccion recibida del generador");
        agent_scrb_mbx.put(transaccion);
        $display("[%g]  Agente: transaccion enviada al scoreboard", $time);
        agent_drv_mbx.put(transaccion);
        $display("[%g]  Agente: transaccion enviada al driver", $time);
      end
    end
  endtask
endclass
