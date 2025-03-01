use libc::{c_char, size_t};
use std::ffi::{CStr, CString};
use std::ptr;
use std::ptr::addr_of; // Added for the addr_of macro

mod parser;

/// Parse YAML to JSON
///
/// # Safety
///
/// This function is unsafe because it dereferences raw pointers.
/// The input must be a valid null-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn yaml_parse(input: *const c_char) -> *mut c_char {
    // Return null if input is null
    if input.is_null() {
        return ptr::null_mut();
    }

    // Convert C string to Rust string
    let c_str = CStr::from_ptr(input);
    let yaml_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => {
            return CString::new("{\"error\":\"Invalid UTF-8 in input\"}")
                .unwrap()
                .into_raw()
        }
    };

    // Parse YAML and convert to JSON
    match parser::parse_yaml_to_json(yaml_str) {
        Ok(json) => CString::new(json).unwrap_or_default().into_raw(),
        Err(e) => {
            let error_msg = format!("{{\"error\":\"{}\"}}", e.to_string().replace('\"', "\\\""));
            CString::new(error_msg).unwrap_or_default().into_raw()
        }
    }
}

/// Encode JSON to YAML
///
/// # Safety
///
/// This function is unsafe because it dereferences raw pointers.
/// The input must be a valid null-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn yaml_encode(input: *const c_char, block_style: i32) -> *mut c_char {
    // Return null if input is null
    if input.is_null() {
        return ptr::null_mut();
    }

    // Convert C string to Rust string
    let c_str = CStr::from_ptr(input);
    let json_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => {
            return CString::new("{\"error\":\"Invalid UTF-8 in input\"}")
                .unwrap()
                .into_raw()
        }
    };

    // Convert JSON to YAML
    match parser::encode_json_to_yaml(json_str, block_style != 0) {
        Ok(yaml) => CString::new(yaml).unwrap_or_default().into_raw(),
        Err(e) => {
            let error_msg = format!("{{\"error\":\"{}\"}}", e.to_string().replace('\"', "\\\""));
            CString::new(error_msg).unwrap_or_default().into_raw()
        }
    }
}

/// Free a string allocated by this library
///
/// # Safety
///
/// This function is unsafe because it deallocates memory for a raw pointer.
/// The pointer must have been returned by yaml_parse or yaml_encode.
#[no_mangle]
pub unsafe extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        let _ = CString::from_raw(ptr);
    }
}

/// Get last error message
///
/// # Safety
///
/// This function is unsafe because it dereferences raw pointers.
/// The buffer must be a valid writeable memory location.
#[no_mangle]
pub unsafe extern "C" fn get_last_error(buffer: *mut c_char, size: size_t) -> size_t {
    static mut LAST_ERROR: Option<String> = None;

    if buffer.is_null() || size == 0 {
        return 0;
    }

    // Using addr_of! instead of & to avoid creating a shared reference to mutable static
    let error_ptr = addr_of!(LAST_ERROR);
    if let Some(error) = &*error_ptr {
        let bytes_to_copy = error.len().min(size - 1);
        ptr::copy_nonoverlapping(error.as_ptr(), buffer as *mut u8, bytes_to_copy);
        *buffer.add(bytes_to_copy) = 0; // Null terminator
        return bytes_to_copy;
    }

    *buffer = 0; // Empty string
    0
}

/// Set the last error message
#[no_mangle]
pub unsafe extern "C" fn set_last_error(error: *const c_char) {
    static mut LAST_ERROR: Option<String> = None;

    if error.is_null() {
        LAST_ERROR = None;
        return;
    }

    let c_str = CStr::from_ptr(error);
    LAST_ERROR = c_str.to_str().ok().map(String::from);
}

/// Version information
#[no_mangle]
pub unsafe extern "C" fn yaml_bridge_version() -> *const c_char {
    static VERSION: &str = concat!(
        env!("CARGO_PKG_NAME"),
        " ",
        env!("CARGO_PKG_VERSION"),
        " (",
        env!("CARGO_PKG_AUTHORS"),
        ")"
    );

    CStr::from_bytes_with_nul_unchecked(VERSION.as_bytes()).as_ptr()
}
