/*
    Módulo: Carry Save Adder (CSA) 3:2
    Realizado por: Luis Alberto Mena González
    Fecha: Junio/2026
*/
module csa #(
  parameter int WIDTH = 32
) (
  input  logic [WIDTH-1:0] a,
  input  logic [WIDTH-1:0] b,
  input  logic [WIDTH-1:0] c,
  output logic [WIDTH-1:0] sum,
  output logic [WIDTH-1:0] carry
);
  // Carry out con que existan al menos 2 bits en 1 (a, b o c)
  // Resultado es la suma de los 3 bits (a, b y c)
  assign sum   = a ^ b ^ c;
  assign carry = (a & b) | (a & c) | (b & c);

endmodule
