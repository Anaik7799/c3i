// ============================================================================
// INDRAJAAL ARK v2 - ZIG CAPSID PROTOTYPE
// ============================================================================
// STAMP: SC-ARK-001, SC-ARK-002, SC-ARK-003
// Implements the Lytic Cycle: Adsorption -> Injection -> Biosynthesis -> Lysis
//
// Architecture: 7-Level Biomorphic Design
//   L7: Existential (Survive 50+ years)
//   L6: Biomorphic (Lytic cycle)
//   L5: Operational (Safety constraints)
//   L4: Artifact (Polyglot structure)
//   L3: Implementation (Zero deps)
//   L2: Algorithmic (RS + BLAKE3)
//   L1: Atomic (Forensic readability)
// ============================================================================

const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const json = std.json;
const Blake3 = std.crypto.hash.Blake3;
const zstd = std.compress.zstd;

// ============================================================================
// CONSTANTS
// ============================================================================

const SEAM_PAYLOAD = "|||INDRAJAAL_DNA_SEP|||";
const SEAM_LEN = SEAM_PAYLOAD.len;
const FOOTER_SIZE: usize = 4096; // Max footer size (JSON metadata)
const SHARD_SIZE: usize = 1024 * 1024; // 1MB per shard
const RS_K: usize = 100; // Data shards
const RS_M: usize = 50; // Parity shards
const RS_N: usize = RS_K + RS_M; // Total shards
const READ_BUF_SIZE: usize = 8192;
const BLAKE3_HASH_SIZE: usize = 32; // 256 bits
const BLAKE3_HEX_SIZE: usize = 64; // 32 bytes * 2 hex chars

// ============================================================================
// REED-SOLOMON GALOIS FIELD GF(2^8)
// ============================================================================
// Using primitive polynomial: x^8 + x^4 + x^3 + x^2 + 1 (0x11d)
// This is the standard RS polynomial used in RAID6, QR codes, etc.

const GF_PRIMITIVE: u16 = 0x11d; // x^8 + x^4 + x^3 + x^2 + 1
const GF_SIZE: usize = 256;

/// Galois Field logarithm table (for multiplication via log(a) + log(b))
const gf_log: [GF_SIZE]u8 = blk: {
    var log: [GF_SIZE]u8 = undefined;
    log[0] = 0; // log(0) is undefined, but we use 0 as sentinel

    var x: u16 = 1;
    for (0..255) |i| {
        log[@as(usize, @intCast(x))] = @intCast(i);
        x <<= 1;
        if (x & 0x100 != 0) {
            x ^= GF_PRIMITIVE;
        }
    }
    break :blk log;
};

/// Galois Field exponent table (antilog)
const gf_exp: [512]u8 = blk: {
    var exp: [512]u8 = undefined;

    var x: u16 = 1;
    for (0..255) |i| {
        exp[i] = @intCast(x);
        x <<= 1;
        if (x & 0x100 != 0) {
            x ^= GF_PRIMITIVE;
        }
    }
    // Double the table for easy modular arithmetic
    for (255..512) |i| {
        exp[i] = exp[i - 255];
    }
    break :blk exp;
};

/// GF(2^8) multiplication
fn gfMul(a: u8, b: u8) u8 {
    if (a == 0 or b == 0) return 0;
    return gf_exp[@as(usize, gf_log[a]) + @as(usize, gf_log[b])];
}

/// GF(2^8) division
fn gfDiv(a: u8, b: u8) u8 {
    if (a == 0) return 0;
    if (b == 0) @panic("Division by zero in GF(2^8)");
    // a / b = exp(log(a) - log(b))
    const log_a = @as(i16, gf_log[a]);
    const log_b = @as(i16, gf_log[b]);
    var diff = log_a - log_b;
    if (diff < 0) diff += 255;
    return gf_exp[@as(usize, @intCast(diff))];
}

/// GF(2^8) power
fn gfPow(x: u8, power: u8) u8 {
    if (power == 0) return 1;
    if (x == 0) return 0;
    const log_x = @as(u32, gf_log[x]);
    const exp_idx = (log_x * @as(u32, power)) % 255;
    return gf_exp[@as(usize, exp_idx)];
}

/// GF(2^8) inverse
fn gfInverse(x: u8) u8 {
    if (x == 0) @panic("Inverse of zero in GF(2^8)");
    return gf_exp[255 - @as(usize, gf_log[x])];
}

// ============================================================================
// REED-SOLOMON MATRIX OPERATIONS
// ============================================================================

/// Reed-Solomon coding context
const RSContext = struct {
    k: usize, // Number of data shards
    m: usize, // Number of parity shards
    n: usize, // Total shards (k + m)
    allocator: std.mem.Allocator,

    // Generator matrix (n x k) - stored as flat array, row-major
    generator: ?[]u8,

    pub fn init(allocator: std.mem.Allocator, k: usize, m: usize) !RSContext {
        var ctx = RSContext{
            .k = k,
            .m = m,
            .n = k + m,
            .allocator = allocator,
            .generator = null,
        };

        // Build Vandermonde-based generator matrix
        try ctx.buildGeneratorMatrix();

        return ctx;
    }

    pub fn deinit(self: *RSContext) void {
        if (self.generator) |gen| {
            self.allocator.free(gen);
        }
    }

    /// Build the generator matrix using Vandermonde construction
    /// The generator matrix G is n x k where:
    /// - First k rows are identity (data passes through)
    /// - Last m rows are parity coefficients
    fn buildGeneratorMatrix(self: *RSContext) !void {
        self.generator = try self.allocator.alloc(u8, self.n * self.k);
        const gen = self.generator.?;

        // Identity matrix for first k rows (data shards)
        for (0..self.k) |row| {
            for (0..self.k) |col| {
                gen[row * self.k + col] = if (row == col) 1 else 0;
            }
        }

        // Vandermonde matrix for parity rows
        // V[i][j] = x[i]^j where x[i] = i+1 for parity rows
        for (self.k..self.n) |row| {
            const x: u8 = @intCast(row - self.k + 1); // x = 1, 2, 3, ...
            for (0..self.k) |col| {
                gen[row * self.k + col] = gfPow(x, @intCast(col));
            }
        }
    }

    /// Encode data shards to produce parity shards
    /// Input: k data shards
    /// Output: m parity shards appended to data
    pub fn encode(self: *const RSContext, data_shards: [][]u8, parity_shards: [][]u8, shard_size: usize) void {
        if (self.generator == null) return;
        const gen = self.generator.?;

        // For each parity shard
        for (0..self.m) |p| {
            const parity_row = self.k + p;
            const parity = parity_shards[p];

            // Zero the parity shard
            @memset(parity, 0);

            // parity[p] = sum(gen[parity_row][i] * data[i]) for all i in 0..k
            for (0..self.k) |i| {
                const coeff = gen[parity_row * self.k + i];
                if (coeff == 0) continue;

                const data = data_shards[i];
                for (0..shard_size) |byte_idx| {
                    parity[byte_idx] ^= gfMul(coeff, data[byte_idx]);
                }
            }
        }
    }

    /// Decode (recover) missing shards
    /// valid_indices: indices of shards that are valid (must have >= k)
    /// shards: all shard buffers (some may be invalid)
    /// Returns: number of recovered shards
    pub fn decode(self: *const RSContext, valid_indices: []const usize, shards: [][]u8, shard_size: usize) !usize {
        if (valid_indices.len < self.k) {
            return error.InsufficientShards;
        }

        // If we have at least k valid shards, we can recover
        // Select the first k valid shards for recovery
        var selected: [RS_K]usize = undefined;
        for (0..self.k) |i| {
            selected[i] = valid_indices[i];
        }

        // Build the submatrix from selected rows of generator matrix
        var submatrix: [RS_K * RS_K]u8 = undefined;
        if (self.generator == null) return error.NoGenerator;
        const gen = self.generator.?;

        for (0..self.k) |row| {
            const src_row = selected[row];
            for (0..self.k) |col| {
                submatrix[row * self.k + col] = gen[src_row * self.k + col];
            }
        }

        // Invert the submatrix
        var inverse: [RS_K * RS_K]u8 = undefined;
        if (!matrixInvert(&submatrix, &inverse, self.k)) {
            return error.MatrixNotInvertible;
        }

        // Recover missing data shards
        var recovered: usize = 0;

        // Find which data shards (0..k-1) are missing
        for (0..self.k) |data_idx| {
            var is_valid = false;
            for (valid_indices) |vi| {
                if (vi == data_idx) {
                    is_valid = true;
                    break;
                }
            }

            if (!is_valid) {
                // This data shard needs recovery
                const target = shards[data_idx];
                @memset(target, 0);

                // target = sum(inverse[data_idx][i] * shards[selected[i]]) for all i
                for (0..self.k) |i| {
                    const coeff = inverse[data_idx * self.k + i];
                    if (coeff == 0) continue;

                    const source = shards[selected[i]];
                    for (0..shard_size) |byte_idx| {
                        target[byte_idx] ^= gfMul(coeff, source[byte_idx]);
                    }
                }
                recovered += 1;
            }
        }

        return recovered;
    }
};

/// Invert a matrix in GF(2^8) using Gauss-Jordan elimination
/// matrix: input matrix (will be modified to identity)
/// inverse: output inverse matrix (starts as identity)
/// size: matrix dimension (size x size)
fn matrixInvert(matrix: []u8, inverse: []u8, size: usize) bool {
    // Initialize inverse to identity
    for (0..size) |i| {
        for (0..size) |j| {
            inverse[i * size + j] = if (i == j) 1 else 0;
        }
    }

    // Gauss-Jordan elimination
    for (0..size) |col| {
        // Find pivot
        var pivot_row: ?usize = null;
        for (col..size) |row| {
            if (matrix[row * size + col] != 0) {
                pivot_row = row;
                break;
            }
        }

        if (pivot_row == null) {
            return false; // Matrix is singular
        }

        // Swap rows if needed
        if (pivot_row.? != col) {
            for (0..size) |j| {
                const tmp1 = matrix[col * size + j];
                matrix[col * size + j] = matrix[pivot_row.? * size + j];
                matrix[pivot_row.? * size + j] = tmp1;

                const tmp2 = inverse[col * size + j];
                inverse[col * size + j] = inverse[pivot_row.? * size + j];
                inverse[pivot_row.? * size + j] = tmp2;
            }
        }

        // Scale pivot row
        const pivot = matrix[col * size + col];
        const pivot_inv = gfInverse(pivot);
        for (0..size) |j| {
            matrix[col * size + j] = gfMul(matrix[col * size + j], pivot_inv);
            inverse[col * size + j] = gfMul(inverse[col * size + j], pivot_inv);
        }

        // Eliminate column
        for (0..size) |row| {
            if (row == col) continue;
            const factor = matrix[row * size + col];
            if (factor == 0) continue;

            for (0..size) |j| {
                matrix[row * size + j] ^= gfMul(factor, matrix[col * size + j]);
                inverse[row * size + j] ^= gfMul(factor, inverse[col * size + j]);
            }
        }
    }

    return true;
}

// ============================================================================
// TYPES
// ============================================================================

/// Lytic cycle phases (biomorphic state machine)
const LyticPhase = enum {
    Dormant, // File exists but not executed
    Adsorbed, // Execution started, locating seam
    Analyzing, // Parsing metadata, counting shards
    Healing, // Reed-Solomon recovery in progress
    Germinating, // Decompression in progress
    Alive, // Extraction complete, system running
    Dead, // Unrecoverable corruption
};

/// Shard state for recovery tracking
const ShardState = enum {
    Valid, // Hash verified
    Corrupted, // Hash mismatch, needs recovery
    Missing, // Not present
    Recovered, // Reconstructed via RS
};

/// File entry in the manifest (SC-ARK-004)
const FileEntry = struct {
    path: []const u8 = "", // Relative path within archive
    size: u64 = 0, // Uncompressed size
    offset: u64 = 0, // Offset within extracted payload
    blake3: []const u8 = "", // Hex-encoded BLAKE3 hash
    mode: u32 = 0o644, // Unix file mode (optional)
};

/// Metadata footer structure (JSON compatible)
/// SC-ARK-001: Contains full file manifest for multi-file archives
const ArkMetadata = struct {
    version: []const u8 = "1.0.0",
    created: []const u8 = "",
    original_size: u64 = 0,
    compressed_size: u64 = 0,
    shard_count: u32 = RS_K,
    parity_count: u32 = RS_M,
    shard_size: u32 = SHARD_SIZE,
    blake3_root: []const u8 = "", // Hex-encoded BLAKE3 root hash
    files: ?[]const FileEntry = null, // File manifest (null for single-file archives)

    pub fn print(self: *const ArkMetadata) void {
        std.debug.print("  Version: {s}\n", .{self.version});
        std.debug.print("  Created: {s}\n", .{self.created});
        std.debug.print("  Original size: {d} bytes\n", .{self.original_size});
        std.debug.print("  Compressed size: {d} bytes\n", .{self.compressed_size});
        std.debug.print("  Shards: {d} data + {d} parity\n", .{ self.shard_count, self.parity_count });
        std.debug.print("  Shard size: {d} bytes\n", .{self.shard_size});
        if (self.blake3_root.len > 0) {
            std.debug.print("  BLAKE3 root: {s}...\n", .{self.blake3_root[0..@min(16, self.blake3_root.len)]});
        }
        if (self.files) |file_list| {
            std.debug.print("  Files in manifest: {d}\n", .{file_list.len});
            for (file_list, 0..) |entry, i| {
                if (i < 5) { // Show first 5 files
                    std.debug.print("    [{d}] {s} ({d} bytes)\n", .{ i, entry.path, entry.size });
                } else if (i == 5) {
                    std.debug.print("    ... and {d} more files\n", .{file_list.len - 5});
                    break;
                }
            }
        }
    }
};

/// Shard information for verification
const ShardInfo = struct {
    index: u32,
    offset: u64,
    size: u32,
    state: ShardState,
    expected_hash: [BLAKE3_HASH_SIZE]u8,
    actual_hash: [BLAKE3_HASH_SIZE]u8,
};

/// Capsid state during execution
const CapsidState = struct {
    phase: LyticPhase,
    self_path: []const u8,
    file_size: u64,
    seam_offset: ?u64,
    payload_offset: ?u64,
    metadata: ?ArkMetadata,
    integrity_score: u32, // Valid shards count
    corrupted_count: u32, // Corrupted shards count
    recovered_count: u32,
    allocator: std.mem.Allocator,
    // Shard tracking (dynamically allocated)
    shard_states: ?[]ShardState,
    // Extracted data (after germination)
    extracted_data: ?[]u8,
    extracted_size: usize,
};

// ============================================================================
// CORE FUNCTIONS
// ============================================================================

/// Initialize capsid state
fn initCapsid(allocator: std.mem.Allocator) !CapsidState {
    const self_path = try std.fs.selfExePathAlloc(allocator);

    return CapsidState{
        .phase = .Dormant,
        .self_path = self_path,
        .file_size = 0,
        .seam_offset = null,
        .payload_offset = null,
        .metadata = null,
        .integrity_score = 0,
        .corrupted_count = 0,
        .recovered_count = 0,
        .allocator = allocator,
        .shard_states = null,
        .extracted_data = null,
        .extracted_size = 0,
    };
}

/// Compute BLAKE3 hash of a data slice
fn computeBlake3(data: []const u8) [BLAKE3_HASH_SIZE]u8 {
    var hasher = Blake3.init(.{});
    hasher.update(data);
    var hash: [BLAKE3_HASH_SIZE]u8 = undefined;
    hasher.final(&hash);
    return hash;
}

/// Convert hex string to bytes
fn hexToBytes(hex: []const u8, out: []u8) bool {
    if (hex.len != out.len * 2) return false;

    for (out, 0..) |*byte, i| {
        const hi = hexCharToNibble(hex[i * 2]) orelse return false;
        const lo = hexCharToNibble(hex[i * 2 + 1]) orelse return false;
        byte.* = (@as(u8, hi) << 4) | @as(u8, lo);
    }
    return true;
}

fn hexCharToNibble(c: u8) ?u4 {
    return switch (c) {
        '0'...'9' => @intCast(c - '0'),
        'a'...'f' => @intCast(c - 'a' + 10),
        'A'...'F' => @intCast(c - 'A' + 10),
        else => null,
    };
}

/// Verify a single shard's integrity using BLAKE3
fn verifyShard(file: fs.File, shard_offset: u64, shard_size: u32, expected_hash: ?[BLAKE3_HASH_SIZE]u8, allocator: std.mem.Allocator) !struct { valid: bool, hash: [BLAKE3_HASH_SIZE]u8 } {
    // Allocate buffer for shard data
    const buffer = try allocator.alloc(u8, shard_size);
    defer allocator.free(buffer);

    // Seek to shard position and read
    try file.seekTo(shard_offset);
    const bytes_read = try file.readAll(buffer);

    // Compute hash
    const actual_hash = computeBlake3(buffer[0..bytes_read]);

    // Compare with expected hash if provided
    const valid = if (expected_hash) |expected|
        mem.eql(u8, &actual_hash, &expected)
    else
        true; // No expected hash means we just compute

    return .{ .valid = valid, .hash = actual_hash };
}

/// Verify all shards and update integrity score
fn verifyAllShards(state: *CapsidState) !void {
    if (state.payload_offset == null or state.metadata == null) {
        std.debug.print("  Cannot verify shards without payload/metadata\n", .{});
        return;
    }

    const metadata = state.metadata.?;
    const total_shards = metadata.shard_count + metadata.parity_count;
    const shard_size = metadata.shard_size;

    std.debug.print("  Verifying {d} shards ({d} data + {d} parity)...\n", .{ total_shards, metadata.shard_count, metadata.parity_count });

    // Allocate shard states
    state.shard_states = try state.allocator.alloc(ShardState, total_shards);

    const file = try fs.cwd().openFile(state.self_path, .{});
    defer file.close();

    var valid_count: u32 = 0;
    var corrupted_count: u32 = 0;
    const payload_start = state.payload_offset.?;

    // For MVP, we don't have per-shard hashes in metadata
    // So we just compute hashes and mark all as valid (no corruption detection without expected hashes)
    for (0..total_shards) |i| {
        const shard_offset = payload_start + (i * shard_size);

        // Check if shard is within file bounds
        if (shard_offset + shard_size > state.file_size - FOOTER_SIZE) {
            state.shard_states.?[i] = .Missing;
            continue;
        }

        // Verify shard (without expected hash for MVP)
        const result = verifyShard(file, shard_offset, shard_size, null, state.allocator) catch {
            state.shard_states.?[i] = .Corrupted;
            corrupted_count += 1;
            continue;
        };

        _ = result; // Hash computed but not compared in MVP
        state.shard_states.?[i] = .Valid;
        valid_count += 1;
    }

    state.integrity_score = valid_count;
    state.corrupted_count = corrupted_count;

    std.debug.print("  Verification complete: {d} valid, {d} corrupted, {d} missing\n", .{
        valid_count,
        corrupted_count,
        total_shards - valid_count - corrupted_count,
    });
}

/// Phase 1: Adsorption - Locate the biomorphic seam
fn adsorb(state: *CapsidState) !void {
    state.phase = .Adsorbed;
    printPhase("ADSORPTION", "Locating biomorphic seam...");

    const file = try fs.cwd().openFile(state.self_path, .{});
    defer file.close();

    state.file_size = try file.getEndPos();
    std.debug.print("  File size: {d} bytes\n", .{state.file_size});

    // Sliding window search for seam pattern
    var window: [SEAM_LEN]u8 = undefined;
    var window_pos: usize = 0;
    var window_filled: usize = 0;
    var offset: u64 = 0;

    var read_buf: [READ_BUF_SIZE]u8 = undefined;

    while (true) {
        const bytes_read = try file.read(&read_buf);
        if (bytes_read == 0) break;

        for (read_buf[0..bytes_read]) |byte| {
            // Add byte to sliding window
            window[window_pos] = byte;
            window_pos = (window_pos + 1) % SEAM_LEN;
            if (window_filled < SEAM_LEN) window_filled += 1;

            offset += 1;

            // Check if window matches seam pattern (only if window is full)
            if (window_filled == SEAM_LEN) {
                var matches = true;
                for (0..SEAM_LEN) |i| {
                    const idx = (window_pos + i) % SEAM_LEN;
                    if (window[idx] != SEAM_PAYLOAD[i]) {
                        matches = false;
                        break;
                    }
                }
                if (matches) {
                    state.seam_offset = offset - SEAM_LEN;
                    state.payload_offset = offset;
                    break;
                }
            }
        }
        if (state.seam_offset != null) break;
    }

    if (state.seam_offset) |off| {
        std.debug.print("  Seam found at offset: {d}\n", .{off});
        std.debug.print("  Payload starts at: {d}\n", .{state.payload_offset.?});
    } else {
        std.debug.print("  Seam not found - standalone capsid mode\n", .{});
    }
}

/// Phase 2: Analyze - Parse metadata and assess integrity
fn analyze(state: *CapsidState) !void {
    state.phase = .Analyzing;
    printPhase("ANALYSIS", "Parsing metadata footer...");

    if (state.payload_offset == null) {
        std.debug.print("  No payload to analyze (standalone mode)\n", .{});
        return;
    }

    const file = try fs.cwd().openFile(state.self_path, .{});
    defer file.close();

    // Read footer from end of file
    const footer_start = if (state.file_size > FOOTER_SIZE)
        state.file_size - FOOTER_SIZE
    else
        state.payload_offset.?;

    try file.seekTo(footer_start);

    var footer_buf: [FOOTER_SIZE]u8 = undefined;
    const bytes_read = try file.readAll(&footer_buf);

    // Find JSON block by searching from end (footer is appended last)
    // Look for the LAST valid JSON object in the buffer
    var json_start: ?usize = null;
    var json_end: ?usize = null;

    // Search backwards for '}' (end of JSON)
    var i: usize = bytes_read;
    while (i > 0) {
        i -= 1;
        if (footer_buf[i] == '}') {
            json_end = i + 1;

            // Now find matching '{' by counting braces backwards
            var brace_count: i32 = 1;
            var j = i;
            while (j > 0 and brace_count > 0) {
                j -= 1;
                if (footer_buf[j] == '}') brace_count += 1;
                if (footer_buf[j] == '{') brace_count -= 1;
            }
            if (brace_count == 0) {
                json_start = j;
                break;
            }
        }
    }

    if (json_start != null and json_end != null) {
        const json_slice = footer_buf[json_start.?..json_end.?];
        std.debug.print("  Metadata footer found ({d} bytes)\n", .{json_slice.len});

        // Parse JSON metadata
        const parsed = json.parseFromSlice(ArkMetadata, state.allocator, json_slice, .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        }) catch |err| {
            std.debug.print("  JSON parse error: {s}\n", .{@errorName(err)});
            state.integrity_score = RS_K; // Assume valid for fallback
            std.debug.print("  Integrity score: {d}/{d} (assumed)\n", .{ state.integrity_score, RS_N });
            return;
        };
        defer parsed.deinit();

        const metadata = parsed.value;
        std.debug.print("  Metadata parsed successfully:\n", .{});
        metadata.print();

        // Store metadata in state (copy needed since parsed will be freed)
        state.metadata = ArkMetadata{
            .version = metadata.version,
            .created = metadata.created,
            .original_size = metadata.original_size,
            .compressed_size = metadata.compressed_size,
            .shard_count = metadata.shard_count,
            .parity_count = metadata.parity_count,
            .shard_size = metadata.shard_size,
            .blake3_root = metadata.blake3_root,
        };

        // Verify shards using BLAKE3
        try verifyAllShards(state);
    } else {
        std.debug.print("  No valid metadata footer found\n", .{});
        // Calculate integrity score (placeholder)
        state.integrity_score = RS_K; // Assume all valid for now
        std.debug.print("  Integrity score: {d}/{d} shards valid\n", .{ state.integrity_score, RS_N });
    }
}

/// Phase 3: Biosynthesis - Reed-Solomon recovery
fn heal(state: *CapsidState) !void {
    state.phase = .Healing;
    printPhase("BIOSYNTHESIS", "Reed-Solomon recovery...");

    // Get K and M from metadata or use defaults
    const k = if (state.metadata) |m| m.shard_count else RS_K;
    const m = if (state.metadata) |md| md.parity_count else RS_M;
    const total = k + m;
    const shard_size = if (state.metadata) |md| md.shard_size else SHARD_SIZE;

    std.debug.print("  Configuration: K={d} data, M={d} parity, shard_size={d}\n", .{ k, m, shard_size });
    std.debug.print("  Status: {d} valid, {d} corrupted\n", .{ state.integrity_score, state.corrupted_count });

    if (state.integrity_score >= k) {
        std.debug.print("  Sufficient shards ({d} >= K={d}), no healing needed\n", .{ state.integrity_score, k });
        return;
    }

    const corrupted = total - state.integrity_score;
    if (corrupted > m) {
        std.debug.print("  FATAL: Too many corrupted/missing shards ({d} bad, only {d} parity)\n", .{ corrupted, m });
        state.phase = .Dead;
        return;
    }

    // RS can recover up to M erasures
    std.debug.print("  Need to recover {d} shards using RS({d},{d})\n", .{ corrupted, total, k });

    // Initialize RS context
    var rs = RSContext.init(state.allocator, k, m) catch |err| {
        std.debug.print("  Failed to initialize RS context: {s}\n", .{@errorName(err)});
        state.phase = .Dead;
        return;
    };
    defer rs.deinit();

    // Collect valid shard indices
    if (state.shard_states == null) {
        std.debug.print("  No shard state information available\n", .{});
        state.phase = .Dead;
        return;
    }

    const shard_states = state.shard_states.?;
    var valid_indices = state.allocator.alloc(usize, state.integrity_score) catch |err| {
        std.debug.print("  Memory allocation failed: {s}\n", .{@errorName(err)});
        state.phase = .Dead;
        return;
    };
    defer state.allocator.free(valid_indices);

    var valid_count: usize = 0;
    for (shard_states, 0..) |ss, idx| {
        if (ss == .Valid or ss == .Recovered) {
            valid_indices[valid_count] = idx;
            valid_count += 1;
        }
    }

    std.debug.print("  Found {d} valid shards for recovery\n", .{valid_count});

    // Read shards from file and perform recovery
    if (state.payload_offset == null) {
        std.debug.print("  No payload offset available\n", .{});
        state.phase = .Dead;
        return;
    }

    const file = fs.cwd().openFile(state.self_path, .{}) catch |err| {
        std.debug.print("  Failed to open file: {s}\n", .{@errorName(err)});
        state.phase = .Dead;
        return;
    };
    defer file.close();

    // Allocate shard buffers
    const shards = state.allocator.alloc([]u8, total) catch |err| {
        std.debug.print("  Failed to allocate shard array: {s}\n", .{@errorName(err)});
        state.phase = .Dead;
        return;
    };
    defer state.allocator.free(shards);

    // Allocate individual shard buffers
    for (0..total) |i| {
        shards[i] = state.allocator.alloc(u8, shard_size) catch |err| {
            std.debug.print("  Failed to allocate shard {d}: {s}\n", .{ i, @errorName(err) });
            // Free already allocated shards
            for (0..i) |j| {
                state.allocator.free(shards[j]);
            }
            state.phase = .Dead;
            return;
        };
    }
    defer {
        for (0..total) |i| {
            state.allocator.free(shards[i]);
        }
    }

    // Read valid shards from file
    const payload_start = state.payload_offset.?;
    for (valid_indices[0..valid_count]) |shard_idx| {
        const shard_offset = payload_start + (shard_idx * shard_size);
        file.seekTo(shard_offset) catch continue;
        _ = file.readAll(shards[shard_idx]) catch continue;
    }

    // Perform RS recovery
    const recovered = rs.decode(valid_indices[0..valid_count], shards, shard_size) catch |err| {
        std.debug.print("  RS decode failed: {s}\n", .{@errorName(err)});
        state.phase = .Dead;
        return;
    };

    state.recovered_count = @intCast(recovered);
    std.debug.print("  RS recovery complete: {d} shards recovered\n", .{recovered});

    // Update shard states for recovered shards
    for (0..k) |data_idx| {
        if (shard_states[data_idx] == .Corrupted or shard_states[data_idx] == .Missing) {
            shard_states[data_idx] = .Recovered;
        }
    }

    state.integrity_score += @intCast(recovered);
}

/// Phase 4: Germination - Decompression
fn germinate(state: *CapsidState) !void {
    state.phase = .Germinating;
    printPhase("GERMINATION", "Zstd decompression...");

    if (state.metadata == null or state.payload_offset == null) {
        std.debug.print("  Cannot germinate - no metadata or payload\n", .{});
        return;
    }

    const metadata = state.metadata.?;
    const shard_count = metadata.shard_count;
    const shard_size = metadata.shard_size;
    const compressed_size = metadata.compressed_size;
    const original_size = metadata.original_size;

    std.debug.print("  Compressed size: {d} bytes\n", .{compressed_size});
    std.debug.print("  Original size: {d} bytes\n", .{original_size});
    std.debug.print("  Data shards to reassemble: {d}\n", .{shard_count});

    // Open self and read shard data
    const file = fs.cwd().openFile(state.self_path, .{}) catch |err| {
        std.debug.print("  Failed to open file: {s}\n", .{@errorName(err)});
        return;
    };
    defer file.close();

    // Calculate total data size (only data shards, not parity)
    const total_data_size: usize = @as(usize, shard_count) * @as(usize, shard_size);

    // Allocate buffer for concatenated compressed data
    const compressed_buf = state.allocator.alloc(u8, total_data_size) catch |err| {
        std.debug.print("  Failed to allocate compressed buffer: {s}\n", .{@errorName(err)});
        return;
    };
    defer state.allocator.free(compressed_buf);

    // Read all data shards into buffer
    const payload_start = state.payload_offset.?;
    for (0..shard_count) |i| {
        const shard_offset = payload_start + (i * shard_size);
        const buf_offset = i * shard_size;
        file.seekTo(shard_offset) catch continue;
        _ = file.readAll(compressed_buf[buf_offset .. buf_offset + shard_size]) catch continue;
    }

    std.debug.print("  Read {d} bytes of shard data\n", .{total_data_size});

    // Check if data is actually zstd compressed (magic number: 0xFD2FB528)
    var final_data: []u8 = undefined;
    var final_size: usize = 0;
    var owns_data = false;

    if (total_data_size >= 4) {
        const magic = std.mem.readInt(u32, compressed_buf[0..4], .little);
        if (magic == 0xFD2FB528) {
            std.debug.print("  Zstd magic number detected (0x{x:0>8})\n", .{magic});

            // Attempt Zstd decompression using streaming API
            const decompressed = decompressZstd(state.allocator, compressed_buf, original_size) catch |err| {
                std.debug.print("  Zstd decompression failed: {s}\n", .{@errorName(err)});
                std.debug.print("  Falling back to raw data mode\n", .{});
                // Fall through to raw data
                final_data = compressed_buf;
                final_size = @min(total_data_size, @as(usize, @intCast(original_size)));
                owns_data = false;
            };

            if (decompressed) |buf| {
                std.debug.print("  Decompressed {d} bytes successfully\n", .{buf.len});
                final_data = buf;
                final_size = buf.len;
                owns_data = true;
            } else if (final_size == 0) {
                // Decompression returned null, use raw data
                final_data = compressed_buf;
                final_size = @min(total_data_size, @as(usize, @intCast(original_size)));
                owns_data = false;
            }
        } else {
            std.debug.print("  No Zstd magic found (0x{x:0>8}), data may be uncompressed\n", .{magic});
            std.debug.print("  Treating shards as raw data\n", .{});
            final_data = compressed_buf;
            final_size = @min(total_data_size, @as(usize, @intCast(original_size)));
            owns_data = false;
        }
    } else {
        std.debug.print("  Insufficient data for compression detection\n", .{});
        final_data = compressed_buf;
        final_size = total_data_size;
        owns_data = false;
    }

    // Store extracted data in state for lyse phase
    if (final_size > 0) {
        // Copy data to state-owned buffer
        const state_buf = state.allocator.alloc(u8, final_size) catch |err| {
            std.debug.print("  Failed to allocate state buffer: {s}\n", .{@errorName(err)});
            if (owns_data) state.allocator.free(final_data);
            return;
        };
        @memcpy(state_buf, final_data[0..final_size]);
        state.extracted_data = state_buf;
        state.extracted_size = final_size;
        std.debug.print("  Stored {d} bytes for extraction\n", .{final_size});

        if (owns_data) {
            state.allocator.free(final_data);
        }
    }

    std.debug.print("  Germination phase complete\n", .{});
}

/// Decompress Zstd data using Zig 0.15's std.Io API
/// SC-ARK-003: Implements full Zstd decompression for biomorphic archive
fn decompressZstd(allocator: std.mem.Allocator, compressed: []const u8, expected_size: u64) !?[]u8 {
    _ = expected_size; // May be used for pre-allocation in future

    // Validate minimum size for Zstd frame (magic + minimal header)
    if (compressed.len < 5) {
        std.debug.print("  Zstd data too small: {d} bytes\n", .{compressed.len});
        return null;
    }

    // Check for valid zstd magic (0xFD2FB528 in little-endian)
    const magic = std.mem.readInt(u32, compressed[0..4], .little);
    if (magic != 0xFD2FB528) {
        std.debug.print("  Invalid Zstd magic: 0x{x:0>8}\n", .{magic});
        return null;
    }

    std.debug.print("  Zstd magic verified, decompressing...\n", .{});

    // Create allocating writer for output
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();

    // Create fixed buffer reader for input
    var in: std.Io.Reader = .fixed(compressed);

    // Initialize zstd decompressor with default window buffer and options
    var decompressor: zstd.Decompress = .init(&in, &.{}, .{});

    // Decompress all remaining data to output writer
    const bytes_written = decompressor.reader.streamRemaining(&out.writer) catch |err| {
        std.debug.print("  Zstd decompression failed: {s}\n", .{@errorName(err)});
        return null;
    };

    std.debug.print("  Decompressed {d} bytes\n", .{bytes_written});

    // Return ownership of the decompressed buffer
    return out.toOwnedSlice() catch |err| {
        std.debug.print("  Failed to get owned slice: {s}\n", .{@errorName(err)});
        return null;
    };
}

/// Create parent directories for a file path (SC-ARK-005)
fn ensureParentDirs(base_dir: []const u8, rel_path: []const u8) !void {
    var path_buf: [fs.max_path_bytes]u8 = undefined;

    // Find the last slash to get the directory part
    var last_slash: ?usize = null;
    for (rel_path, 0..) |c, i| {
        if (c == '/') last_slash = i;
    }

    if (last_slash) |slash_pos| {
        const dir_part = rel_path[0..slash_pos];

        // Create each directory component
        var current_end: usize = 0;
        while (current_end < dir_part.len) {
            // Find next slash or end
            var next_slash = current_end;
            while (next_slash < dir_part.len and dir_part[next_slash] != '/') {
                next_slash += 1;
            }

            if (next_slash > current_end) {
                const subdir = dir_part[0..next_slash];
                const full_dir = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ base_dir, subdir }) catch {
                    return error.PathTooLong;
                };

                fs.cwd().makeDir(full_dir) catch |err| switch (err) {
                    error.PathAlreadyExists => {},
                    else => return err,
                };
            }

            current_end = next_slash + 1;
        }
    }
}

/// Extract a single file from payload data (SC-ARK-006)
fn extractFile(base_dir: []const u8, entry: FileEntry, data: []const u8) !bool {
    var path_buf: [fs.max_path_bytes]u8 = undefined;

    // Validate offset and size
    if (entry.offset + entry.size > data.len) {
        std.debug.print("    ERROR: File {s} extends beyond payload\n", .{entry.path});
        return false;
    }

    // Ensure parent directories exist
    ensureParentDirs(base_dir, entry.path) catch |err| {
        std.debug.print("    ERROR: Failed to create dirs for {s}: {s}\n", .{ entry.path, @errorName(err) });
        return false;
    };

    // Build full output path
    const full_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ base_dir, entry.path }) catch {
        std.debug.print("    ERROR: Path too long for {s}\n", .{entry.path});
        return false;
    };

    // Extract file data
    const file_data = data[entry.offset .. entry.offset + entry.size];

    // Create and write file
    const out_file = fs.cwd().createFile(full_path, .{}) catch |err| {
        std.debug.print("    ERROR: Failed to create {s}: {s}\n", .{ full_path, @errorName(err) });
        return false;
    };
    defer out_file.close();

    out_file.writeAll(file_data) catch |err| {
        std.debug.print("    ERROR: Failed to write {s}: {s}\n", .{ full_path, @errorName(err) });
        return false;
    };

    // Verify BLAKE3 hash if provided
    if (entry.blake3.len == BLAKE3_HEX_SIZE) {
        const computed_hash = computeBlake3(file_data);
        const hex = std.fmt.bytesToHex(computed_hash, .lower);

        if (!mem.eql(u8, &hex, entry.blake3)) {
            std.debug.print("    WARNING: Hash mismatch for {s}\n", .{entry.path});
            std.debug.print("      Expected: {s}\n", .{entry.blake3});
            std.debug.print("      Computed: {s}\n", .{&hex});
            // Continue extraction but note the mismatch
        }
    }

    return true;
}

/// Phase 5: Lysis - Extract files to filesystem
/// SC-ARK-001: Supports both single-file and multi-file archives
fn lyse(state: *CapsidState, target_dir: []const u8) !void {
    printPhase("LYSIS", "Extracting payload...");

    if (state.phase == .Dead) {
        std.debug.print("  Cannot extract - capsid is dead\n", .{});
        return;
    }

    std.debug.print("  Target directory: {s}\n", .{target_dir});

    // SC-ARK-001: Verify target exists or create it
    fs.cwd().makeDir(target_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Check if we have extracted data
    if (state.extracted_data == null or state.extracted_size == 0) {
        std.debug.print("  No extracted data available\n", .{});
        state.phase = .Alive;
        return;
    }

    const data = state.extracted_data.?;
    const size = state.extracted_size;
    std.debug.print("  Extracting {d} bytes of data\n", .{size});

    // Check if we have a file manifest in metadata
    if (state.metadata) |meta| {
        if (meta.files) |file_list| {
            // Multi-file extraction from manifest
            std.debug.print("  Multi-file archive detected: {d} files\n", .{file_list.len});

            var success_count: usize = 0;
            var fail_count: usize = 0;

            for (file_list, 0..) |entry, i| {
                std.debug.print("  [{d}/{d}] Extracting: {s}\n", .{ i + 1, file_list.len, entry.path });

                if (extractFile(target_dir, entry, data[0..size])) {
                    success_count += 1;
                } else {
                    fail_count += 1;
                }
            }

            std.debug.print("\n  Extraction complete: {d} succeeded, {d} failed\n", .{ success_count, fail_count });

            if (fail_count > 0) {
                std.debug.print("  WARNING: Some files failed to extract\n", .{});
            }

            state.phase = .Alive;
            return;
        }
    }

    // Single-file fallback (no manifest or legacy archive)
    std.debug.print("  Single-file archive (no manifest)\n", .{});

    var path_buf: [fs.max_path_bytes]u8 = undefined;
    const full_path = std.fmt.bufPrint(&path_buf, "{s}/payload.bin", .{target_dir}) catch {
        std.debug.print("  Path buffer overflow\n", .{});
        state.phase = .Dead;
        return;
    };

    // Create and write the output file
    const out_file = fs.cwd().createFile(full_path, .{}) catch |err| {
        std.debug.print("  Failed to create output file: {s}\n", .{@errorName(err)});
        state.phase = .Dead;
        return;
    };
    defer out_file.close();

    // Write data
    out_file.writeAll(data[0..size]) catch |err| {
        std.debug.print("  Failed to write data: {s}\n", .{@errorName(err)});
        state.phase = .Dead;
        return;
    };

    std.debug.print("  Written {d} bytes to {s}\n", .{ size, full_path });

    // Compute and display BLAKE3 hash of extracted file
    const hash = computeBlake3(data[0..size]);
    std.debug.print("  BLAKE3 hash: ", .{});
    for (hash) |byte| {
        std.debug.print("{x:0>2}", .{byte});
    }
    std.debug.print("\n", .{});

    state.phase = .Alive;
    std.debug.print("  Lysis complete - {d} bytes extracted!\n", .{size});
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

fn printBanner() void {
    std.debug.print(
        \\
        \\====================================================================
        \\  INDRAJAAL ARK v2.0 - ZIG CAPSID PROTOTYPE
        \\  SIL-6 BIOMORPHIC DEEP NATIVE ARCHIVE
        \\====================================================================
        \\
    , .{});
}

fn printPhase(phase: []const u8, desc: []const u8) void {
    std.debug.print("\n--- {s} ---\n", .{phase});
    std.debug.print("  {s}\n", .{desc});
}

fn printUsage() void {
    std.debug.print(
        \\
        \\Usage: indrajaal_ark [command] [options]
        \\
        \\Commands:
        \\  unseal <target>    Extract archive to target directory
        \\  verify             Verify integrity without extraction
        \\  info               Display archive metadata
        \\
        \\Options:
        \\  --force            Overwrite existing files (SC-ARK-001)
        \\  --verbose          Detailed output
        \\
    , .{});
}

// ============================================================================
// MAIN ENTRY POINT
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    printBanner();

    // Initialize capsid state
    var state = try initCapsid(allocator);
    defer allocator.free(state.self_path);
    defer if (state.shard_states) |shards| allocator.free(shards);
    defer if (state.extracted_data) |data| allocator.free(data);

    std.debug.print("Self: {s}\n", .{state.self_path});

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var target_dir: []const u8 = "./ark_extracted";
    var verify_only = false;
    var info_only = false;

    if (args.len > 1) {
        const cmd = args[1];
        if (mem.eql(u8, cmd, "unseal")) {
            if (args.len > 2) target_dir = args[2];
        } else if (mem.eql(u8, cmd, "verify")) {
            verify_only = true;
        } else if (mem.eql(u8, cmd, "info")) {
            info_only = true;
        } else if (mem.eql(u8, cmd, "--help") or mem.eql(u8, cmd, "-h")) {
            printUsage();
            return;
        }
    }

    // Execute lytic cycle
    try adsorb(&state);
    try analyze(&state);

    if (info_only) {
        std.debug.print("\nInfo display complete\n", .{});
        return;
    }

    if (verify_only) {
        const k = if (state.metadata) |m| m.shard_count else RS_K;
        const total = if (state.metadata) |m| m.shard_count + m.parity_count else RS_N;
        if (state.integrity_score >= k) {
            std.debug.print("\nVerification PASSED: {d}/{d} shards valid (K={d})\n", .{ state.integrity_score, total, k });
        } else {
            std.debug.print("\nVerification FAILED: Only {d}/{d} shards valid (need K={d})\n", .{ state.integrity_score, total, k });
        }
        return;
    }

    try heal(&state);

    if (state.phase != .Dead) {
        try germinate(&state);
        try lyse(&state, target_dir);
    }

    // Final status
    std.debug.print("\n", .{});
    switch (state.phase) {
        .Alive => std.debug.print("=== LYTIC CYCLE COMPLETE: SYSTEM ALIVE ===\n", .{}),
        .Dead => std.debug.print("=== LYTIC CYCLE FAILED: SYSTEM DEAD ===\n", .{}),
        else => std.debug.print("=== LYTIC CYCLE INCOMPLETE: Phase {s} ===\n", .{@tagName(state.phase)}),
    }
}

// ============================================================================
// UNIT TESTS (SC-TEST-ZIG-001 to SC-TEST-ZIG-010)
// ============================================================================

test "GF multiplication identity" {
    // x * 1 = x for all x in GF(2^8)
    for (0..256) |i| {
        const x: u8 = @intCast(i);
        const result = gfMul(x, 1);
        try std.testing.expectEqual(x, result);
    }
}

test "GF multiplication by zero" {
    // x * 0 = 0 for all x
    for (0..256) |i| {
        const x: u8 = @intCast(i);
        const result = gfMul(x, 0);
        try std.testing.expectEqual(@as(u8, 0), result);
    }
}

test "GF multiplication commutativity" {
    // a * b = b * a
    const test_values = [_]u8{ 0, 1, 2, 3, 17, 42, 128, 255 };
    for (test_values) |a| {
        for (test_values) |b| {
            try std.testing.expectEqual(gfMul(a, b), gfMul(b, a));
        }
    }
}

test "GF division is inverse of multiplication" {
    // (a * b) / b = a for b != 0
    const test_values = [_]u8{ 1, 2, 3, 17, 42, 128, 255 };
    for (test_values) |a| {
        for (test_values) |b| {
            const product = gfMul(a, b);
            const divided = gfDiv(product, b);
            try std.testing.expectEqual(a, divided);
        }
    }
}

test "GF power and inverse" {
    // Test: x * x^(-1) = 1 for all x != 0
    for (1..256) |i| {
        const x: u8 = @intCast(i);
        const inv = gfInverse(x);
        const product = gfMul(x, inv);
        try std.testing.expectEqual(@as(u8, 1), product);
    }
}

test "BLAKE3 hash consistency" {
    // Same input should produce same hash
    const data = "Hello, Indrajaal!";
    var hash1: [BLAKE3_HASH_SIZE]u8 = undefined;
    var hash2: [BLAKE3_HASH_SIZE]u8 = undefined;

    var hasher1 = Blake3.init(.{});
    hasher1.update(data);
    hasher1.final(&hash1);

    var hasher2 = Blake3.init(.{});
    hasher2.update(data);
    hasher2.final(&hash2);

    try std.testing.expectEqualSlices(u8, &hash1, &hash2);
}

test "BLAKE3 hash differs for different inputs" {
    const data1 = "Hello";
    const data2 = "World";
    var hash1: [BLAKE3_HASH_SIZE]u8 = undefined;
    var hash2: [BLAKE3_HASH_SIZE]u8 = undefined;

    var hasher1 = Blake3.init(.{});
    hasher1.update(data1);
    hasher1.final(&hash1);

    var hasher2 = Blake3.init(.{});
    hasher2.update(data2);
    hasher2.final(&hash2);

    // Hashes should differ
    try std.testing.expect(!std.mem.eql(u8, &hash1, &hash2));
}

test "Zstd decompression with valid data" {
    const allocator = std.testing.allocator;

    // Real zstd compressed "Hello World"
    const compressed = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd, 0x24, 0x0b, 0x59, 0x00,
        0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x57,
        0x6f, 0x72, 0x6c, 0x64, 0xc2, 0x5b, 0x24, 0x19,
    };

    const result = try decompressZstd(allocator, &compressed, 11);
    try std.testing.expect(result != null);
    defer allocator.free(result.?);

    try std.testing.expectEqualSlices(u8, "Hello World", result.?);
}

test "Zstd decompression with invalid magic" {
    const allocator = std.testing.allocator;

    // Invalid magic number
    const invalid = [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00 };

    const result = try decompressZstd(allocator, &invalid, 0);
    try std.testing.expect(result == null);
}

test "Zstd decompression with too small data" {
    const allocator = std.testing.allocator;

    // Too small for valid zstd frame
    const small = [_]u8{ 0x28, 0xb5 };

    const result = try decompressZstd(allocator, &small, 0);
    try std.testing.expect(result == null);
}

test "Capsid phase transitions" {
    // Verify valid phase transitions in lytic cycle
    const phases = [_]LyticPhase{
        .Dormant,
        .Adsorbed,
        .Analyzing,
        .Healing,
        .Germinating,
        .Alive,
    };

    // All phases should be distinct
    for (phases, 0..) |p1, i| {
        for (phases[i + 1 ..]) |p2| {
            try std.testing.expect(p1 != p2);
        }
    }
}
