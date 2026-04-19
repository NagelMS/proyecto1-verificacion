///////////////////////////////////
// Módulo para correr la prueba  //
///////////////////////////////////
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
    $display("[%g]  El Test fue inicializado", $time);
    fork
      ambiente_inst.run();
    join_none

    // Escenario: default=caso_general, con +llenado_aleatorio se cambia al otro
    if ($test$plusargs("llenado_aleatorio")) begin
      $display("[%g]  Test: escenario llenado_aleatorio (+plusarg)", $time);
      instr_gen = llenado_aleatorio;
    end else begin
      $display("[%g]  Test: escenario caso_general (default)", $time);
      instr_gen = caso_general;
    end
    test_gen_mbx.put(instr_gen);

    #10000
    $display("[%g]  Test: Se alcanza el tiempo limite de la prueba", $time);
    instr_sb = retardo_promedio;
    test_sb_mbx.put(instr_sb);
    instr_sb = reporte;
    test_sb_mbx.put(instr_sb);
    #20
    $finish;
  endtask
endclass
