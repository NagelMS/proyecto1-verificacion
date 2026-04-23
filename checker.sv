////////////////////////////////////////////////////////////////////////////////////////////
// Checker: referencia dorada del sistema de verificación.                              //
// Mantiene emul_fifo como modelo dorado de la FIFO. Recibe observaciones reales del   //
// monitor y transacciones planificadas del scoreboard (via sb_chkr_mbx). Por cada     //
// evento del monitor extrae UNA transacción planificada, actualiza el modelo, y       //
// verifica que el DUT se comporte correctamente.                                       //
//                                                                                      //
// MEJORAS para casos de esquina:                                                       //
//   - Contadores dedicados por evento especial (overflow, underflow, reset, simultáneo)//
//   - Detección activa del tamaño del modelo antes y después de cada operación         //
//   - Tarea reporte_final() llamable desde el test vía plusarg +reporte_checker        //
//   - Banner de PASS/FAIL al finalizar la simulación                                   //
////////////////////////////////////////////////////////////////////////////////////////////
 
class checker_c #(parameter width=16, parameter depth=8);
  fifo_pkg #(.width(width))::mbx_t mon_chkr_mbx; // observaciones reales del DUT (desde monitor)
  fifo_pkg #(.width(width))::mbx_t sb_chkr_mbx;  // transacciones planificadas crudas (desde scoreboard)
 
  trans_fifo #(.width(width)) emul_fifo[$]; // modelo dorado de la FIFO
  trans_fifo #(.width(width)) trans_real;   // observación del monitor
  trans_fifo #(.width(width)) trans_plan;   // transacción planificada del scoreboard
  trans_fifo #(.width(width)) esperado;
 
  // -------------------------------------------------------
  // Contadores generales
  // -------------------------------------------------------
  int transacciones_ok;
  int transacciones_error;
 
  // -------------------------------------------------------
  // Contadores por caso de esquina
  // -------------------------------------------------------
  int cnt_overflow;        // escrituras detectadas con modelo lleno
  int cnt_underflow;       // lecturas detectadas con modelo vacío
  int cnt_reset;           // resets procesados
  int cnt_simultaneo_ok;   // lectura_escritura correctas
  int cnt_simultaneo_err;  // lectura_escritura incorrectas
 
  // -------------------------------------------------------
  // Variables de seguimiento de ocupación máxima
  // -------------------------------------------------------
  int ocupacion_maxima;    // mayor cantidad de elementos que tuvo el modelo
  int ocupacion_actual;    // alias legible de emul_fifo.size()
 
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
 
  // -------------------------------------------------------
  // Tarea auxiliar: actualiza ocupacion_maxima tras escritura
  // -------------------------------------------------------
  function automatic void actualizar_ocupacion();
    ocupacion_actual = emul_fifo.size();
    if (ocupacion_actual > ocupacion_maxima)
      ocupacion_maxima = ocupacion_actual;
  endfunction
 
  // -------------------------------------------------------
  // Tarea de reporte final — llamar al terminar la simulación
  // -------------------------------------------------------
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
 
  // =========================================================
  task run;
    $display("[%g] El checker fue inicializado", $time);
    forever begin
      // Espera observación real del DUT
      mon_chkr_mbx.get(trans_real);
      trans_real.print("Checker: Observacion del monitor");
 
      // Obtiene la transacción planificada correspondiente del scoreboard
      sb_chkr_mbx.get(trans_plan);
 
      case (trans_real.tipo)
 
        // -------------------------------------------------------
        // ESCRITURA
        // -------------------------------------------------------
        escritura: begin
          if (emul_fifo.size() == depth) begin
            // *** CASO DE ESQUINA: OVERFLOW ***
            cnt_overflow++;
            void'(emul_fifo.pop_front());
            $display("[%g] Checker [OVERFLOW #%0d]: escritura con modelo LLENO dato=0x%h  modelo=%0d/%0d",
                     $time, cnt_overflow, trans_plan.dato, emul_fifo.size()+1, depth);
          end
          emul_fifo.push_back(trans_plan);
          actualizar_ocupacion();
          $display("[%g] Checker: Escritura registrada dato=0x%h  modelo=%0d/%0d",
                   $time, trans_plan.dato, emul_fifo.size(), depth);
        end
 
        // -------------------------------------------------------
        // LECTURA
        // -------------------------------------------------------
        lectura: begin
          if (emul_fifo.size() == 0) begin
            // *** CASO DE ESQUINA: UNDERFLOW ***
            cnt_underflow++;
            $display("[%g] Checker [UNDERFLOW #%0d]: lectura con modelo VACIO  dato_DUT=0x%h",
                     $time, cnt_underflow, trans_real.dato_leido);
          end else begin
            esperado = emul_fifo.pop_front();
            if (trans_real.dato_leido === esperado.dato) begin
              transacciones_ok++;
              $display("[%g] Checker: OK lectura [%0d]  esperado=0x%h  leido=0x%h  latencia=%0dns  modelo=%0d/%0d",
                       $time, transacciones_ok, esperado.dato, trans_real.dato_leido,
                       trans_real.tiempo - esperado.tiempo, emul_fifo.size(), depth);
            end else begin
              transacciones_error++;
              $display("[%g] Checker: ERROR lectura [%0d]  esperado=0x%h  leido=0x%h  modelo=%0d/%0d",
                       $time, transacciones_error, esperado.dato, trans_real.dato_leido,
                       emul_fifo.size(), depth);
              reporte_final();
              $finish;
            end
          end
        end
 
        // -------------------------------------------------------
        // LECTURA + ESCRITURA SIMULTÁNEA
        // *** CASO DE ESQUINA: simultaneous_test ***
        // -------------------------------------------------------
        lectura_escritura: begin
          // — Parte lectura: verificar dato leído contra modelo —
          if (emul_fifo.size() == 0) begin
            cnt_underflow++;
            $display("[%g] Checker [UNDERFLOW #%0d]: lect+escr simultanea con modelo VACIO  dato_DUT=0x%h",
                     $time, cnt_underflow, trans_real.dato_leido);
          end else begin
            esperado = emul_fifo.pop_front();
            if (trans_real.dato_leido === esperado.dato) begin
              cnt_simultaneo_ok++;
              transacciones_ok++;
              $display("[%g] Checker: OK lect+escr [%0d]  esperado=0x%h  leido=0x%h  modelo_tras_pop=%0d/%0d",
                       $time, cnt_simultaneo_ok, esperado.dato, trans_real.dato_leido,
                       emul_fifo.size(), depth);
            end else begin
              cnt_simultaneo_err++;
              transacciones_error++;
              $display("[%g] Checker: ERROR lect+escr [%0d]  esperado=0x%h  leido=0x%h  modelo=%0d/%0d",
                       $time, cnt_simultaneo_err, esperado.dato, trans_real.dato_leido,
                       emul_fifo.size(), depth);
              reporte_final();
              $finish;
            end
          end
          // — Parte escritura: actualizar modelo dorado —
          if (emul_fifo.size() == depth) begin
            cnt_overflow++;
            void'(emul_fifo.pop_front());
            $display("[%g] Checker [OVERFLOW #%0d]: lect+escr con modelo LLENO dato=0x%h",
                     $time, cnt_overflow, trans_plan.dato);
          end
          emul_fifo.push_back(trans_plan);
          actualizar_ocupacion();
        end
 
        // -------------------------------------------------------
        // RESET
        // *** CASO DE ESQUINA: reset_llena / reset_vacia / reset_mitad ***
        // -------------------------------------------------------
        reset: begin
          cnt_reset++;
          $display("[%g] Checker [RESET #%0d]: modelo vaciado — tenia %0d/%0d elementos antes del reset",
                   $time, cnt_reset, emul_fifo.size(), depth);
          emul_fifo = {};
          $display("[%g] Checker [RESET #%0d]: modelo dorado vaciado correctamente",
                   $time, cnt_reset);
        end
 
      endcase
    end
  endtask
endclass
