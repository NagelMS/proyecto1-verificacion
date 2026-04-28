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
 
  // ── Contadores generales ──────────────────────────────────────────
  int transacciones_ok;
  int transacciones_error;
 
  // ── Contadores de casos de esquina ───────────────────────────────
  int cnt_overflow;        // escrituras con modelo lleno (FIFO en depth)
  int cnt_underflow;       // lecturas con modelo vacío
  int cnt_reset;           // eventos de reset procesados
  int cnt_simultaneo_ok;   // lectura_escritura correctas
  int cnt_simultaneo_err;  // lectura_escritura con error en la parte de lectura
 
  // ── Métrica de ocupación ─────────────────────────────────────────
  int ocupacion_maxima;    // mayor tamaño que alcanzó emul_fifo durante la prueba
 
  function new();
    this.transacciones_ok    = 0;
    this.transacciones_error = 0;
    this.cnt_overflow        = 0;
    this.cnt_underflow       = 0;
    this.cnt_reset           = 0;
    this.cnt_simultaneo_ok   = 0;
    this.cnt_simultaneo_err  = 0;
    this.ocupacion_maxima    = 0;
  endfunction
 
  // ── Actualiza ocupacion_maxima tras cada push al modelo ───────────
  function void actualizar_ocupacion();
    if (emul_fifo.size() > ocupacion_maxima)
      ocupacion_maxima = emul_fifo.size();
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
            cnt_overflow++;
            void'(emul_fifo.pop_front());
            $display("[%g] Checker: Overflow en escritura dato=0x%h (cnt_overflow=%0d)",
                     $time, trans_plan.dato, cnt_overflow);
          end
          emul_fifo.push_back(trans_plan);
          actualizar_ocupacion();
          $display("[%g] Checker: Escritura registrada dato=0x%h (modelo size=%0d)",
                   $time, trans_plan.dato, emul_fifo.size());
        end
 
        lectura: begin
          if (emul_fifo.size() == 0) begin
            cnt_underflow++;
            $display("[%g] Checker: Underflow - lectura con modelo vacio, dato DUT=0x%h (cnt_underflow=%0d)",
                     $time, trans_real.dato_leido, cnt_underflow);
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
            cnt_underflow++;
            $display("[%g] Checker: lectura_escritura - Underflow en lectura, dato DUT=0x%h (cnt_underflow=%0d)",
                     $time, trans_real.dato_leido, cnt_underflow);
          end else begin
            esperado = emul_fifo.pop_front();
            if (trans_real.dato_leido === esperado.dato) begin
              transacciones_ok++;
              cnt_simultaneo_ok++;
              $display("[%g] Checker: OK lectura_escritura [%0d] - esperado=0x%h leido=0x%h",
                       $time, transacciones_ok, esperado.dato, trans_real.dato_leido);
            end else begin
              transacciones_error++;
              cnt_simultaneo_err++;
              $display("[%g] Checker: ERROR lectura_escritura [%0d] - esperado=0x%h leido=0x%h",
                       $time, transacciones_error, esperado.dato, trans_real.dato_leido);
              $finish;
            end
          end
          // Parte escritura: actualizar modelo dorado
          if (emul_fifo.size() == depth) begin
            cnt_overflow++;
            void'(emul_fifo.pop_front());
            $display("[%g] Checker: lectura_escritura - Overflow en escritura dato=0x%h (cnt_overflow=%0d)",
                     $time, trans_plan.dato, cnt_overflow);
          end
          emul_fifo.push_back(trans_plan);
          actualizar_ocupacion();
        end
 
        reset: begin
          cnt_reset++;
          emul_fifo = {};
          $display("[%g] Checker: Reset - modelo dorado vaciado (cnt_reset=%0d)",
                   $time, cnt_reset);
        end
 
      endcase
    end
  endtask
 
  // ── Reporte final ─────────────────────────────────────────────────
  task reporte_final();
    $display("");
    $display("================================================================");
    $display("  CHECKER — REPORTE FINAL   @%0t ns", $time);
    $display("================================================================");
    $display("  Transacciones correctas  : %0d", transacciones_ok);
    $display("  Transacciones con error  : %0d", transacciones_error);
    $display("  ---- Casos de esquina ----");
    $display("  Overflows  detectados    : %0d", cnt_overflow);
    $display("  Underflows detectados    : %0d", cnt_underflow);
    $display("  Resets     procesados    : %0d", cnt_reset);
    $display("  Lect+Escr  correctas     : %0d", cnt_simultaneo_ok);
    $display("  Lect+Escr  con error     : %0d", cnt_simultaneo_err);
    $display("  Ocupacion maxima modelo  : %0d / %0d", ocupacion_maxima, depth);
    $display("----------------------------------------------------------------");
    if (transacciones_error == 0 && cnt_simultaneo_err == 0) begin
      $display("  >>  RESULTADO: ** PASS ** — sin errores detectados");
    end else begin
      $display("  >>  RESULTADO: !! FAIL !! — %0d errores en total",
               transacciones_error + cnt_simultaneo_err);
    end
    $display("================================================================");
    $display("");
  endtask
 
endclass
