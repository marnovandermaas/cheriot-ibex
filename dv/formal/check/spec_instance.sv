/*
The following instantiates the specification via the spec api. It also chooses the mode for the spec to run in (see main.sail
for more on that).

It just wires up the pre_* state to the spec_post* state.
*/

always_comb begin
    if (wbexc_handling_irq) main_mode = MAIN_IRQ;
    else if (`ID.instr_fetch_err_i) main_mode = MAIN_IFERR;
    else main_mode = MAIN_IDEX;
end

// Some registers are not driven. Only those that have reg_driven[i] high are
// given real values, the rest are left free (i.e. the spec cannot depend on
// them). For wraparound purposes it does not matter what reg_driven[i] is:
// - If too many registers are driven they all must pass checks anyway (since
// they are checked as inputs)
// - If too few registers are driven instructions will fail to be spec
// conformant
// Note that while it again does not matter how they are defined, but only
// registers matching one of `CR.rf_raddr_{a, b} can be driven.

logic [31:0] reg_driven;
assign reg_driven[0] = 1'b0;

for (genvar i = 1; i < 32; i++) begin: g_regs_cut
    t_Capability free; // Undriven
    // csr_cheri_asr err is a corner case where a CSR instruction (which
    // depends on register a) might fail to execute due to the PCC missing
    // some permissions, meaning it does not actually depend on register a.
    assign reg_driven[i] = (`CR.rf_raddr_a == i && `CR.rf_ren_a && ~`IDC.csr_cheri_asr_err) || (`CR.rf_raddr_b == i && `CR.rf_ren_b);
    assign pre_regs_cut[i] = reg_driven[i] ? pre_regs[i] : free;
end

spec_api #(
    .NREGS(32)
) spec_api_i (
    .int_err_o(spec_int_err),
    .main_mode(main_mode),

    .insn_bits(idex_compressed_instr),

    .regs_i(pre_regs_cut),

    .wx_o(spec_post_wX),
    .wx_addr_o(spec_post_wX_addr),
    .wx_en_o(spec_post_wX_en),

    .mvendor_id_i(CSR_MVENDORID_CHERI_VALUE),
    .march_id_i(CSR_MARCHID_CHERI_VALUE),
    .mimp_id_i(CSR_MIMPID_VALUE),
    .mhart_id_i(hart_id_i),
    .mconfigptr_i(),

    .misa_i(`CSR.MISA_VALUE),
    .mip_i(pre_mip),
    .nextpc_i(pre_nextpc),

    .nmi_i(pre_nmi),

    // Unused
    .mseccfg_i(),
    .mseccfg_o(),

    `define X(n) .n``_i(pre_``n), .n``_o(spec_post_``n),
    `X_EACH_CSR
    `undef X

    .mem_read_o(spec_mem_read),
    .mem_read_snd_gran_o(spec_mem_read_snd),
    .mem_read_fst_addr_o(spec_mem_read_fst_addr),
    .mem_read_snd_addr_o(spec_mem_read_snd_addr),
    .mem_read_fst_rdata_i(spec_mem_read_fst_rdata),
    .mem_read_snd_rdata_i(spec_mem_read_snd_rdata),
    .mem_read_tag_i(spec_mem_read_tag),

    .mem_revoke_en_o(spec_mem_revoke_en),
    .mem_revoke_granule_o(spec_mem_revoke_addr),
    .mem_revoke_i(spec_mem_revoke),

    .mem_write_o(spec_mem_write),
    .mem_write_snd_gran_o(spec_mem_write_snd),
    .mem_write_fst_addr_o(spec_mem_write_fst_addr),
    .mem_write_snd_addr_o(spec_mem_write_snd_addr),
    .mem_write_fst_wdata_o(spec_mem_write_fst_wdata),
    .mem_write_snd_wdata_o(spec_mem_write_snd_wdata),
    .mem_write_fst_be_o(spec_mem_write_fst_be),
    .mem_write_snd_be_o(spec_mem_write_snd_be),
    .mem_write_tag_o(spec_mem_write_tag)
);