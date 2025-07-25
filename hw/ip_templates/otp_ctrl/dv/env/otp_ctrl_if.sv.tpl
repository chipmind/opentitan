// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
<%
from topgen.lib import Name
unbuf_parts_with_digest = [part for part in otp_mmap["partitions"] if
                           part["variant"] == "Unbuffered" and
                           (part["sw_digest"] or part["hw_digest"])]
parts_without_lc = [part for part in otp_mmap["partitions"] if
                    part["variant"] in ["Buffered", "Unbuffered"]]
buf_parts_without_lc = [part for part in otp_mmap["partitions"] if
                        part["variant"] == "Buffered"]
%>\
// This interface collect the broadcast output data from OTP,
// and drive input requests coming into OTP.
`define ECC_REG_PATH gen_ecc_reg.u_otp_ctrl_ecc_reg.gen_ecc_dec[0].u_prim_secded_inv_72_64_dec

// This only supports buffered partitions.
`define BUF_PART_OTP_CMD_PATH(i) ${"\\"}
    tb.dut.gen_partitions[``i``].gen_buffered.u_part_buf.otp_cmd_o

`define LC_PART_OTP_CMD_PATH ${"\\"}
    tb.dut.gen_partitions[LifeCycleIdx].gen_lifecycle.u_part_buf.otp_cmd_o

`define FORCE_OTP_PART_LOCK_WITH_RAND_NON_MUBI_VAL(i) ${"\\"}
  if (forced_part_access_sel[``i``].read_lock) begin ${"\\"}
    force tb.dut.part_access[``i``].read_lock = get_rand_mubi8_val(.t_weight(0), .f_weight(0)); ${"\\"}
    force tb.dut.part_access_dai[``i``].read_lock = get_rand_mubi8_val(.t_weight(0), .f_weight(0)); ${"\\"}
  end ${"\\"}
  if (forced_part_access_sel[``i``].write_lock) begin ${"\\"}
    force tb.dut.part_access[``i``].write_lock = get_rand_mubi8_val(.t_weight(0), .f_weight(0)); ${"\\"}
    force tb.dut.part_access_dai[``i``].write_lock = get_rand_mubi8_val(.t_weight(0), .f_weight(0)); ${"\\"}
  end

`ifndef PRIM_GENERIC_OTP_PATH
  `define PRIM_GENERIC_OTP_PATH${"\\"}
      tb.otp_macro
`endif

`ifndef PRIM_GENERIC_OTP_CMD_I_PATH
  `define PRIM_GENERIC_OTP_CMD_I_PATH ${"\\"}
      `PRIM_GENERIC_OTP_PATH.otp_i.cmd
`endif

interface otp_ctrl_if(input clk_i, input rst_ni);
  import uvm_pkg::*;
  import otp_ctrl_env_pkg::*;
  import otp_ctrl_pkg::*;
  import otp_ctrl_reg_pkg::*;
  import otp_ctrl_part_pkg::*;
  import otp_macro_pkg::*;
  import cip_base_pkg::*;

  // Output from DUT
  otp_broadcast_t    otp_broadcast_o;
  otp_keymgr_key_t   keymgr_key_o;
  otp_lc_data_t      lc_data_o;
  logic              pwr_otp_done_o, pwr_otp_idle_o;

  // Inputs to DUT
  logic                   pwr_otp_init_i, scan_en_i, scan_rst_ni, ext_voltage_h_io;
  lc_ctrl_pkg::lc_tx_t    lc_dft_en_i, lc_escalate_en_i, lc_check_byp_en_i,
                          lc_creator_seed_sw_rw_en_i, lc_owner_seed_sw_rw_en_i,
                          lc_seed_hw_rd_en_i;
  prim_mubi_pkg::mubi4_t  scanmode_i;
  otp_ast_rsp_t           otp_ast_pwr_seq_h_i;
  ast_pkg::ast_obs_ctrl_t obs_ctrl_i;

  // Unused in prim_generic_otp memory.
  logic [OtpTestCtrlWidth-1:0]   otp_vendor_test_ctrl_i;
  logic [OtpTestStatusWidth-1:0] otp_vendor_test_status_o;
  logic [OtpTestVectWidth-1:0]   cio_test_o;
  logic [OtpTestVectWidth-1:0]   cio_test_en_o;

  // Connect with lc_prog push_pull interface.
  logic lc_prog_req, lc_prog_err;
  logic lc_prog_err_dly1, lc_prog_no_sta_check;

  // Connect push_pull interfaces ack signals for assertion checks.
  logic otbn_ack, lc_prog_ack;
% if enable_flash_key:
  logic [1:0] flash_acks;
% endif
  logic [NumSramKeyReqSlots-1:0] sram_acks;

  // Variables for internal interface logic.
  // `lc_escalate_en` is async, take two clock cycles to synchronize.
  lc_ctrl_pkg::lc_tx_t lc_esc_dly1, lc_esc_dly2;

  // Variable for scoreboard.
  // For `lc_escalate_en`, any value that is not `Off` is a `On`.
  bit lc_esc_on;

  // Probe design signal for alert request.
  logic alert_reqs;

  // Usually the `lc_check_byp_en` will be automatically set to `On` when LC program request is
  // issued, and stays `On` until reset is issued.
  // Set this variable to 0 after a LC program request might cause otp checks to fail.
  bit lc_check_byp_en = 1;

  // Internal variable to track which sw partitions have ECC reg error.
  bit [NumPartUnbuf-1:0] force_sw_parts_ecc_reg;

  // DUT configuration object
  otp_ctrl_ast_inputs_cfg dut_cfg;

  // for DV macros ID
  string msg_id = "otp_ctrl_if";

  // Lc_err could trigger during LC program, so check intr and status after lc_req is finished.
  // Lc_err takes one clock cycle to propagate to intr signal. So avoid intr check if it happens
  // during the transition.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lc_prog_err_dly1  <= 0;
      lc_esc_dly1       <= lc_ctrl_pkg::Off;
      lc_esc_dly2       <= lc_ctrl_pkg::Off;
      lc_check_byp_en_i <= get_rand_lc_tx_val();
      lc_esc_on         <= 0;
    end else begin
      lc_prog_err_dly1 <= lc_prog_err;
      lc_esc_dly1      <= lc_escalate_en_i;
      lc_esc_dly2      <= lc_esc_dly1;
      if (lc_prog_req) begin
        lc_check_byp_en_i <= lc_check_byp_en ? lc_ctrl_pkg::On : lc_ctrl_pkg::Off;
      end
      if (lc_esc_dly2 != lc_ctrl_pkg::Off && !lc_esc_on) begin
        lc_esc_on <= 1;
      end
    end
  end

  assign lc_prog_no_sta_check = lc_prog_err | lc_prog_err_dly1 | lc_prog_req | lc_esc_on;

  function automatic void drive_pwr_otp_init(logic val);
    pwr_otp_init_i = val;
  endfunction

  function automatic void drive_ext_voltage_h_io(logic val);
    ext_voltage_h_io = val;
  endfunction

  function automatic void drive_lc_creator_seed_sw_rw_en(lc_ctrl_pkg::lc_tx_t val);
    lc_creator_seed_sw_rw_en_i = val;
  endfunction

  function automatic void drive_lc_owner_seed_sw_rw_en(lc_ctrl_pkg::lc_tx_t val);
    lc_owner_seed_sw_rw_en_i = val;
  endfunction

  function automatic void drive_lc_dft_en(lc_ctrl_pkg::lc_tx_t val);
    lc_dft_en_i = val;
  endfunction

  function automatic void drive_lc_escalate_en(lc_ctrl_pkg::lc_tx_t val);
    lc_escalate_en_i = val;
  endfunction

  function automatic void drive_lc_seed_hw_rd_en(lc_ctrl_pkg::lc_tx_t val);
    lc_seed_hw_rd_en_i = val;
  endfunction

  function automatic bit under_error_states();
    return lc_esc_on | alert_reqs;
  endfunction

  // SW partitions do not have any internal checks.
  // Here we force internal ECC check to fail.
  task automatic force_sw_check_fail(
      bit[NumPartUnbuf-1:0] fail_idx = $urandom_range(1, (1'b1 << NumPartUnbuf) - 1));
    @(posedge clk_i);
% for part in unbuf_parts_with_digest:
<%
  part_name_camel = Name.to_camel_case(part["name"])
%>\
    if (fail_idx[${part_name_camel}Idx]) begin
      force tb.dut.gen_partitions[${part_name_camel}Idx].gen_unbuffered.
            u_part_unbuf.`ECC_REG_PATH.data_i[0] = 1;
      force_sw_parts_ecc_reg[${part_name_camel}Idx] = 1;
    end
% endfor
  endtask

  task automatic release_sw_check_fail();
    @(posedge clk_i);
% for part in unbuf_parts_with_digest:
<%
  part_name_camel = Name.to_camel_case(part["name"])
%>\
    if (force_sw_parts_ecc_reg[${part_name_camel}Idx]) begin
      release tb.dut.gen_partitions[${part_name_camel}Idx].gen_unbuffered.
              u_part_unbuf.`ECC_REG_PATH.data_i[0];
      force_sw_parts_ecc_reg[${part_name_camel}Idx] = 0;
    end
% endfor
  endtask

  // Force prim_generic_otp input cmd_i to a invalid value.
  task automatic force_invalid_otp_cmd_i();
    @(posedge clk_i);
    force `PRIM_GENERIC_OTP_CMD_I_PATH = otp_ctrl_macro_pkg::cmd_e'(2'b10);
  endtask

  task automatic release_invalid_otp_cmd_i();
    @(posedge clk_i);
    release `PRIM_GENERIC_OTP_CMD_I_PATH;
  endtask

  // Force part_buf partitions output otp_cmd_o to a invalid value.
  task automatic force_invalid_part_cmd_o(int part_idx);
    @(posedge clk_i);
    case (part_idx)
% for part in buf_parts_without_lc:
<%
  part_name_camel = Name.to_camel_case(part["name"])
%>\
      ${part_name_camel}Idx: force `BUF_PART_OTP_CMD_PATH(${part_name_camel}Idx) = otp_ctrl_macro_pkg::cmd_e'(2'b10);
% endfor
      LifeCycleIdx: force `LC_PART_OTP_CMD_PATH              = otp_ctrl_macro_pkg::cmd_e'(2'b10);
      default: begin
        `uvm_fatal("otp_ctrl_if",
            $sformatf("force invalid otp_cmd_o only supports buffered partitions: %0d", part_idx))
      end
    endcase
  endtask

  task automatic release_invalid_part_cmd_o(int part_idx);
    @(posedge clk_i);
    case (part_idx)
% for part in buf_parts_without_lc:
<%
  part_name_camel = Name.to_camel_case(part["name"])
%>\
      ${part_name_camel}Idx: release `BUF_PART_OTP_CMD_PATH(${part_name_camel}Idx);
% endfor
      LifeCycleIdx: release `LC_PART_OTP_CMD_PATH;
      default: begin
        `uvm_fatal("otp_ctrl_if",
            $sformatf("release invalid otp_cmd_o only supports buffered partitions: %0d",
            part_idx))
      end
    endcase
  endtask

  // This task forces otp_ctrl's internal mubi signals to values that are not mubi::true or mubi::
  // false. Then scb will check if design treats these values as locking the partition access.
  task automatic force_part_access_mubi(otp_part_access_lock_t forced_part_access_sel[NumPart-1]);
    @(posedge clk_i);
% for part in parts_without_lc:
<%
  part_name_camel = Name.to_camel_case(part["name"])
%>\
    `FORCE_OTP_PART_LOCK_WITH_RAND_NON_MUBI_VAL(${part_name_camel}Idx)
% endfor
  endtask

  task automatic release_part_access_mubi();
    @(posedge clk_i);
    release tb.dut.part_access;
    release tb.dut.part_access_dai;
  endtask

  // Connectivity assertions for test related I/Os.
//  `ASSERT(LcOtpTestStatusO_A, otp_vendor_test_status_o == `PRIM_GENERIC_OTP_PATH.test_status_o)
//  `ASSERT(LcOtpTestCtrlI_A, otp_vendor_test_ctrl_i == `PRIM_GENERIC_OTP_PATH.test_ctrl_i)

//  `ASSERT(CioTestOWithDftOn_A, lc_dft_en_i == lc_ctrl_pkg::On |->
//                               ${"##"}[2:3] cio_test_o == `PRIM_GENERIC_OTP_PATH.test_vect_o)
  `ASSERT(CioTestOWithDftOff_A, lc_dft_en_i != lc_ctrl_pkg::On |-> ##[2:3] cio_test_o == 0)
  `ASSERT(CioTestEnOWithDftOn_A, lc_dft_en_i == lc_ctrl_pkg::On |-> ##[2:3] cio_test_en_o == '1)
  `ASSERT(CioTestEnOWithDftOff_A, lc_dft_en_i != lc_ctrl_pkg::On |-> ##[2:3] cio_test_en_o == 0)


  `define OTP_ASSERT_WO_LC_ESC(NAME, SEQ) ${"\\"}
    `ASSERT(NAME, SEQ, clk_i, !rst_ni || lc_esc_on || alert_reqs)

  // If pwr_otp_idle is set only if pwr_otp init is done
  `OTP_ASSERT_WO_LC_ESC(OtpPwrDoneWhenIdle_A, pwr_otp_idle_o |-> pwr_otp_done_o)

  // otp_broadcast_o is valid only when otp init is done
  `OTP_ASSERT_WO_LC_ESC(OtpHwCfgValidOn_A, pwr_otp_done_o |->
                        otp_broadcast_o.valid == lc_ctrl_pkg::On)
  // If otp_broadcast is Off, then hw partition is not finished calculation,
  // then otp init is not done
  `OTP_ASSERT_WO_LC_ESC(OtpHwCfgValidOff_A, otp_broadcast_o.valid == lc_ctrl_pkg::Off |->
                        pwr_otp_done_o == 0)
  // Once OTP init is done, otp_broadcast_o output value stays stable until next power cycle
  `OTP_ASSERT_WO_LC_ESC(OtpHwCfgStable_A, otp_broadcast_o.valid == lc_ctrl_pkg::On |=>
                        $stable(otp_broadcast_o))

  // Otp_keymgr valid is related to part_digest, should not be changed after otp_pwr_init
  `OTP_ASSERT_WO_LC_ESC(OtpKeymgrValidStable0_A, pwr_otp_done_o |->
                        $stable(keymgr_key_o.creator_root_key_share0_valid))
  `OTP_ASSERT_WO_LC_ESC(OtpKeymgrValidStable1_A, pwr_otp_done_o |->
                        $stable(keymgr_key_o.creator_root_key_share1_valid))
  `OTP_ASSERT_WO_LC_ESC(OtpKeymgrValidStable2_A, pwr_otp_done_o |->
                        $stable(keymgr_key_o.creator_seed_valid))
  `OTP_ASSERT_WO_LC_ESC(OtpKeymgrValidStable3_A, pwr_otp_done_o |->
                        $stable(keymgr_key_o.owner_seed_valid))

  // During lc_prog_req, either otp_idle will be reset or lc_error is set
  `OTP_ASSERT_WO_LC_ESC(LcProgReq_A, $rose(lc_prog_req) |=>
                       (pwr_otp_idle_o == 0 || $rose(lc_prog_err)) within lc_prog_req[*1:$])

  // During fatal alert, check if otp outputs revert back to default value.
  // Wait three clock cycles until error propagates to each FSM states and regs.
  `define OTP_FATAL_ERR_ASSERT(NAME, SEQ) ${"\\"}
    `ASSERT(FatalErr``NAME``, alert_reqs |-> ##3 SEQ)

  `OTP_FATAL_ERR_ASSERT(LcDataValid_A, lc_data_o.valid == 0 && lc_data_o.error == 1)
  `OTP_FATAL_ERR_ASSERT(LcDataState_A, lc_data_o.state ==
                        PartInvDefault[LcStateOffset*8+:LcStateSize*8])
  `OTP_FATAL_ERR_ASSERT(LcDataCount_A, lc_data_o.count ==
                        PartInvDefault[LcTransitionCntOffset*8+:LcTransitionCntSize*8])
  `OTP_FATAL_ERR_ASSERT(LcDataTestUnlockToken_A, lc_data_o.test_unlock_token ==
                        PartInvDefault[TestUnlockTokenOffset*8+:TestUnlockTokenSize*8])
  `OTP_FATAL_ERR_ASSERT(LcDataTestExitToken_A, lc_data_o.test_exit_token ==
                        PartInvDefault[TestExitTokenOffset*8+:TestExitTokenSize*8])
  `OTP_FATAL_ERR_ASSERT(LcDataRmaToken_A, lc_data_o.rma_token ==
                        PartInvDefault[RmaTokenOffset*8+:RmaTokenSize*8])

  `OTP_FATAL_ERR_ASSERT(KeymgrKeyData_A, keymgr_key_o.creator_root_key_share0 ==
                        PartInvDefault[CreatorRootKeyShare0Offset*8+:CreatorRootKeyShare0Size*8] &&
                        keymgr_key_o.creator_root_key_share1 ==
                        PartInvDefault[CreatorRootKeyShare1Offset*8+:CreatorRootKeyShare1Size*8])

  `OTP_FATAL_ERR_ASSERT(HwCfgOValid_A, otp_broadcast_o.valid == lc_ctrl_pkg::Off)
  `OTP_FATAL_ERR_ASSERT(HwCfg0OData_A, otp_broadcast_o.hw_cfg0_data ==
                        PartInvDefault[HwCfg0Offset*8+:HwCfg0Size*8])
  `OTP_FATAL_ERR_ASSERT(HwCfg1OData_A, otp_broadcast_o.hw_cfg1_data ==
                        PartInvDefault[HwCfg1Offset*8+:HwCfg1Size*8])

  `OTP_FATAL_ERR_ASSERT(LcProgAck_A, lc_prog_ack == 0)
% if enable_flash_key:
  `OTP_FATAL_ERR_ASSERT(FlashAcks_A, flash_acks == 0)
% endif
  `OTP_FATAL_ERR_ASSERT(SramAcks_A, sram_acks == 0)
  `OTP_FATAL_ERR_ASSERT(OtbnAck_A, otbn_ack == 0)

  `undef OTP_ASSERT_WO_LC_ESC
  `undef OTP_FATAL_ERR_ASSERT
  `undef ECC_REG_PATH
  `undef BUF_PART_OTP_CMD_PATH
  `undef LC_PART_OTP_CMD_PATH
  `undef PRIM_GENERIC_OTP_PATH
  `undef PRIM_GENERIC_OTP_CMD_I_PATH
  `undef FORCE_OTP_PART_LOCK_WITH_RAND_NON_MUBI_VAL
endinterface
