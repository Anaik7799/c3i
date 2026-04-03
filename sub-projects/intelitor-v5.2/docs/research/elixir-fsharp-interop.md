# Elixir-F# Interoperability Research Report

**Version**: 1.0.0
**Date**: 2025-12-23
**Status**: Research Complete
**Purpose**: Evaluate integration options between Elixir/Erlang and F#/.NET for the Indrajaal project

---

## Executive Summary

This report evaluates multiple approaches for integrating F# code with Elixir. The analysis covers NIFs, Ports, gRPC, JSON-RPC, and CLI invocation patterns. Our recommendation is a **tiered approach** using gRPC for complex operations and Ports for simpler CLI-style invocations.

---

## 1. NIF-Based Approaches

### 1.1 Rustler (Rust NIFs) - Reference Architecture

[Rustler](https://github.com/rusterlium/rustler) is the gold standard for safe NIF development in Elixir:

- Provides safe Rust bindings to the BEAM
- Automatic marshaling of Elixir terms to Rust types
- Catches Rust panics before they crash the BEAM
- Integrated with Mix build system

**Can Rustler be adapted for F#/.NET?**

**No, not directly.** Rustler relies on:
1. Rust's memory safety guarantees (ownership, borrowing)
2. Rust's FFI capabilities to produce C-compatible shared libraries
3. Rust's compile-time guarantees that prevent BEAM crashes

F#/.NET operates differently:
- Managed memory with garbage collection
- CLR runtime requirements
- Different FFI model (P/Invoke, COM interop)

### 1.2 Zigler (Zig NIFs) - Alternative Reference

[Zigler](https://github.com/E-xyza/zigler) provides Zig NIFs for Elixir:

- Inline Zig code in Elixir modules using `~Z` sigil
- Automatic type marshaling between BEAM and Zig
- Supports dirty NIFs and threaded execution
- Cross-compilation support (including Nerves)

**Is there a .NET equivalent to Zigler?**

**Not directly**, but [Netler](https://github.com/svan-jansson/netler) provides similar developer experience patterns (see Section 2).

### 1.3 Direct NIF Implementation for .NET

Creating a pure NIF wrapper for .NET would require:

1. **C Bridge Layer**: Write a C NIF that hosts the .NET CLR
2. **CLR Hosting**: Use `coreclr_initialize()` and `coreclr_execute_assembly()`
3. **Data Marshaling**: Convert Erlang terms to .NET types and back

**Challenges**:
- CLR startup time impacts NIF performance
- GC coordination between BEAM and CLR
- Memory management complexity
- Risk of crashing the BEAM if .NET code fails

**Verdict**: Not recommended due to complexity and stability risks.

---

## 2. Netler - Dedicated Elixir/.NET Interop Library

[Netler](https://hexdocs.pm/netler/readme.html) is the most mature Elixir/.NET interoperability solution:

### 2.1 Architecture

```
Elixir Process <---> Netler.Client <---> .NET Core Process
    (BEAM)            (Port-based)         (External)
```

### 2.2 Key Features

- **Inspired by Rustler workflows**: Similar developer experience
- **Automatic .NET compilation**: Integrates with `mix compile`
- **GenServer-based client**: Manages .NET process lifecycle
- **Message-based communication**: Uses Ports internally

### 2.3 Setup

```elixir
# mix.exs
def project do
  [
    compilers: [:netler] ++ Mix.compilers(),
    dotnet_projects: [
      {:my_dotnet_project, path: "dotnet/MyProject"}
    ]
  ]
end
```

### 2.4 Usage

```elixir
# Generate a new .NET project
mix netler.new my_dotnet_project

# The generated module provides the interop API
MyDotnetProject.call(:my_function, [arg1, arg2])
```

### 2.5 Considerations for F#

Netler supports F# since F# compiles to .NET assemblies:

1. Create F# project in `dotnet/` directory
2. Configure Netler to compile F# instead of C#
3. Expose F# functions through the Netler interface

**Pros**:
- Mature library with active maintenance
- Similar workflow to Rustler
- Process isolation (no BEAM crash risk)

**Cons**:
- Last update may need verification for recent .NET versions
- Port-based communication overhead
- Requires .NET SDK on build/runtime machines

---

## 3. Port-Based Communication

Ports are Erlang/Elixir's primary mechanism for external process communication.

### 3.1 How Ports Work

```
Elixir Process <---> Port <---> External Process
                   (STDIN/STDOUT)
```

- External program reads from stdin, writes to stdout
- BEAM sends/receives binary data through the port
- Process isolation: crashes don't affect BEAM

### 3.2 Port Implementation

```elixir
defmodule FSharpPort do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    port = Port.open({:spawn_executable, executable_path()}, [
      :binary,
      :exit_status,
      {:packet, 4},  # 4-byte length prefix
      {:args, ["--mode", "port"]}
    ])
    {:ok, %{port: port}}
  end

  def call(request) do
    GenServer.call(__MODULE__, {:call, request})
  end

  def handle_call({:call, request}, _from, state) do
    data = encode_request(request)
    Port.command(state.port, data)
    receive do
      {port, {:data, response}} when port == state.port ->
        {:reply, decode_response(response), state}
    after
      5000 -> {:reply, {:error, :timeout}, state}
    end
  end

  defp executable_path do
    Path.join(:code.priv_dir(:my_app), "fsharp_bridge")
  end
end
```

### 3.3 F# Port Server Example

```fsharp
// F# side - reads from stdin, writes to stdout
open System
open System.IO

let readPacket (stream: Stream) =
    let lengthBytes = Array.zeroCreate 4
    stream.Read(lengthBytes, 0, 4) |> ignore
    let length = BitConverter.ToInt32(lengthBytes |> Array.rev, 0)
    let data = Array.zeroCreate length
    stream.Read(data, 0, length) |> ignore
    data

let writePacket (stream: Stream) (data: byte[]) =
    let length = BitConverter.GetBytes(data.Length) |> Array.rev
    stream.Write(length, 0, 4)
    stream.Write(data, 0, data.Length)
    stream.Flush()

[<EntryPoint>]
let main _ =
    use stdin = Console.OpenStandardInput()
    use stdout = Console.OpenStandardOutput()

    while true do
        let request = readPacket stdin
        let response = processRequest request  // Your logic here
        writePacket stdout response
    0
```

### 3.4 Advantages

- **Process isolation**: F# crashes don't affect BEAM
- **Simple protocol**: Binary over STDIN/STDOUT
- **No runtime dependencies**: Just needs executable
- **Native AOT compatible**: F# can compile to native executable

### 3.5 Disadvantages

- **Serialization overhead**: Must encode/decode all data
- **Startup latency**: New process for each connection (unless pooled)
- **No shared memory**: All data must be copied

---

## 4. gRPC Integration

### 4.1 Architecture

```
Elixir (gRPC Client) <---> Network <---> F# (gRPC Server)
   grpc-elixir                         Grpc.AspNetCore
```

### 4.2 Elixir gRPC Client

[grpc-elixir](https://github.com/elixir-grpc/grpc) provides full gRPC support:

```elixir
# mix.exs
defp deps do
  [
    {:grpc, "~> 0.11"},
    {:protobuf, "~> 0.14"}
  ]
end
```

```elixir
# Client usage
{:ok, channel} = GRPC.Stub.connect("localhost:50051")
request = Cepa.VerifyRequest.new(code: code_string)
{:ok, reply} = channel |> Cepa.Verifier.Stub.verify(request)
```

### 4.3 F# gRPC Server

```fsharp
// F# gRPC server using Grpc.AspNetCore
open Grpc.Core
open Microsoft.AspNetCore.Builder

type VerifierService() =
    inherit Cepa.Verifier.VerifierBase()

    override this.Verify(request, context) =
        task {
            let result = CepaEngine.verify request.Code
            return Cepa.VerifyResponse(Success = result.Success, Messages = result.Messages)
        }

[<EntryPoint>]
let main args =
    let builder = WebApplication.CreateBuilder(args)
    builder.Services.AddGrpc() |> ignore

    let app = builder.Build()
    app.MapGrpcService<VerifierService>() |> ignore
    app.Run()
    0
```

### 4.4 Shared .proto Definition

```protobuf
syntax = "proto3";

package cepa;

service Verifier {
  rpc Verify (VerifyRequest) returns (VerifyResponse);
  rpc VerifyStream (stream CodeChunk) returns (stream VerifyResult);
}

message VerifyRequest {
  string code = 1;
  string language = 2;
}

message VerifyResponse {
  bool success = 1;
  repeated string messages = 2;
}
```

### 4.5 Advantages

- **Language agnostic**: Any language with gRPC support
- **Streaming support**: Bidirectional streaming for large data
- **Strong typing**: Protocol Buffers schema enforcement
- **Network ready**: Works locally or distributed
- **HTTP/2**: Multiplexing, compression, efficient binary format

### 4.6 Disadvantages

- **Network overhead**: Even for local communication
- **Proto compilation**: Requires build step for both languages
- **Complexity**: More infrastructure than simple Ports

---

## 5. JSON-RPC over Unix Domain Sockets

### 5.1 Architecture

```
Elixir Client <---> Unix Socket <---> F# Server
   :gen_tcp                           TcpListener
```

### 5.2 Elixir Implementation

```elixir
defmodule FSharpJsonRpc do
  use GenServer

  def start_link(socket_path) do
    GenServer.start_link(__MODULE__, socket_path, name: __MODULE__)
  end

  def init(socket_path) do
    {:ok, socket} = :gen_tcp.connect({:local, socket_path}, 0, [
      :binary,
      {:packet, :line},
      {:active, false}
    ])
    {:ok, %{socket: socket, id: 0}}
  end

  def call(method, params) do
    GenServer.call(__MODULE__, {:rpc, method, params})
  end

  def handle_call({:rpc, method, params}, _from, state) do
    request = Jason.encode!(%{
      jsonrpc: "2.0",
      id: state.id,
      method: method,
      params: params
    })

    :ok = :gen_tcp.send(state.socket, request <> "\n")
    {:ok, response} = :gen_tcp.recv(state.socket, 0, 5000)

    result = Jason.decode!(response)
    {:reply, result["result"], %{state | id: state.id + 1}}
  end
end
```

### 5.3 F# Unix Socket Server

```fsharp
open System.Net.Sockets
open System.Text.Json

let startServer socketPath =
    if File.Exists(socketPath) then File.Delete(socketPath)

    let listener = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified)
    listener.Bind(UnixDomainSocketEndPoint(socketPath))
    listener.Listen(10)

    while true do
        let client = listener.Accept()
        async {
            use reader = new StreamReader(new NetworkStream(client))
            use writer = new StreamWriter(new NetworkStream(client))

            while true do
                let line = reader.ReadLine()
                let request = JsonSerializer.Deserialize<JsonRpcRequest>(line)
                let result = dispatchMethod request.Method request.Params
                let response = JsonSerializer.Serialize({| jsonrpc = "2.0"; id = request.Id; result = result |})
                writer.WriteLine(response)
                writer.Flush()
        } |> Async.Start
```

### 5.4 Elixir Libraries

- [jsonrpc2-elixir](https://github.com/fanduel-oss/jsonrpc2-elixir): Full JSON-RPC 2.0 with TCP/TLS
- [json_rpc_toolkit](https://github.com/alexpeachey/json_rpc_toolkit): Transport-agnostic implementation

### 5.5 Advantages

- **Lower overhead than TCP/IP**: Unix sockets are faster for local IPC
- **Simple protocol**: JSON is human-readable and debuggable
- **Standardized**: JSON-RPC 2.0 is well-defined
- **Flexible**: Easy to add new methods

### 5.6 Disadvantages

- **Unix-only**: Windows uses named pipes (different API)
- **JSON overhead**: Larger than binary formats
- **No streaming**: Request-response only

---

## 6. CLI Invocation (System.cmd / :os.cmd)

### 6.1 Simple Command Execution

```elixir
# Using System.cmd (recommended)
{output, exit_code} = System.cmd("dotnet", ["run", "--project", "CepaVerifier", "--", code])

# Using :os.cmd (returns string only)
output = :os.cmd('dotnet run --project CepaVerifier')
```

### 6.2 F# Native AOT CLI Tool

F# supports [Native AOT compilation](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/):

```xml
<!-- F# project file -->
<PropertyGroup>
  <PublishAot>true</PublishAot>
  <InvariantGlobalization>true</InvariantGlobalization>
</PropertyGroup>
```

**Benefits of Native AOT for CLI**:
- Startup time: ~10ms (vs 150-200ms with JIT)
- Self-contained: No .NET runtime needed
- Small binary: ~1-15MB depending on features
- Instant execution: No JIT warmup

### 6.3 Elixir Integration Pattern

```elixir
defmodule CepaCli do
  @cepa_bin Path.join(:code.priv_dir(:indrajaal), "cepa")

  def verify(code) do
    case System.cmd(@cepa_bin, ["verify", "--stdin"], input: code) do
      {output, 0} -> {:ok, Jason.decode!(output)}
      {error, code} -> {:error, {code, error}}
    end
  end

  def analyze(file_path) do
    case System.cmd(@cepa_bin, ["analyze", file_path]) do
      {output, 0} -> {:ok, Jason.decode!(output)}
      {error, _} -> {:error, error}
    end
  end
end
```

### 6.4 erlexec for Enhanced Control

[erlexec](https://github.com/saleyn/erlexec) provides advanced process management:

- Redirect STDIN/STDOUT/STDERR separately
- Run as different user
- PTY support for interactive processes
- Signal handling
- Process monitoring

### 6.5 Advantages

- **Simplest integration**: No special protocols
- **Native AOT**: Fast startup, no runtime
- **Stateless**: Each invocation is independent
- **Easy debugging**: Run CLI manually

### 6.6 Disadvantages

- **Process spawn overhead**: New process per call
- **No persistent state**: Must reload on each call
- **Limited data transfer**: Command line and stdin/stdout

---

## 7. NFX.Erlang - .NET Erlang Distribution Protocol

[NFX.Erlang](http://nfxlib.com/archive/blog/2013/10/nfx-native-interoperability-of-net-with-erlang.html) implements Erlang distribution in .NET:

### 7.1 Features

- Full Erlang type support and CLR mapping
- Pattern matching of Erlang types
- Erlang term serialization/deserialization
- OTP distributed protocol support
- RPC calls in both directions

### 7.2 Architecture

```
Erlang Node <---> Distribution Protocol <---> .NET Node
  BEAM               (TCP/EPMD)              NFX.Erlang
```

### 7.3 Considerations

- **Mature but older**: Project is from 2013 era
- **Deep integration**: Acts as full Erlang node
- **Complex setup**: Requires Erlang distribution knowledge
- **F# compatible**: Works with any .NET language

---

## 8. Serialization Format Comparison

### 8.1 Options

| Format | Library (Elixir) | Library (F#) | Size | Speed |
|--------|------------------|--------------|------|-------|
| JSON | Jason | System.Text.Json | Large | Good |
| MessagePack | Msgpax | MessagePack-CSharp | Small | Fast |
| Protocol Buffers | protobuf-elixir | Google.Protobuf | Small | Fast |
| ETF (Erlang Term Format) | :erlang.term_to_binary | Custom | Medium | Fast |

### 8.2 Recommendations

- **Development/Debug**: JSON (readable)
- **Production (simple)**: MessagePack (fast, schemaless)
- **Production (typed)**: Protocol Buffers (schema, streaming)

### 8.3 Elixir MessagePack

```elixir
# Using Msgpax
{:ok, packed} = Msgpax.pack(%{code: code, options: opts})
{:ok, unpacked} = Msgpax.unpack(response)
```

### 8.4 F# MessagePack

```fsharp
open MessagePack

[<MessagePackObject>]
type VerifyRequest = {
    [<Key(0)>] Code: string
    [<Key(1)>] Options: Map<string, string>
}

let packed = MessagePackSerializer.Serialize(request)
let response = MessagePackSerializer.Deserialize<VerifyResponse>(data)
```

---

## 9. Comparison Matrix

| Approach | Latency | Throughput | Complexity | Isolation | F# Support |
|----------|---------|------------|------------|-----------|------------|
| NIF (not possible) | - | - | - | - | No |
| Netler | Medium | Medium | Low | Full | Yes |
| Ports | Medium | Medium | Medium | Full | Yes |
| gRPC | Medium | High | High | Full | Excellent |
| JSON-RPC/UDS | Low | Medium | Medium | Full | Yes |
| CLI (Native AOT) | Low* | Low | Low | Full | Excellent |
| NFX.Erlang | Low | High | High | Partial | Yes |

*With Native AOT compilation

---

## 10. Recommendations

### 10.1 Primary Recommendation: Hybrid Approach

**For Indrajaal/Cepa Integration**:

1. **gRPC for Complex Operations**
   - Code verification with streaming
   - Large data transfers
   - Bidirectional communication
   - Long-running operations

2. **Native AOT CLI for Simple Operations**
   - Quick one-off verifications
   - Build-time tools
   - CI/CD integration
   - Debugging and testing

### 10.2 Implementation Phases

**Phase 1: CLI Tool (Quick Win)**
```
F# Native AOT CLI <-- System.cmd -- Elixir
```
- Build F# verifier as Native AOT executable
- Call from Elixir using System.cmd
- JSON input/output

**Phase 2: Port-Based Server (Performance)**
```
F# Port Server <-- Port (MessagePack) -- Elixir GenServer
```
- Persistent F# process
- MessagePack serialization
- Connection pooling

**Phase 3: gRPC Service (Scale)**
```
F# gRPC Server <-- HTTP/2 -- Elixir gRPC Client
```
- Full streaming support
- Multiple concurrent requests
- Potential for distribution

### 10.3 Technology Choices

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Serialization | MessagePack | Fast, compact, schemaless |
| Protocol | gRPC (primary), Port (fallback) | Mature, streaming |
| F# Runtime | Native AOT | Fast startup, no deps |
| Elixir Client | grpc-elixir | Active, feature-complete |

---

## 11. References

### Elixir/.NET Interop
- [Netler Library](https://github.com/svan-jansson/netler)
- [Netler Documentation](https://hexdocs.pm/netler/readme.html)
- [Elixir Interoperability in 2025](http://elixir-lang.org/blog/2025/08/18/interop-and-portability/)

### NIF Development
- [Rustler](https://github.com/rusterlium/rustler)
- [Zigler](https://github.com/E-xyza/zigler)
- [Writing Rust NIFs](https://mainmatter.com/blog/2020/06/25/writing-rust-nifs-for-elixir-with-rustler/)

### Erlang/.NET
- [NFX.Erlang](http://nfxlib.com/archive/blog/2013/10/nfx-native-interoperability-of-net-with-erlang.html)
- [OTP.NET](https://github.com/saleyn/otp.net)

### gRPC
- [grpc-elixir](https://github.com/elixir-grpc/grpc)
- [gRPC Elixir Docs](https://hexdocs.pm/grpc/)
- [How to Use gRPC in Elixir](https://blog.appsignal.com/2020/03/24/how-to-use-grpc-in-elixir.html)

### Ports and Communication
- [Elixir Port Documentation](https://hexdocs.pm/elixir/Port.html)
- [Outside Elixir: Running External Programs](https://www.theerlangelist.com/article/outside_elixir)
- [erlexec](https://github.com/saleyn/erlexec)

### JSON-RPC
- [JSONRPC2 for Elixir](https://github.com/fanduel-oss/jsonrpc2-elixir)
- [Unix Domain Sockets with Elixir](https://medium.com/@hdswick/unix-domain-sockets-ipc-with-elixir-ec027f83c511)

### .NET Native AOT
- [Native AOT Overview](https://learn.microsoft.com/en-us/dotnet/core/deploying/native-aot/)
- [State of Native AOT in .NET 10](https://code.soundaranbu.com/state-of-nativeaot-net10)

### Serialization
- [Msgpax](https://github.com/lexmag/msgpax)
- [Protocol Buffers in Elixir](https://peerdh.com/blogs/programming-insights/using-protocol-buffers-with-elixir-for-efficient-data-serialization-in-microservices)

---

## 12. Conclusion

For integrating F# code with Elixir in the Indrajaal project, we recommend a **hybrid approach**:

1. **Start with Native AOT CLI**: Fastest path to working integration
2. **Evolve to gRPC**: When performance or streaming is needed
3. **Consider Netler**: If deep .NET integration becomes necessary

The key insight is that F#'s Native AOT support makes CLI-based integration highly viable, with startup times competitive with native binaries. Combined with gRPC for heavier workloads, this provides a robust, maintainable integration strategy without the risks of NIF-based approaches.
