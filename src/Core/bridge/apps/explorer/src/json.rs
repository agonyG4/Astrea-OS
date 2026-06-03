pub fn array<T>(items: &[T], f: fn(&T) -> String) -> String {
    let mut out = String::with_capacity(items.len() * 200);
    out.push('[');
    for (i, item) in items.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&f(item));
    }
    out.push(']');
    out
}

pub fn escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

fn push_percent_encoded_byte(out: &mut String, byte: u8) {
    const HEX: &[u8; 16] = b"0123456789ABCDEF";
    out.push('%');
    out.push(HEX[(byte >> 4) as usize] as char);
    out.push(HEX[(byte & 0x0f) as usize] as char);
}

#[cfg(unix)]
pub fn file_url(path: &std::path::Path) -> String {
    use std::os::unix::ffi::OsStrExt;

    let mut out = String::from("file://");
    for &byte in path.as_os_str().as_bytes() {
        match byte {
            b'/' | b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                out.push(byte as char)
            }
            _ => push_percent_encoded_byte(&mut out, byte),
        }
    }
    out
}

#[cfg(not(unix))]
pub fn file_url(path: &std::path::Path) -> String {
    let mut out = String::from("file://");
    for byte in path.to_string_lossy().as_bytes() {
        match *byte {
            b'/'
            | b'\\'
            | b':'
            | b'A'..=b'Z'
            | b'a'..=b'z'
            | b'0'..=b'9'
            | b'-'
            | b'.'
            | b'_'
            | b'~' => out.push(*byte as char),
            _ => push_percent_encoded_byte(&mut out, *byte),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn file_url_percent_encodes_spaces_hashes_and_unicode() {
        let url = file_url(Path::new("/tmp/a # b 😀.png"));

        assert_eq!(url, "file:///tmp/a%20%23%20b%20%F0%9F%98%80.png");
    }
}
