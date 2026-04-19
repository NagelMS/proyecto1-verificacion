/*  
    Monitor para verificar las transacciones en la FIFO. 
    Este monitor se conecta a la interfaz virtual del DUT
    y envía las transacciones a un mailbox para que el checker 
    pueda verificarlas.
*/

class monitor #(parameter width =16);
  
    virtual fifo_if #(.width(width)) vif; // Interfaz virtual
    trans_fifo_mbx mon_chkr_mbx; // Mailbox hacia el checker

    task run();
        $display("[%g] El monitor fue inicializado", $time);
        forever begin
            trans_fifo #(.width(width)) transaction;
            // Se muestrea en el negedge para estabilidad de las señales 
            // y para capturar el dato correcto
            @(negedge vif.clk);
            if (vif.rst) begin
                transaction = new();
                transaction.tipo   = reset;
                transaction.tiempo = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Reset detectado");
            end else if (vif.push && vif.pop) begin
                transaction = new();
                transaction.tipo       = lectura_escritura;
                transaction.dato       = vif.dato_in;  // dato que entra (escritura)
                transaction.dato_leido = vif.dato_out; // dato que sale (lectura)
                transaction.tiempo     = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Lectura+Escritura simultanea detectada");
            end else if (vif.push) begin
                transaction = new();
                transaction.tipo   = escritura;
                transaction.dato   = vif.dato_in;
                transaction.tiempo = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Escritura detectada");
            end else if (vif.pop) begin
                transaction = new();
                transaction.tipo       = lectura;
                transaction.dato_leido = vif.dato_out;
                transaction.tiempo     = $time;
                mon_chkr_mbx.put(transaction);
                transaction.print("Monitor: Lectura detectada");
            end
        end
    endtask
endclass