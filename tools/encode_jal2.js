function encode_jal_correct(rd, offset) {
    // RISC-V JAL encoding: imm[20|10:1|11|19:12] | rd[11:7] | opcode[6:0]
    // offset is a signed 21-bit value (PC-relative)
    // We need to encode the lower 21 bits of offset (two's complement)
    
    // Get 21-bit two's complement
    let imm21 = offset & 0x1FFFFF;  // lower 21 bits
    
    let imm20_bit  = (imm21 >> 20) & 1;  // bit 20 of imm -> instruction bit 31
    let imm10_1    = (imm21 >> 1) & 0x3FF;  // bits 10:1 -> instruction bits 30:21
    let imm11_bit  = (imm21 >> 11) & 1;  // bit 11 -> instruction bit 20
    let imm19_12   = (imm21 >> 12) & 0xFF;  // bits 19:12 -> instruction bits 19:12
    
    let instr = (imm20_bit << 31) | (imm10_1 << 21) | (imm11_bit << 20) | (imm19_12 << 12) | (rd << 7) | 0x6F;
    return instr >>> 0;  // unsigned
}

// Test: encode JAL x0, -300
let result = encode_jal_correct(0, -300);
console.log('JAL x0, -300 : 32\'h' + result.toString(16).toUpperCase().padStart(8, '0'));

// Verify: decode it back
function decode_jal(instr) {
    let imm20  = (instr >> 31) & 1;
    let imm10_1 = (instr >> 21) & 0x3FF;
    let imm11  = (instr >> 20) & 1;
    let imm19_12 = (instr >> 12) & 0xFF;
    let rd     = (instr >> 7) & 0x1F;
    let opcode = instr & 0x7F;
    
    // Reconstruct 21-bit signed offset
    let offset = (imm20 << 20) | (imm19_12 << 12) | (imm11 << 11) | (imm10_1 << 1);
    // Sign extend from 21 bits
    if (offset & (1 << 20)) {
        offset -= (1 << 21);
    }
    return {rd, offset, opcode};
}

let decoded = decode_jal(result);
console.log('Decoded: jal x' + decoded.rd + ', ' + decoded.offset + ' (opcode=0x' + decoded.opcode.toString(16) + ')');

// Also decode the original 0xED5FF06F
let orig = 0xED5FF06F;
let d2 = decode_jal(orig);
console.log('Original 0xED5FF06F: jal x' + d2.rd + ', ' + d2.offset);

// Decode the "fixed" 0xED50306F
let fixed = 0xED50306F;
let d3 = decode_jal(fixed);
console.log('"Fixed" 0xED50306F: jal x' + d3.rd + ', ' + d3.offset);

// Encode -280 (jump to rom[6], start of send H)
let r280 = encode_jal_correct(0, -280);
console.log('JAL x0, -280: 32\'h' + r280.toString(16).toUpperCase().padStart(8, '0'));

// Encode -304 (jump to rom[0], full restart)
let r304 = encode_jal_correct(0, -304);
console.log('JAL x0, -304: 32\'h' + r304.toString(16).toUpperCase().padStart(8, '0'));

// Encode -12 (beq loop offset)
function encode_btype(rs2, rs1, funct3, offset) {
    let imm12 = (offset >> 12) & 1;
    let imm10_5 = (offset >> 5) & 0x3F;
    let imm4_1 = (offset >> 1) & 0xF;
    let imm11 = (offset >> 11) & 1;
    
    let instr = (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_1 << 8) | (imm11 << 7) | 0x63;
    return instr >>> 0;
}

let beq = encode_btype(0, 31, 0, -12);
console.log('BEQ x31, x0, -12: 32\'h' + beq.toString(16).toUpperCase().padStart(8, '0'));
console.log('Expected for FE0F8AE3: ' + (beq == 0xFE0F8AE3 ? 'MATCH' : 'MISMATCH (got ' + (beq >>> 0).toString(16) + ')'));

// Test: CPU decode of imm_j for 0xED5FF06F 
console.log('\n--- CPU imm_j decoder test ---');
function cpu_decoder_imm_j(instr) {
    // From riscv_core.v:
    // wire [31:0] imm_j  = {{11{if_id_ir[31]}}, if_id_ir[31], if_id_ir[19:12], if_id_ir[20], if_id_ir[30:21], 1'b0};
    // With the CPU's PC update: pc_next = if_id_pc + id_imm (for jal)
    // And imm_j is assigned to id_imm when opcode is JAL
    
    let bit31 = (instr >> 31) & 1;
    let bits19_12 = (instr >> 12) & 0xFF;
    let bit20 = (instr >> 20) & 1;
    let bits30_21 = (instr >> 21) & 0x3FF;
    
    // Reconstruct imm_j as CPU would
    let sign_ext = bit31 ? 0x7FF : 0;  // 11-bit sign extension
    let imm_j = (sign_ext << 21) | (bit31 << 20) | (bits19_12 << 12) | (bit20 << 11) | (bits30_21 << 1) | 0;
    
    // As signed
    if (imm_j & (1 << 31)) {
        imm_j -= (1 << 32);
    }
    return imm_j;
}

console.log('0xED5FF06F CPU decoded imm_j = ' + cpu_decoder_imm_j(0xED5FF06F));
console.log('0xED50306F CPU decoded imm_j = ' + cpu_decoder_imm_j(0xED50306F));
console.log('0xED10306F CPU decoded imm_j = ' + cpu_decoder_imm_j(0xED10306F));
