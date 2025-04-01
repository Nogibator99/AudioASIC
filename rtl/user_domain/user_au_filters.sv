// gives us the `FF(...) macro making it easy to have properly defined flip-flops
`include "common_cells/registers.svh"

module user_au_filters #(
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
  output obi_rsp_t obi_rsp_o  
);

  // Request fields
  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  // Current decay setting
  logic [15:0] decay_d, decay_q;

  // Signals used to create the response
  logic [ObiCfg.DataWidth-1:0] rsp_data; // Data field of the obi response
  logic rsp_err; // Error field of the obi response

  `FF(decay_q, decay_d, '0);
  `FF(req_q, req_d, '0);
  `FF(id_q , id_d , '0);
  `FF(we_q , we_d , '0);
  `FF(wdata_q , wdata_d , '0);
  `FF(addr_q , addr_d , '0);

  assign req_d = obi_req_i.req;
  assign id_d = obi_req_i.a.aid;
  assign we_d = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;
  assign wdata_d = obi_req_i.a.wdata;

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
        2'd1: begin // set decay value
          if(we_q) begin
            decay_d = wdata_q[15:0];
          end else begin
            rsp_err = '1;
          end
        end
        2'd2: begin // read decay value
          if(we_q) begin
              rsp_err = '1;
          end else begin
            rsp_data = decay_q;
          end
        end
        2'd3: begin // read one minus decay value
          if(we_q) begin
              rsp_err = '1;
          end else begin
            rsp_data = 32'h0000_ffff - decay_q;
          end
        end
        default: rsp_data = 32'hffff_ffff;
      endcase
    end
  end

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