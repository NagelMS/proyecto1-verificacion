///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Ambiente: este módulo es el encargado de conectar todos los elementos del ambiente para que puedan ser usados por el test //
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class ambiente #(parameter width =16, parameter depth = 8);
  // Declaración de los componentes del ambiente
  driver #(.width(width)) driver_inst;
  checker_c #(.width(width),.depth(depth)) checker_inst;
  score_board #(.width(width)) scoreboard_inst;
  agent #(.width(width),.depth(depth)) agent_inst; //*
  generador #(.width(width),.depth(depth)) gen_inst; //*
  
  // Declaración de la interface que conecta el DUT 
  virtual fifo_if  #(.width(width)) _if;

  //declaración de los mailboxes
  trans_fifo_mbx agent_drv_mbx;           //mailbox del agente al driver *
  trans_fifo_mbx drv_chkr_mbx;           //mailbox del driver al checher
  trans_fifo_mbx gen_agent_mbx;           //mailboox del generador al agente *
  trans_fifo_mbx agent_scrb_mbx;          //mailbox del agente al scoreboard *
  trans_sb_mbx chkr_sb_mbx;              //mailbox del checker al scoreboard
  comando_test_sb_mbx test_sb_mbx;       //mailbox del test al scoreboard
  comando_test_agent_mbx test_gen_mbx; //mailbox del test al generador *

  function new();
    // Instanciación de los mailboxes
    drv_chkr_mbx   = new();
    agent_drv_mbx   = new(); //*
    chkr_sb_mbx    = new();
    test_sb_mbx    = new();
    test_gen_mbx   = new(); //*
    gen_agent_mbx  = new(); //*
    agent_scrb_mbx = new(); //*

    // instanciación de los componentes del ambiente
    driver_inst     = new();
    checker_inst    = new();
    scoreboard_inst = new();
    agent_inst      = new();
    gen_inst        = new(); //*
    // conexion de las interfaces y mailboxes en el ambiente
    driver_inst.vif             = _if;
    driver_inst.drv_chkr_mbx    = drv_chkr_mbx;
    driver_inst.agnt_drv_mbx    = agent_drv_mbx;
    checker_inst.drv_chkr_mbx   = drv_chkr_mbx;
    checker_inst.chkr_sb_mbx    = chkr_sb_mbx;
    scoreboard_inst.chkr_sb_mbx = chkr_sb_mbx;
    scoreboard_inst.test_sb_mbx = test_sb_mbx;
    gen_inst.test_gen_mbx   = test_gen_mbx; //*
    gen_inst.gen_agent_mbx = gen_agent_mbx; //*
    agent_inst.agent_drv_mbx = agent_drv_mbx; //*
    agent_inst.agent_scrb_mbx = agent_scrb_mbx; //*
    agent_inst.gen_agent_mbx = gen_agent_mbx; //*
  endfunction

  virtual task run();
    $display("[%g]  El ambiente fue inicializado",$time);
    fork
      driver_inst.run();
      checker_inst.run();
      scoreboard_inst.run();
      agent_inst.run();
      gen_inst.run();
    join_none
  endtask 
endclass
