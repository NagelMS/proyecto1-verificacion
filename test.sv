///////////////////////////////////
// Módulo para correr la prueba  //
///////////////////////////////////
class test #(parameter width = 16, parameter depth = 8);
 
  comando_test_sb_mbx test_sb_mbx;
  solicitud_sb        instr_sb;
 
  ambiente #(.depth(depth),.width(width)) ambiente_inst;
  virtual fifo_if #(.width(width)) _if;
 
  function new;
    test_sb_mbx  = new();
 
    ambiente_inst = new();
    ambiente_inst._if = _if;
 
    ambiente_inst.test_sb_mbx = test_sb_mbx;
    ambiente_inst.scoreboard_inst.test_sb_mbx = test_sb_mbx;
  endfunction
 
  task run;
    $display("[%g]  El Test fue inicializado", $time);
    fork
      ambiente_inst.run();
    join_none
 
    // El escenario de prueba queda definido completamente por los plusargs
    // pasados desde comando.sh. No hay selección de escenario aquí.
    // Ver interface_transactions.sv y generador.sv para la lista completa
    // de plusargs disponibles.
 
    #10000
    $display("[%g]  Test: Se alcanza el tiempo limite de la prueba", $time);
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);
    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);
    #20
    ambiente_inst.checker_inst.reporte_final();
    $finish;
  endtask
endclass
