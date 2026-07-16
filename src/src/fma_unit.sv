/*
  fma_unit.sv — Wrapper sobre fma_c (Booth Radix-4 + Wallace + CPA)
  
  Adapta la interfaz interna del acelerador neural_network_digits
  a la interfaz completa de fma_c sin modificar ninguno de los dos.

  Operación : out = c_in + a * b
  Operandos :
    a    → uint8  (pixel uint4 zero-extendido, o activación uint8)
    b    → int8   (peso cuantizado, complemento a dos)
    c_in → int32  (acumulador: bias o resultado FMA anterior en la cadena)
    out  → int32  (resultado, pasa al siguiente FMA o al acumulador)

  Mapeo de puertos hacia fma_c:
    srca       ← {1'b0, a}   9 bits, MSB=0 → siempre positivo en signed
    srcb       ← b           int8 signed
    srcc       ← c_in        int32 signed
    is_fma     ← 1           siempre modo FMA (sumar srcc)
    is_signed  ← 1           operación signed (b negativo debe funcionar)
    result     → out         bits [31:0] del resultado del CPA
*/

module fma_unit (
  input  logic        [7:0]  a,     // operando sin signo (pixel o activación)
  input  logic signed [7:0]  b,     // peso int8
  input  logic signed [31:0] c_in,  // acumulador de entrada
  output logic signed [31:0] out    // c_in + a*b
);

  logic [31:0] result_raw;

  fma_c #(
    .SRC1_WIDTH  (9),    // {1'b0, a}: 8-bit unsigned → 9 bits (MSB siempre 0)
    .SRC2_WIDTH  (8),    // b: int8
    .SRC3_WIDTH  (32),   // c_in: int32
    .RESULT_WIDTH(32)    // out: int32 (el producto cabe en 17b, acum en 32b)
  ) u_fma_c (
    .srca      ({1'b0, a}),   // zero-extend: garantiza que srca sea positivo
    .srcb      (b),
    .srcc      (c_in),
    .is_fma    (1'b1),        // siempre FMA: sumar c_in al producto
    .is_signed (1'b1),        // signed: b puede ser negativo
    .result    (result_raw)
  );

  assign out = $signed(result_raw);

endmodule

