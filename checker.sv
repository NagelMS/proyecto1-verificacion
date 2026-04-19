////////////////////////////////////////////////////////////////////////////////////////////
// Checker: referencia dorada del sistema de verificación.                              //
// Mantiene emul_fifo como modelo dorado de la FIFO. Recibe observaciones reales del   //
// monitor y transacciones planificadas del scoreboard (via sb_chkr_mbx). Por cada     //
// evento del monitor extrae UNA transacción planificada, actualiza el modelo, y       //
// verifica que el DUT se comporte correctamente.                                       //
////////////////////////////////////////////////////////////////////////////////////////////

class checker_c #(parameter width=16, parameter depth=8);
  trans_fifo_mbx mon_chkr_mbx; // observaciones reales del DUT (desde monitor)
  trans_fifo_mbx sb_chkr_mbx;  // transacciones planificadas crudas (desde scoreboard)

  trans_fifo #(.width(width)) emul_fifo[$]; // modelo dorado de la FIFO
  trans_fifo #(.width(width)) trans_real;   // observación del monitor
  trans_fifo #(.width(width)) trans_plan;   // transacción planificada del scoreboard
  trans_fifo #(.width(width)) esperado;
  int transacciones_ok;
  int transacciones_error;

  function new();
    this.transacciones_ok = 0;
    this.transacciones_error = 0;
  endfunction

  task run;
    $display("[%g] El checker fue inicializado", $time);
    forever begin
      // Espera observación real del DUT
      mon_chkr_mbx.get(trans_real);
      trans_real.print("Checker: Observacion del monitor");

      // Obtiene la transacción planificada correspondiente del scoreboard
      sb_chkr_mbx.get(trans_plan);

      case (trans_real.tipo)
        escritura: begin
          // Actualizar modelo dorado
          if (emul_fifo.size() == depth) begin
            void'(emul_fifo.pop_front());
            $display("[%g] Checker: Overflow en escritura dato=0x%h", $time, trans_plan.dato);
          end
          emul_fifo.push_back(trans_plan);
          $display("[%g] Checker: Escritura registrada dato=0x%h (modelo size=%0d)",
                   $time, trans_plan.dato, emul_fifo.size());
        end

        lectura: begin
          if (emul_fifo.size() == 0) begin
            $display("[%g] Checker: Underflow - lectura con modelo vacio, dato DUT=0x%h",
                     $time, trans_real.dato_leido);
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

        lectura_escritura: begin
          // Parte lectura: verificar dato leído contra modelo
          if (emul_fifo.size() == 0) begin
            $display("[%g] Checker: lectura_escritura - Underflow en lectura, dato DUT=0x%h",
                     $time, trans_real.dato_leido);
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
          // Parte escritura: actualizar modelo dorado
          if (emul_fifo.size() == depth) begin
            void'(emul_fifo.pop_front());
            $display("[%g] Checker: lectura_escritura - Overflow en escritura dato=0x%h",
                     $time, trans_plan.dato);
          end
          emul_fifo.push_back(trans_plan);
        end

        reset: begin
          emul_fifo = {};
          $display("[%g] Checker: Reset - modelo dorado vaciado", $time);
        end
      endcase
    end
  endtask
endclass
