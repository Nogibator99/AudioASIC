`include "common_cells/registers.svh"
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

  // Current filter coefficient
  logic signed [31:0] decay_d, decay_q;

  // OBI request fields
  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  // Signals used to create OBI response
  logic [ObiCfg.DataWidth-1:0] rsp_data; // Data field of the obi response
  logic rsp_err; // Error field of the obi response

  `FF(decay_q, decay_d, '0);
  `FF(req_q, req_d, '0);
  `FF(we_q, we_d , '0);
  `FF(addr_q, addr_d , '0);
  `FF(id_q, id_d , '0);
  `FF(wdata_q, wdata_d , '0);

  // Wire OBI request
  assign req_d = obi_req_i.req;
  assign id_d = obi_req_i.a.aid;
  assign we_d = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;
  assign wdata_d = obi_req_i.a.wdata;

  // Wire OBI response
  // A channel
  assign obi_rsp_o.gnt = obi_req_i.req;
  // R channel:
  assign obi_rsp_o.rvalid = req_q;
  assign obi_rsp_o.r.rid = id_q;
  assign obi_rsp_o.r.err = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;
  assign obi_rsp_o.r.rdata = rsp_data;

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

  // Create individual filter stages
  genvar i;
  generate
    for (i = 0; i < NUM_STAGES; i++) begin : gen_filter_stages
      user_au_LPF_stage i_filter (
        .clk_i,
        .rst_ni,
        .data_i     ( data_s[i]  ),
        .valid_i    ( valid_s[i] ),
        .ready_o    ( ready_s[i] ),
        .data_o     ( data_s[i+1]),
        .valid_o    ( valid_s[i+1]),
        .ready_i    ( ready_s[i+1]),
        .decay_i    ( decay_q     )
      );
    end
  endgenerate

  // Handle OBI transaction
  always_comb begin
    rsp_data = '0;
    rsp_err  = '0;
    decay_d = decay_q;

    if(req_q) begin
      case(addr_q[3:2])
        2'd0: begin // reset
          if(we_q) begin
            decay_d = '0;
          end else begin
            rsp_err = '1;
          end
        end
        2'd1: begin // set/read decay value
          if(we_q) begin
            decay_d = wdata_q;
          end else begin
            rsp_data = decay_q;
          end
        end
        //default: rsp_data = 32'hffff_ffff;
      endcase
    end
  end

endmodule


