// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

module user_domain import user_pkg::*; import croc_pkg::*; #(
  parameter int unsigned GpioCount = 16
) (
  input  logic      clk_i,
  input  logic      ref_clk_i,
  input  logic      rst_ni,
  input  logic      testmode_i,
  
  input  sbr_obi_req_t user_sbr_obi_req_i, // User Sbr (rsp_o), Croc Mgr (req_i)
  output sbr_obi_rsp_t user_sbr_obi_rsp_o,

  output mgr_obi_req_t user_mgr_obi_req_o, // User Mgr (req_o), Croc Sbr (rsp_i)
  input  mgr_obi_rsp_t user_mgr_obi_rsp_i,

  input  logic [      GpioCount-1:0] gpio_in_sync_i, // synchronized GPIO inputs
  output logic [NumExternalIrqs-1:0] interrupts_o // interrupts to core
);

  assign interrupts_o = '0;  


  //////////////////////
  // User Manager MUX //
  /////////////////////

  // No manager so we don't need a obi_mux module and just terminate the request properly
  assign user_mgr_obi_req_o = '0;


  ////////////////////////////
  // User Subordinate DEMUX //
  ////////////////////////////

  // ----------------------------------------------------------------------------------------------
  // User Subordinate Buses
  // ----------------------------------------------------------------------------------------------
  
  // collection of signals from the demultiplexer
  sbr_obi_req_t [NumDemuxSbr-1:0] all_user_sbr_obi_req;
  sbr_obi_rsp_t [NumDemuxSbr-1:0] all_user_sbr_obi_rsp;

  // Error Subordinate Bus
  sbr_obi_req_t user_error_obi_req;
  sbr_obi_rsp_t user_error_obi_rsp;

  // LPF and HPF Cascade Bus
  sbr_obi_req_t user_au_filters_cascade_obi_req;
  sbr_obi_rsp_t user_au_filters_cascade_obi_rsp;

  // Audio Interface Bus
  sbr_obi_req_t user_au_audio_interface_obi_req;
  sbr_obi_rsp_t user_au_audio_interface_obi_rsp;

  // Fanout into more readable signals
  assign user_error_obi_req                          = all_user_sbr_obi_req[UserError];
  assign all_user_sbr_obi_rsp[UserError]             = user_error_obi_rsp;
  assign user_au_filters_cascade_obi_req             = all_user_sbr_obi_req[UserAuFiltersCascade];
  assign all_user_sbr_obi_rsp[UserAuFiltersCascade]  = user_au_filters_cascade_obi_rsp;
  assign user_au_audio_interface_obi_req             = all_user_sbr_obi_req[UserAuAudioInterface];
  assign all_user_sbr_obi_rsp[UserAuAudioInterface]  = user_au_audio_interface_obi_rsp;

  // Filter modules interconnect
  logic [31:0] audio_interface_data_i;
  logic        audio_interface_valid_i;
  logic        audio_interface_ready_o;
  logic [31:0] audio_interface_data_o;
  logic        audio_interface_valid_o;
  logic        audio_interface_ready_i;

  logic [31:0] from_LPF_data_o;
  logic        from_LPF_valid_o;
  logic        to_LPF_ready_i;

  //-----------------------------------------------------------------------------------------------
  // Demultiplex to User Subordinates according to address map
  //-----------------------------------------------------------------------------------------------

  logic [cf_math_pkg::idx_width(NumDemuxSbr)-1:0] user_idx;

  addr_decode #(
    .NoIndices ( NumDemuxSbr                    ),
    .NoRules   ( NumDemuxSbrRules               ),
    .addr_t    ( logic[SbrObiCfg.DataWidth-1:0] ),
    .rule_t    ( addr_map_rule_t                ),
    .Napot     ( 1'b0                           )
  ) i_addr_decode_periphs (
    .addr_i           ( user_sbr_obi_req_i.a.addr ),
    .addr_map_i       ( user_addr_map             ),
    .idx_o            ( user_idx                  ),
    .dec_valid_o      (),
    .dec_error_o      (),
    .en_default_idx_i ( 1'b1 ),
    .default_idx_i    ( '0   )
  );

  obi_demux #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMgrPorts ( NumDemuxSbr   ),
    .NumMaxTrans ( 2             )
  ) i_obi_demux (
    .clk_i,
    .rst_ni,

    .sbr_port_select_i ( user_idx             ),
    .sbr_port_req_i    ( user_sbr_obi_req_i   ),
    .sbr_port_rsp_o    ( user_sbr_obi_rsp_o   ),

    .mgr_ports_req_o   ( all_user_sbr_obi_req ),
    .mgr_ports_rsp_i   ( all_user_sbr_obi_rsp )
  );


//-------------------------------------------------------------------------------------------------
// User Subordinates
//-------------------------------------------------------------------------------------------------

  // Error Subordinate
  obi_err_sbr #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMaxTrans ( 1             ),
    .RspData     ( 32'hBADCAB1E  )
  ) i_user_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( testmode_i      ),
    .obi_req_i  ( user_error_obi_req ),
    .obi_rsp_o  ( user_error_obi_rsp )
  );

  // Audio Interface Module
  user_au_audio_interface #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t )
  ) i_au_interface (
    .clk_i,
    .rst_ni,
    .obi_req_i  ( user_au_audio_interface_obi_req   ),
    .obi_rsp_o  ( user_au_audio_interface_obi_rsp   ),
    .data_i     ( audio_interface_data_i            ),
    .valid_i    ( audio_interface_valid_i           ),
    .ready_o    ( audio_interface_ready_o           ),
    .data_o     ( audio_interface_data_o            ),
    .valid_o    ( audio_interface_valid_o           ),
    .ready_i    ( audio_interface_ready_i           )
  );

  // LPF Cascade Module
  user_au_LPF_cascade #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NUM_STAGES  ( 2             )
  ) i_au_LPF_cascade (
    .clk_i,
    .rst_ni,
    .obi_req_i  ( user_au_filters_cascade_obi_req ),
    .obi_rsp_o  ( user_au_filters_cascade_obi_rsp ),
    .data_i     ( audio_interface_data_o          ),
    .valid_i    ( audio_interface_valid_o         ),
    .ready_o    ( audio_interface_ready_i         ),
    .data_o     ( from_LPF_data_o                 ),
    .valid_o    ( from_LPF_valid_o                ),
    .ready_i    ( to_LPF_ready_i                  )
  );

  // HPF Cascade Module
  user_au_HPF_cascade #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NUM_STAGES  ( 2             )
  ) i_au_HPF_cascade (
    .clk_i,
    .rst_ni,
    .obi_req_i  ( user_au_filters_cascade_obi_req ),
    .obi_rsp_o  ( user_au_filters_cascade_obi_rsp ),
    .data_i     ( from_LPF_data_o                 ),
    .valid_i    ( from_LPF_valid_o                ),
    .ready_o    ( to_LPF_ready_i                  ),
    .data_o     ( audio_interface_data_i          ),
    .valid_o    ( audio_interface_valid_i         ),
    .ready_i    ( audio_interface_ready_o         )
  );

  

endmodule
