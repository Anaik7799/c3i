fn main() {
    csbindgen::Builder::default()
        .input_extern_file("src/lib.rs")
        .csharp_dll_name("zenoh_ffi")
        .csharp_namespace("Cepaf.Zenoh.Native")
        .csharp_class_name("ZenohFfi")
        .generate_csharp_file("generated/ZenohFfi.g.cs")
        .unwrap();
}
