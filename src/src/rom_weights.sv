/*
	Description: Single Port ROM — salida de N_WORDS pesos por ciclo
	Dado 'addr' como dirección base, entrega los pesos:
	  q[7:0]               = rom[addr + 0]
	  q[15:8]              = rom[addr + 1]
	  ...
	  q[N_WORDS*8-1 : -:8] = rom[addr + N_WORDS-1]
	Date : 08/February/2025 — modificado Julio/2026
*/

module rom_weights
#(parameter DATA_WIDTH = 8,     // bits por peso
  parameter ADDR_WIDTH = 11,    // bits de dirección (2^11 = 2048 >= 1184)
  parameter DEPTH      = 1184,  // número total de pesos
  parameter N_WORDS    = 16     // pesos entregados por ciclo
)
(
  input logic  [ADDR_WIDTH-1:0]       addr,  // dirección base
  output logic [N_WORDS*DATA_WIDTH-1:0] q    // N_WORDS pesos packed: q[k*8+:8] = peso k
);

logic [DATA_WIDTH-1:0] rom [0:DEPTH-1];

initial
  begin
    $readmemh("../neural_network/weights.hex", rom);
  end

// N_WORDS lecturas simultáneas a partir de addr
genvar k;
generate
  for (k = 0; k < N_WORDS; k++) begin : gen_rd
    assign q[k*DATA_WIDTH +: DATA_WIDTH] = rom[addr + ADDR_WIDTH'(k)];
  end
endgenerate

endmodule
