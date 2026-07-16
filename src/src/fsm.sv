/*
    Proyecto Final: FSM para control de la red neuronal
    Estados:
      IDLE   : espera señal de start proveniente del testbench
      LAYER1 : señal para procesar 16 neuronas ocultas
      LAYER2 : señal para procesar 10 neuronas de salida
      S_DONE : activa señal de done por 1 ciclo
    Fecha: Julio/2026
*/

module fsm (
 input logic clk,
 input logic rst,
 input logic start,
 input logic last_p1,   // Como estoy usando 16 FMA, se requiere 4 pasadas para procesar los 64 pesos de la neurona, esta señal es el cambio de estado para pasar de layer 1 a layer 2
 input logic last_n1,   // Indica que la ultima neurona de la capa 1 ha sido procesada, esta señal es el cambio de estado para pasar de layer 1 a layer 2
 input logic last_n2,   // Al estar usando 16 FMA, la segunda capa no requiere varias pasadas por los FMAs. Solo me fijo que la ultima neurona haya sido procesada para pasar al estado de done.
 output logic done,
 output logic weights_layer1_rd_en, //Señal para indicar a la ROM de pesos que lea los pesos de la capa 1
 output logic weights_layer2_rd_en, //Señal para indicar a la ROM de pesos que lea los pesos de la capa 2
 output logic bias_rd_en            // Señal para indicar a la ROM de bias que lea el bias de la neurona
);
  // Estados de la FSM
  typedef enum logic [1:0] {
    IDLE   = 2'b00,   
    LAYER1 = 2'b01,   
    LAYER2 = 2'b11,   
    S_DONE = 2'b10   
  } state_t;

  state_t state, next_state;

  // Registro de estado 
  always_ff @(posedge clk or posedge rst) begin
    if (rst) state <= IDLE;
    else     state <= next_state;
  end

  // Siguiente estado
  always_comb begin
    unique case (state)
      IDLE   : next_state = start ? LAYER1 : IDLE;
      LAYER1 : next_state = (last_p1 && last_n1) ? LAYER2 : LAYER1;
      LAYER2 : next_state = last_n2 ? S_DONE : LAYER2;
      S_DONE : next_state = IDLE;
    endcase
  end

  // Salidas — mux ternario: condición ? valor_si_true : valor_si_false
  assign done                 = (state == S_DONE) ? 1'b1 : 1'b0;
  assign weights_layer1_rd_en = (state == LAYER1) ? 1'b1 : 1'b0;
  assign weights_layer2_rd_en = (state == LAYER2) ? 1'b1 : 1'b0;
  assign bias_rd_en           = (state == LAYER1) ? 1'b1 : (state == LAYER2) ? 1'b1 : 1'b0;

endmodule