////////////////////////////////////////////////////////////////////////////////////////////
// Scoreboard: base de datos que almacena todas las transacciones generadas por el      //
// agente y las redirige al checker para que éste pueda verificar el comportamiento      //
// del DUT contra la secuencia planificada. También genera reportes bajo demanda.        //
////////////////////////////////////////////////////////////////////////////////////////////

class score_board #(parameter width=16);
  trans_fifo_mbx      agnt_sb_mbx;  // entrada: transacciones planificadas del agente
  trans_fifo_mbx      sb_chkr_mbx;  // salida: reenvío al checker para verificación
  comando_test_sb_mbx test_sb_mbx;  // entrada: comandos del test

  trans_fifo #(.width(width)) historial[$]; // historial completo de transacciones del agente
  trans_fifo #(.width(width)) trans_entrada;
  solicitud_sb orden;
  int n_escrituras;
  int n_lecturas;
  int n_resets;

  task run;
    $display("[%g] El Score Board fue inicializado", $time);
    forever begin
      #1
      // Almacena las transacciones del agente y las redirige al checker
      if (agnt_sb_mbx.num() > 0) begin
        agnt_sb_mbx.get(trans_entrada);
        trans_entrada.print("Score Board: Transaccion del agente recibida y almacenada");
        historial.push_back(trans_entrada);
        sb_chkr_mbx.put(trans_entrada);
        case (trans_entrada.tipo)
          escritura: n_escrituras++;
          lectura:   n_lecturas++;
          reset:     n_resets++;
        endcase
      end

      // Maneja comandos del test para generar reportes
      if (test_sb_mbx.num() > 0) begin
        test_sb_mbx.get(orden);
        case (orden)
          retardo_promedio: begin
            $display("[%g] Score Board: Latencia disponible en los reportes del checker", $time);
          end
          reporte: begin
            $display("[%g] Score Board: Reporte de transacciones del agente - Escrituras=%0d Lecturas=%0d Resets=%0d Total=%0d",
                     $time, n_escrituras, n_lecturas, n_resets, historial.size());
          end
        endcase
      end
    end
  endtask
endclass
