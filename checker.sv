////////////////////////////////////////////////////////////////////////////////////////////
// Checker: verifica que el comportamiento del DUT sea coherente con su especificación. //
// Mantiene una referencia dorada (golden model) alimentada por el scoreboard con las   //
// transacciones planificadas por el agente, y la contrasta con lo que observa el       //
// monitor en las salidas reales del DUT.                                                //
////////////////////////////////////////////////////////////////////////////////////////////

class checker_c #(parameter width=16, parameter depth=8);
  trans_fifo #(.width(width)) emul_fifo[$]; // referencia dorada (golden model)
  trans_fifo_mbx mon_chkr_mbx;             // observaciones reales del DUT (desde monitor)
  trans_fifo_mbx sb_chkr_mbx;              // transacciones planificadas (desde scoreboard)

  trans_fifo #(.width(width)) trans_planeada;
  trans_fifo #(.width(width)) trans_real;
  trans_fifo #(.width(width)) esperado;
  int transacciones_ok;
  int transacciones_error;

  function new();
    this.emul_fifo = {};
    this.transacciones_ok = 0;
    this.transacciones_error = 0;
  endfunction

  // Aplica una transacción planificada del agente al modelo dorado
  function void aplicar_al_modelo(trans_fifo #(.width(width)) trans);
    case (trans.tipo)
      escritura: begin
        if (emul_fifo.size() == depth) begin
          void'(emul_fifo.pop_front()); // overflow: descarta el dato más antiguo
          $display("[%g] Checker-Modelo: Overflow en escritura dato=0x%h", $time, trans.dato);
        end
        emul_fifo.push_back(trans);
      end
      reset: begin
        emul_fifo = {};
        $display("[%g] Checker-Modelo: Reset aplicado, FIFO emulada vaciada", $time);
      end
      lectura:           ; // las lecturas no modifican el estado del modelo
      lectura_escritura: ; // la verificación y actualización se hacen en el paso de verificación
    endcase
  endfunction

  task run;
    $display("[%g] El checker fue inicializado", $time);
    forever begin
      // Drena transacciones planificadas pendientes para mantener el modelo actualizado
      while (sb_chkr_mbx.try_get(trans_planeada)) begin
        trans_planeada.print("Checker: Transaccion del scoreboard aplicada al modelo");
        aplicar_al_modelo(trans_planeada);
      end

      // Espera la próxima observación real del DUT desde el monitor
      mon_chkr_mbx.get(trans_real);
      trans_real.print("Checker: Observacion recibida del monitor");

      // Drena de nuevo por si llegaron transacciones planificadas en el mismo instante
      while (sb_chkr_mbx.try_get(trans_planeada)) begin
        trans_planeada.print("Checker: Transaccion del scoreboard aplicada al modelo");
        aplicar_al_modelo(trans_planeada);
      end

      case (trans_real.tipo)
        lectura: begin
          if (emul_fifo.size() == 0) begin
            $display("[%g] Checker: Underflow - lectura sin datos disponibles en la FIFO emulada", $time);
          end else begin
            esperado = emul_fifo.pop_front();
            if (trans_real.dato_leido === esperado.dato) begin
              transacciones_ok++;
              $display("[%g] Checker: OK [%0d] - esperado=0x%h leido=0x%h latencia=%0dns",
                       $time, transacciones_ok, esperado.dato, trans_real.dato_leido,
                       trans_real.tiempo - esperado.tiempo);
            end else begin
              transacciones_error++;
              $display("[%g] Checker: ERROR [%0d] - esperado=0x%h leido=0x%h",
                       $time, transacciones_error, esperado.dato, trans_real.dato_leido);
              $finish;
            end
          end
        end
        escritura: begin
          $display("[%g] Checker: Escritura observada dato=0x%h", $time, trans_real.dato);
        end
        lectura_escritura: begin
          // Verificar la parte de lectura (con el estado ANTES de la escritura)
          if (emul_fifo.size() == 0) begin
            $display("[%g] Checker: lectura_escritura - Underflow en lectura", $time);
          end else begin
            esperado = emul_fifo.pop_front();
            if (trans_real.dato_leido === esperado.dato) begin
              transacciones_ok++;
              $display("[%g] Checker: OK lectura_escritura [%0d] - esperado=0x%h leido=0x%h",
                       $time, transacciones_ok, esperado.dato, trans_real.dato_leido);
            end else begin
              transacciones_error++;
              $display("[%g] Checker: ERROR lectura_escritura [%0d] - esperado=0x%h leido=0x%h",
                       $time, transacciones_error, esperado.dato, trans_real.dato_leido);
              $finish;
            end
          end
          // Aplicar la parte de escritura al modelo (después de la lectura)
          if (emul_fifo.size() == depth) begin
            void'(emul_fifo.pop_front());
            $display("[%g] Checker: lectura_escritura - Overflow en escritura dato=0x%h", $time, trans_real.dato);
          end
          emul_fifo.push_back(trans_real);
        end
        reset: begin
          emul_fifo = {};
          $display("[%g] Checker: Reset observado, modelo sincronizado con el DUT", $time);
        end
      endcase
    end
  endtask
endclass
