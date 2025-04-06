module user_au_LPF_cascade #(
  parameter int NUM_STAGES = 2,
   /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type                         obi_req_t   = logic,
  /// The response struct.
  parameter type                         obi_rsp_t   = logic
)(
  /// Clock
  input  logic clk_i,
  /// Active-low reset
  input  logic rst_ni,

  /// OBI request interface
  input  obi_req_t obi_req_i,
  /// OBI response interface
  output obi_rsp_t obi_rsp_o,


  /// Input audio sample
  input  logic signed [31:0] data_i,
  /// New input sample is valid
  input  logic               valid_i,
  /// We're ready to receive new sample
  output logic               ready_o,

  /// Output audio sample
  output logic signed [31:0] data_o,
  /// New output sample is valid
  output logic               valid_o,
  /// Next module is ready to receive new sample
  input  logic               ready_i
);

  // Inter-stage signals
  logic [NUM_STAGES:0][31:0] data_s;
  logic [NUM_STAGES:0]       valid_s;
  logic [NUM_STAGES:0]       ready_s;

  // Connect external signals to stage 0
  assign data_s[0]  = data_i;
  assign valid_s[0] = valid_i;
  assign ready_o    = ready_s[0];

  // Connect last stage to output
  assign data_o     = data_s[NUM_STAGES];
  assign valid_o    = valid_s[NUM_STAGES];
  assign ready_s[NUM_STAGES] = ready_i;

  genvar i;
  generate
    for (i = 0; i < NUM_STAGES; i++) begin : gen_filter_stages
      user_au_LPF_stage #(
        .ObiCfg     ( ObiCfg      ),
        .obi_req_t  ( obi_req_t   ),
        .obi_rsp_t  ( obi_rsp_t   )
      ) i_filter (
        .clk_i,
        .rst_ni,
        .obi_req_i  ( obi_req_i  ), // Same OBI bus reused
        .obi_rsp_o  ( obi_rsp_o  ),
        .data_i     ( data_s[i]  ),
        .valid_i    ( valid_s[i] ),
        .ready_o    ( ready_s[i] ),
        .data_o     ( data_s[i+1]),
        .valid_o    ( valid_s[i+1]),
        .ready_i    ( ready_s[i+1])
      );
    end
  endgenerate

endmodule
