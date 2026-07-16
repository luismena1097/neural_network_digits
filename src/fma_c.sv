/*
    Módulo: Booth-Wallace FMA  –  (srca × srcb) + srcc 
    Realizado por: Luis Alberto Mena González

    Recoding table Booth Radix-4
    000                        →   0
    001                        →  +A
    010                        →  +A
    011                        →  +2A
    100                        →  -2A
    101                        →  -A
    110                        →  -A
    111                        →   0

    Fecha: Junio/2026
*/

// Usando interface propuesta por el profe
module fma_c #(
  parameter  int SRC1_WIDTH   = 64,
  parameter  int SRC2_WIDTH   = SRC1_WIDTH,
  parameter  int SRC3_WIDTH   = SRC1_WIDTH,
  parameter int RESULT_WIDTH = (SRC1_WIDTH + SRC2_WIDTH)
) (
  input  logic [SRC1_WIDTH-1:0]   srca,
  input  logic [SRC2_WIDTH-1:0]   srcb,
  input  logic [SRC3_WIDTH-1:0]   srcc,
  input  logic                    is_fma,
  input  logic                    is_signed,
  output logic [RESULT_WIDTH-1:0] result
);

  // Optimizacion de Baugh-Wooley para manejar Two's complement nativamente. Sin pre-conversión ni post-conversión.
  // srca_s: N+2 bits para que ±2A no desborde al desplazar a la izquierda
  logic signed [SRC1_WIDTH+1:0] srca_s;
  assign srca_s = is_signed ? {{2{srca[SRC1_WIDTH-1]}}, srca} : {2'b00, srca};

  localparam int NUM_PP = SRC2_WIDTH / 2 + 1;
  localparam int NUM_IN  = NUM_PP + 1;          // PPs de Booth + srcc (FMA)

  // srcb extendido: signo-extiende para signed, zero-extiende para unsigned
  logic [SRC2_WIDTH+2:0] srcb_ext;
  assign srcb_ext = is_signed ? {srcb[SRC2_WIDTH-1], srcb[SRC2_WIDTH-1], srcb, 1'b0} : {2'b00, srcb, 1'b0};

  // pp[i]: N+2 bits, complemento a 2 directo (Baugh-Wooley)
  logic signed [SRC1_WIDTH+1:0] pp [NUM_PP];

  // Tabla de Booth
  genvar i;
  generate
    for (i = 0; i < NUM_PP; i++) begin : gen_booth
      logic signed [SRC1_WIDTH+1:0] pp_i;
      always_comb begin
        case (srcb_ext[2*i+2 -: 3])
          3'b000:  pp_i =  '0;              //  0
          3'b001:  pp_i =  srca_s;          // +A
          3'b010:  pp_i =  srca_s;          // +A
          3'b011:  pp_i =  srca_s <<< 1;    // +2A
          3'b100:  pp_i = -(srca_s <<< 1);  // -2A
          3'b101:  pp_i = -srca_s;          // -A
          3'b110:  pp_i = -srca_s;          // -A
          3'b111:  pp_i =  '0;              //  0
          default: pp_i =  '0;
        endcase
      end
      assign pp[i] = pp_i;
    end
  endgenerate

  // Arbol de Wallace instanciando CSA
  // TREE_W: ancho uniforme del árbol (+1 sobre RESULT_WIDTH para cubrir el
  // bit de signo extendido de los PPs negativos sin overflow )
  localparam int TREE_W     = RESULT_WIDTH + 1;

  logic [TREE_W-1:0] srcc_ext;
  always_comb begin
    if (!is_fma)        srcc_ext = '0;
    else if (is_signed) srcc_ext = TREE_W'(signed'(srcc));
    else                srcc_ext = TREE_W'(srcc);
  end

  // Número de etapas CSA (2·⌈log2(NUM_IN)⌉ + 2)
  localparam int CSA_ETAPAS = 2 * $clog2(NUM_IN < 2 ? 2 : NUM_IN) + 2;

  // Función que calcula cuántos operandos quedan activos tras s etapas
  // de reducción 3→2: cada grupo de 3 produce 2 salidas, el resto pasa.
  function automatic int wt_n(int n_init, int s);
    automatic int n = n_init;
    for (int k = 0; k < s; k++) n = 2*(n/3) + (n%3);
    return n;
  endfunction

  // Arreglo en 2 dimenciones para llevar control de la etapa y el producto parcial que entra al arbol
  logic [TREE_W-1:0] wt [CSA_ETAPAS][NUM_IN];

  genvar gi, gs, gk, gj, cb;
  generate

    // Etapa 0: cargar los productos parciales 
    // pp[gi] ya es CA2 con signo correcto y se extiende el signo
    // a TREE_W bits y se desplaza 2*gi posiciones (peso 4^gi de Booth R-4).
    for (gi = 0; gi < NUM_PP; gi++) begin : g_init
      assign wt[0][gi] = TREE_W'(signed'(pp[gi])) << (2*gi);
    end

    // FMA: srcc entra al árbol sin desplazamiento (peso 2^0)
    assign wt[0][NUM_PP] = srcc_ext;

    // ── Etapas de reducción 3→2 ────────────────────────────────────────
    for (gs = 0; gs < CSA_ETAPAS-1; gs++) begin : g_stage

      for (gk = 0; gk < NUM_IN/3; gk++) begin : g_csa
        if (gk < wt_n(NUM_IN, gs)/3) begin : g_act
          logic [TREE_W-1:0] csa_s, csa_co;
          csa #(.WIDTH(TREE_W)) u_csa (
            .a    (wt[gs][3*gk  ]),
            .b    (wt[gs][3*gk+1]),
            .c    (wt[gs][3*gk+2]),
            .sum  (csa_s),
            .carry(csa_co)
          );
          assign wt[gs+1][2*gk  ] = csa_s;

          // El carry sale desplazado +1 bit (peso columna +1)
          assign wt[gs+1][2*gk+1] = {csa_co[TREE_W-2:0], 1'b0};
        end
      end

      // Se pasan los bits que no forman grupos de 3 para rellenarse con ceros los bits faltantes
      for (gj = 0; gj < NUM_IN; gj++) begin : g_fill
        if (gj >= 2*(wt_n(NUM_IN,gs)/3) &&
            gj <  2*(wt_n(NUM_IN,gs)/3) + wt_n(NUM_IN,gs)%3) begin : g_pt
          assign wt[gs+1][gj] =
            wt[gs][3*(wt_n(NUM_IN,gs)/3) + gj - 2*(wt_n(NUM_IN,gs)/3)];
        end else if (gj >= 2*(wt_n(NUM_IN,gs)/3) + wt_n(NUM_IN,gs)%3) begin : g_zf
          assign wt[gs+1][gj] = '0;
        end
      end

    end
  endgenerate

  // CPA final: Carry Select Adder
  // Cada bloque realiza la suma con cin=0 y cin=1 en paralelo;
  // un mux selecciona el resultado correcto según el carry propagado.
  localparam int CPA_BLK  = 16;
  localparam int CPA_BLKS = (TREE_W + CPA_BLK - 1) / CPA_BLK;
  localparam int CPA_W    = CPA_BLKS * CPA_BLK;   // ancho paddeado

  logic [CPA_W-1:0] cs_a, cs_b;
  assign cs_a = CPA_W'(wt[CSA_ETAPAS-1][0]);   // zero-extend
  assign cs_b = CPA_W'(wt[CSA_ETAPAS-1][1]);

  logic [CPA_BLKS:0] blk_c;    // blk_c[i] = carry de entrada al bloque i
  logic [CPA_W-1:0]  cs_sum;
  assign blk_c[0] = 1'b0;

  generate
    for (cb = 0; cb < CPA_BLKS; cb++) begin : g_csla
      logic [CPA_BLK:0] s0, s1;
      // suma asumiendo cin = 0
      assign s0 = {1'b0, cs_a[cb*CPA_BLK +: CPA_BLK]}
                + {1'b0, cs_b[cb*CPA_BLK +: CPA_BLK]};
      // suma asumiendo cin = 1
      assign s1 = {1'b0, cs_a[cb*CPA_BLK +: CPA_BLK]}
                + {1'b0, cs_b[cb*CPA_BLK +: CPA_BLK]}
                + {{CPA_BLK{1'b0}}, 1'b1};
      // mux de selección
      assign cs_sum[cb*CPA_BLK +: CPA_BLK] = blk_c[cb] ? s1[CPA_BLK-1:0] : s0[CPA_BLK-1:0];
      assign blk_c[cb+1] = blk_c[cb] ? s1[CPA_BLK] : s0[CPA_BLK];
    end
  endgenerate

  logic [TREE_W-1:0] cpa_result;
  assign cpa_result = cs_sum[TREE_W-1:0];

  assign result = cpa_result[RESULT_WIDTH-1:0];

endmodule
