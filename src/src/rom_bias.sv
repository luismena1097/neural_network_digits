/*
  Description: Single Port ROM — Bias memory
  
  Contenido : 26 biases int32
                índices  0..15 → bias capa 1  (16 neuronas ocultas)
                índices 16..25 → bias capa 2  (10 neuronas de salida)
  Data width: 32 bits (int32, complemento a dos)
  Addr width:  5 bits  (2^5 = 32 entradas ≥ 26)
  Profundidad: 26 entradas
  
  Formato de biases.hex: un valor hexadecimal de 32 bits por línea,
  en complemento a dos (p.ej. FFFFFFA3 para un bias negativo).
*/

module rom_bias
#(parameter DATA_WIDTH = 32,  // int32
  parameter ADDR_WIDTH = 5,   // 2^5 = 32 >= 26
  parameter DEPTH      = 26   // 16 biases capa1 + 10 biases capa2
)
  (input logic  [ADDR_WIDTH-1:0] addr,
   output logic signed[DATA_WIDTH-1:0] q );  // salida signed: el datapath la suma directamente

// Declaración de la ROM
logic signed [DATA_WIDTH-1:0] rom [0:DEPTH-1];

// Formato: un valor hex de 8 dígitos por línea (32 bits).
initial
  begin
    $readmemh("../neural_network/biases.hex", rom);
  end

assign q = rom[addr];

endmodule
