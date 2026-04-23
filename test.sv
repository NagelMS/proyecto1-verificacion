////////////////////////////////////////////////////////////////////////////////////////////////////
// test.sv — Capa de control de la prueba.                                                      //
//                                                                                              //
// Selección de escenario mediante plusargs (se pasa al ejecutable ./salida):                   //
//                                                                                              //
//   Escenario base (uno activo a la vez):                                                      //
//     +caso_general          -> transacciones completamente aleatorias (DEFAULT)               //
//     +llenado_aleatorio     -> N escrituras seguidas de N lecturas                            //
//     +patron_alternancia    -> llena con 0x0000/0x5555/0xAAAA/0xFFFF intercalados             //
//     +overflow_test         -> escribe depth+extra elementos (fuerza overflow)                //
//     +underflow_test        -> lee con la FIFO vacía (fuerza underflow)                       //
//     +simultaneous_test     -> pop+push simultáneos                                           //
//     +reset_llena           -> reset con la FIFO completamente llena                          //
//     +reset_vacia           -> reset con la FIFO completamente vacía                          //
//     +reset_mitad           -> reset con la FIFO a la mitad                                   //
//                                                                                              //
//   Plusargs de configuración (opcionales, se combinan con el escenario):                      //
//     +pa_ciclos=N           -> ciclos de relleno en patron_alternancia    (default 2)         //
//     +overflow_extra=N      -> escrituras extra en overflow_test          (default 4)         //
//     +underflow_extra=N     -> lecturas extra en underflow_test           (default 4)         //
//     +sim_regimen=bajo|medio|alto  -> régimen de retardo en simultaneous  (default bajo)      //
//     +sim_n=N               -> cantidad de lect_escr en simultaneous      (default depth)     //
//     +tiempo_limite=T       -> tiempo de simulación en ns                 (default 10000)     //
//                                                                                              //
//   Ejemplos de uso:                                                                           //
//     ./salida +caso_general                                                                   //
//     ./salida +overflow_test +overflow_extra=8                                                //
//     ./salida +underflow_test +underflow_extra=6                                              //
//     ./salida +patron_alternancia +pa_ciclos=4                                                //
//     ./salida +simultaneous_test +sim_regimen=medio +sim_n=16                                 //
//     ./salida +reset_llena                                                                    //
//     ./salida +reset_vacia                                                                    //
//     ./salida +reset_mitad                                                                    //
////////////////////////////////////////////////////////////////////////////////////////////////////
 
class test #(parameter width = 16, parameter depth = 8);
 
  comando_test_sb_mbx  test_sb_mbx;
  comando_test_gen_mbx test_gen_mbx;
 
  solicitud_sb      instr_sb;
  instrucciones_gen instr_gen;
 
  ambiente #(.depth(depth),.width(width)) ambiente_inst;
  virtual fifo_if  #(.width(width)) _if;
 
  function new;
    test_sb_mbx  = new();
    test_gen_mbx = new();
 
    ambiente_inst = new();
    ambiente_inst._if = _if;
 
    ambiente_inst.test_sb_mbx  = test_sb_mbx;
    ambiente_inst.test_gen_mbx = test_gen_mbx;
 
    ambiente_inst.scoreboard_inst.test_sb_mbx = test_sb_mbx;
    ambiente_inst.gen_inst.test_gen_mbx        = test_gen_mbx;
  endfunction
 
  task run;
    int tiempo_limite;
    $display("[%g]  El Test fue inicializado", $time);
    fork
      ambiente_inst.run();
    join_none
 
    // ------------------------------------------------------------------
    // Lectura del tiempo límite de simulación
    // ------------------------------------------------------------------
    if (!$value$plusargs("tiempo_limite=%d", tiempo_limite))
      tiempo_limite = 10000;
    $display("[%g]  Test: tiempo_limite=%0d ns", $time, tiempo_limite);
 
    // ------------------------------------------------------------------
    // Selección del escenario mediante plusargs
    // Se evalúan en orden de prioridad. El primero que coincida gana.
    // Si no se pasa ninguno, el default es caso_general.
    // ------------------------------------------------------------------
 
    if ($test$plusargs("patron_alternancia")) begin
      $display("[%g]  Test: escenario patron_alternancia (+plusarg)", $time);
      instr_gen = patron_alternancia;
 
    end else if ($test$plusargs("overflow_test")) begin
      $display("[%g]  Test: escenario overflow_test (+plusarg)", $time);
      instr_gen = overflow_test;
 
    end else if ($test$plusargs("underflow_test")) begin
      $display("[%g]  Test: escenario underflow_test (+plusarg)", $time);
      instr_gen = underflow_test;
 
    end else if ($test$plusargs("simultaneous_test")) begin
      $display("[%g]  Test: escenario simultaneous_test (+plusarg)", $time);
      instr_gen = simultaneous_test;
 
    end else if ($test$plusargs("reset_llena")) begin
      $display("[%g]  Test: escenario reset_llena (+plusarg)", $time);
      instr_gen = reset_llena;
 
    end else if ($test$plusargs("reset_vacia")) begin
      $display("[%g]  Test: escenario reset_vacia (+plusarg)", $time);
      instr_gen = reset_vacia;
 
    end else if ($test$plusargs("reset_mitad")) begin
      $display("[%g]  Test: escenario reset_mitad (+plusarg)", $time);
      instr_gen = reset_mitad;
 
    end else if ($test$plusargs("llenado_aleatorio")) begin
      $display("[%g]  Test: escenario llenado_aleatorio (+plusarg)", $time);
      instr_gen = llenado_aleatorio;
 
    end else begin
      // Default: caso_general (también se puede activar explícitamente con +caso_general)
      $display("[%g]  Test: escenario caso_general (default)", $time);
      instr_gen = caso_general;
    end
 
    test_gen_mbx.put(instr_gen);
 
    // ------------------------------------------------------------------
    // Espera el tiempo límite y luego solicita reportes finales
    // ------------------------------------------------------------------
    #(tiempo_limite)
    $display("[%g]  Test: Se alcanza el tiempo limite de la prueba (%0d ns)",
             $time, tiempo_limite);
 
    // Reporte del scoreboard (conteo por tipo de transaccion)
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);
    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);
 
    // Reporte final del checker: contadores de casos de esquina + PASS/FAIL
    #10
    ambiente_inst.checker_inst.reporte_final();
 
    #10
    $finish;
  endtask
endclass
