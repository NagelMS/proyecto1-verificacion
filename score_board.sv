////////////////////////////////////////////////////////////////////////////////////////////
// Scoreboard: base de datos de todas las transacciones planificadas por el agente.     //
// Recibe cada transacción del agente, la almacena en historial para reportes, y la    //
// reenvía al checker para que este aplique su modelo dorado y verifique el DUT.       //
////////////////////////////////////////////////////////////////////////////////////////////

class score_board #(parameter width=16);
  fifo_pkg #(.width(width))::mbx_t agnt_sb_mbx;  // entrada: transacciones planificadas del agente
  fifo_pkg #(.width(width))::mbx_t sb_chkr_mbx;  // salida: transacciones crudas para el checker
  comando_test_sb_mbx test_sb_mbx;  // entrada: comandos del test

  trans_fifo #(.width(width)) historial[$]; // registro completo de transacciones
  trans_fifo #(.width(width)) trans_entrada;
  solicitud_sb orden;
  int n_escrituras;
  int n_lecturas;
  int n_lectura_escritura;
  int n_resets;

  task run;
    $display("[%g] El Score Board fue inicializado", $time);
    forever begin
      #1
      if (agnt_sb_mbx.num() > 0) begin
        agnt_sb_mbx.get(trans_entrada);
        trans_entrada.print("Score Board: Transaccion recibida del agente");
        historial.push_back(trans_entrada);

        case (trans_entrada.tipo)
          escritura:         n_escrituras++;
          lectura:           n_lecturas++;
          lectura_escritura: n_lectura_escritura++;
          reset:             n_resets++;
        endcase

        // Reenviar al checker para que actualice su modelo dorado y verifique
        sb_chkr_mbx.put(trans_entrada);
      end

      if (test_sb_mbx.num() > 0) begin
        test_sb_mbx.get(orden);
        case (orden)
          retardo_promedio: begin
            $display("[%g] Score Board: Latencia calculada por el checker directamente", $time);
          end
          reporte: begin
            $display("[%g] Score Board: Reporte - Escrituras=%0d Lecturas=%0d LectEscr=%0d Resets=%0d Total=%0d",
                     $time, n_escrituras, n_lecturas, n_lectura_escritura, n_resets, historial.size());
          end
        endcase
      end
    end
  endtask
endclass
