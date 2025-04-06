// gives us the `FF(...) macro making it easy to have properly defined flip-flops
`include "common_cells/registers.svh"

module user_au_audio_interface #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type                         obi_req_t   = logic,
  /// The response struct.
  parameter type                         obi_rsp_t   = logic
) (
  /// Clock
  input  logic clk_i,
  /// Active-low reset
  input  logic rst_ni,

  /// OBI request interface
  input  obi_req_t obi_req_i,
  /// OBI response interface
  output obi_rsp_t obi_rsp_o,


  /// Input audio sample
  input  logic [31:0] data_i,
  /// New input sample is valid
  input  logic        valid_i,
  /// We're ready to receive new sample
  output logic        ready_o,

  /// Output audio sample
  output logic [31:0] data_o,
  /// New output sample is valid
  output logic        valid_o,
  /// Next module is ready to receive new sample
  input  logic        ready_i
);

  // Request fields
  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  // Signals used to create the response
  logic [ObiCfg.DataWidth-1:0] rsp_data; // Data field of the obi response
  logic rsp_err; // Error field of the obi response

  logic [31:0] data_i_from_fx_d, data_i_from_fx_q;
  logic [31:0] data_o_to_fx_d, data_o_to_fx_q;
  logic        valid_o_to_fx_d, valid_o_to_fx_q;

  `FF(req_q, req_d, '0);
  `FF(we_q, we_d, '0);
  `FF(addr_q, addr_d, '0);
  `FF(id_q, id_d, '0);
  `FF(wdata_q, wdata_d, '0);

  `FF(data_i_from_fx_q, data_i_from_fx_d, '0);
  `FF(data_o_to_fx_q, data_o_to_fx_d, '0);
  `FF(valid_o_to_fx_q, valid_o_to_fx_d, '0);

  assign req_d = obi_req_i.req;
  assign id_d = obi_req_i.a.aid;
  assign we_d = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;
  assign wdata_d = obi_req_i.a.wdata;

  always_comb begin
    rsp_data = '0;
    rsp_err  = '0;

     // Send or receive data to/from effect
    valid_o_to_fx_d = valid_o_to_fx_q;
    data_o_to_fx_d = data_o_to_fx_q;
    data_i_from_fx_d = data_i_from_fx_q;

    if(valid_o_to_fx_q & ready_i) begin
      valid_o_to_fx_d = 0;
      data_o_to_fx_d = '0;
    end
    if(valid_i) begin
      data_i_from_fx_d = data_i;
    end

     // Receive/send data via OBI
    if(req_q) begin
      case(addr_q[2])
        1'd0: begin // write new sample value to effect
          if(we_q) begin
            data_o_to_fx_d = {{16{wdata_q[15]}}, wdata_q[15:0]};
            valid_o_to_fx_d = 1;
          end else begin
            rsp_err = '1;
          end
        end
        1'd1: begin // return current sample value
        if(we_q) begin
            rsp_err = '1;
          end else begin
            rsp_data = data_i_from_fx_q[15:0];
          end
        end
        default: rsp_data = 32'hffff_ffff;
      endcase
    end
  end

  assign ready_o = 1;
  assign valid_o = valid_o_to_fx_q;
  assign data_o = data_o_to_fx_q;

  // Wire the response
  // A channel
  assign obi_rsp_o.gnt = obi_req_i.req;
  // R channel:
  assign obi_rsp_o.rvalid = req_q;
  assign obi_rsp_o.r.rid = id_q;
  assign obi_rsp_o.r.err = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;
  assign obi_rsp_o.r.rdata = rsp_data;
  
endmodule