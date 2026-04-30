%% scripts_crypto_ffi — Erlang FFI for Ed25519 signing used by CPIG federation.
%% Authority: SC-CPIG-FED-002 (Ed25519 signed attestations), SC-SCRIPT-GLEAM-001.
%% Backed by OTP `crypto` module — pure stdlib, no external deps.

-module(scripts_crypto_ffi).
-export([
    ed25519_keypair/0,
    ed25519_keypair_from_seed/1,
    ed25519_sign/2,
    ed25519_verify/3,
    sha256_hex/1,
    canonical_attestation/3,
    now_seconds/0
]).

%% Generate a fresh Ed25519 keypair: returns {ok, PubHex, PrivHex} as binaries.
ed25519_keypair() ->
    {Pub, Priv} = crypto:generate_key(eddsa, ed25519),
    {ok, hex(Pub), hex(Priv)}.

%% Deterministic keypair from a 32-byte seed (hex encoded).  For tests so we
%% can rerun with the same key without persisting state.
ed25519_keypair_from_seed(SeedHex) when is_binary(SeedHex); is_list(SeedHex) ->
    SeedBin = unhex(to_binary(SeedHex)),
    case byte_size(SeedBin) of
        32 ->
            {Pub, _Priv} = crypto:generate_key(eddsa, ed25519, SeedBin),
            {ok, hex(Pub), hex(SeedBin)};
        _ -> {error, <<"seed must be 32 bytes hex">>}
    end.

ed25519_sign(MessageBin, PrivHex) ->
    Priv = unhex(to_binary(PrivHex)),
    Sig = crypto:sign(eddsa, sha512, to_binary(MessageBin), [Priv, ed25519]),
    {ok, hex(Sig)}.

ed25519_verify(MessageBin, SigHex, PubHex) ->
    Pub = unhex(to_binary(PubHex)),
    Sig = unhex(to_binary(SigHex)),
    case crypto:verify(eddsa, sha512, to_binary(MessageBin), Sig, [Pub, ed25519]) of
        true  -> {ok, true};
        false -> {ok, false}
    end.

sha256_hex(MessageBin) ->
    Digest = crypto:hash(sha256, to_binary(MessageBin)),
    {ok, hex(Digest)}.

%% Build the canonical JSON-ish payload that the peer will verify.
%% Format: "<mesh>|<score>|<timestamp>" — order-stable, no whitespace.
canonical_attestation(MeshId, Score, Timestamp) when is_integer(Score) ->
    Bin = iolist_to_binary([
        to_binary(MeshId), <<"|">>,
        integer_to_binary(Score), <<"|">>,
        integer_to_binary(Timestamp)
    ]),
    {ok, Bin}.

now_seconds() ->
    {ok, erlang:system_time(second)}.

%% ─── helpers ───────────────────────────────────────────────────────────────

hex(Bin) when is_binary(Bin) ->
    list_to_binary([io_lib:format("~2.16.0b", [B]) || <<B>> <= Bin]).

unhex(<<>>) -> <<>>;
unhex(Hex) when is_binary(Hex) ->
    L = binary_to_list(Hex),
    list_to_binary(unhex_pairs(L)).

unhex_pairs([])           -> [];
unhex_pairs([A, B | Rest]) ->
    [list_to_integer([A, B], 16) | unhex_pairs(Rest)];
unhex_pairs([_])          -> [].  %% odd length — drop trailing nibble

to_binary(B) when is_binary(B) -> B;
to_binary(L) when is_list(L)   -> list_to_binary(L).
