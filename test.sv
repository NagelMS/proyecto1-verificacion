///////////////////////////////////
// Módulo para correr la prueba  //
///////////////////////////////////
class test #(parameter width = 16, parameter depth = 8);

  comando_test_sb_mbx  test_sb_mbx;
  comando_test_gen_mbx test_gen_mbx;

  parameter num_transacciones = depth;
  parameter max_retardo = 4;
  solicitud_sb      instr_sb;
  instrucciones_gen instr_gen;

  ambiente #(.depth(depth),.width(width)) ambiente_inst;
  virtual fifo_if  #(.width(width)) _if;

  function new;
    test_sb_mbx  = new();
    test_gen_mbx = new();

    ambiente_inst = new();
    ambiente_inst._if = _if;

    // Conectar mailboxes expuestos del ambiente
    ambiente_inst.test_sb_mbx  = test_sb_mbx;
    ambiente_inst.test_gen_mbx = test_gen_mbx;

    // Conectar directamente a los componentes internos
    ambiente_inst.scoreboard_inst.test_sb_mbx = test_sb_mbx;
    ambiente_inst.gen_inst.test_gen_mbx        = test_gen_mbx;
    ambiente_inst.gen_inst.num_transacciones   = num_transacciones;
    ambiente_inst.gen_inst.max_retardo         = max_retardo;
  endfunction

  task run;
    $display("[%g]  El Test fue inicializado", $time);
    fork
      ambiente_inst.run();
    join_none

    instr_gen = llenado_aleatorio;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: instruccion llenado_aleatorio enviada al generador (num_transacciones=%0g)", $time, num_transacciones);

    instr_gen = trans_aleatoria;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: instruccion trans_aleatoria enviada al generador", $time);

    ambiente_inst.gen_inst.ret_spec = 3;
    ambiente_inst.gen_inst.tpo_spec = escritura;
    ambiente_inst.gen_inst.dto_spec = {width/4{4'h5}};
    instr_gen = trans_especifica;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: instruccion trans_especifica enviada al generador", $time);

    instr_gen = sec_trans_aleatorias;
    test_gen_mbx.put(instr_gen);
    $display("[%g]  Test: instruccion sec_trans_aleatorias enviada al generador (num_transacciones=%0g)", $time, num_transacciones);

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
