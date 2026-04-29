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
 
    // Espera a que el generador termine de encolar todas las transacciones
    wait(ambiente_inst.gen_inst.done == 1);
    $display("[%g]  Test: Generador finalizado, esperando que el pipeline se vacíe", $time);

    // Espera a que los mailboxes del pipeline se vacíen (todas las transacciones ejecutadas)
    while (ambiente_inst.agent_drv_mbx.num()  > 0 ||
           ambiente_inst.gen_agent_mbx.num()  > 0 ||
           ambiente_inst.mon_chkr_mbx.num()   > 0 ||
           ambiente_inst.sb_chkr_mbx.num()    > 0) begin
      @(posedge _if.clk);
    end

    // Ciclos extra para que la última transacción se propague por el monitor y el checker
    repeat(20) @(posedge _if.clk);

    $display("[%g]  Test: Pipeline vacío — generando reporte final", $time);
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);
    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);
    #20
    ambiente_inst.checker_inst.reporte_final();
    $finish;
  endtask
endclass
