`include "common_cells/registers.svh"

module user_au_HPF_stage (
  /// Clock
  input  logic clk_i,
  /// Active-low reset
  input  logic rst_ni,

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
  input  logic               ready_i,
  /// Filter decay, set from cascade wrapper
  input logic signed [31:0]  decay_i
);

  // State of the module
  logic busy_d, busy_q;
  
  // Data samples
  logic signed [31:0] curr_data_d, curr_data_q;
  logic signed [31:0] prev_data_d, prev_data_q;
  logic signed [31:0] prev_out_d, prev_out_q;

  `FF(busy_q, busy_d , '0);
  `FF(curr_data_q, curr_data_d , '0);
  `FF(prev_data_q, prev_data_d , '0);
  `FF(prev_out_q, prev_out_d , '0);

  // Output sample calculation
  always_comb begin
    busy_d = busy_q;
    curr_data_d = curr_data_q;
    prev_data_d = prev_data_q;
    prev_out_d = prev_out_q;
    data_o = '0;

    if(busy_q) begin 
      // Ready to send data
      ready_o = 0;
      valid_o = 1;
      data_o =  ((decay_i * (curr_data_q - prev_data_q + (prev_out_q <<< 1))) >>> 11) - prev_out_q;
      if(ready_i) begin 
        // Send data
        busy_d = 0;
        prev_out_d = data_o;
        prev_data_d = curr_data_q;
      end
    end else begin
      // Ready to receive new data
      ready_o = 1;
      valid_o = 0;
      if(valid_i) begin 
        // Receive new data
        busy_d = 1;
        curr_data_d = data_i;
      end
    end
  end

endmodule