///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ambiente: conecta todos los componentes del entorno de verificación para que puedan ser usados por el test.              //
//                                                                                                                           //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ambiente #(parameter width = 16, parameter depth = 8);
  // Componentes del ambiente
  generador   #(.width(width),.depth(depth)) gen_inst;
  agent       #(.width(width),.depth(depth)) agent_inst;
  driver      #(.width(width))               driver_inst;
  monitor     #(.width(width))               monitor_inst;
  checker_c   #(.width(width),.depth(depth)) checker_inst;
  score_board #(.width(width))               scoreboard_inst;

  // Interface virtual al DUT
  virtual fifo_if #(.width(width)) _if;

  // Mailboxes internos
  fifo_pkg #(.width(width))::mbx_t gen_agent_mbx;   // generador -> agente
  fifo_pkg #(.width(width))::mbx_t agent_drv_mbx;   // agente -> driver
  fifo_pkg #(.width(width))::mbx_t agent_scrb_mbx;  // agente -> scoreboard
  fifo_pkg #(.width(width))::mbx_t sb_chkr_mbx;     // scoreboard -> checker
  fifo_pkg #(.width(width))::mbx_t mon_chkr_mbx;    // monitor -> checker
  // Mailboxes expuestos al test
  comando_test_sb_mbx  test_sb_mbx;     // test -> scoreboard
  comando_test_gen_mbx test_gen_mbx;    // test -> generador

  function new();
    // Instanciación de mailboxes
    gen_agent_mbx  = new();
    agent_drv_mbx  = new();
    agent_scrb_mbx = new();
    sb_chkr_mbx    = new();
    mon_chkr_mbx   = new();
    test_sb_mbx    = new();
    test_gen_mbx   = new();

    // Instanciación de componentes
    gen_inst        = new();
    agent_inst      = new();
    driver_inst     = new();
    monitor_inst    = new();
    checker_inst    = new();
    scoreboard_inst = new();

    // Conexiones del generador
    gen_inst.test_gen_mbx  = test_gen_mbx;
    gen_inst.gen_agent_mbx = gen_agent_mbx;

    // Conexiones del agente
    agent_inst.gen_agent_mbx  = gen_agent_mbx;
    agent_inst.agent_drv_mbx  = agent_drv_mbx;
    agent_inst.agent_scrb_mbx = agent_scrb_mbx;

    // Conexiones del driver (vif se asigna desde test_bench)
    driver_inst.vif         = _if;
    driver_inst.agnt_drv_mbx = agent_drv_mbx;

    // Conexiones del monitor (vif se asigna desde test_bench)
    monitor_inst.vif           = _if;
    monitor_inst.mon_chkr_mbx  = mon_chkr_mbx;

    // Conexiones del scoreboard
    scoreboard_inst.agnt_sb_mbx = agent_scrb_mbx;
    scoreboard_inst.sb_chkr_mbx = sb_chkr_mbx;
    scoreboard_inst.test_sb_mbx = test_sb_mbx;

    // Conexiones del checker
    checker_inst.mon_chkr_mbx = mon_chkr_mbx;
    checker_inst.sb_chkr_mbx  = sb_chkr_mbx;
  endfunction

  virtual task run();
    $display("[%g]  El ambiente fue inicializado", $time);
    fork
      gen_inst.run();
      agent_inst.run();
      driver_inst.run();
      monitor_inst.run();
      checker_inst.run();
      scoreboard_inst.run();
    join_none
  endtask
endclass
