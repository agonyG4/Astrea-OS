use std::cmp::Ordering;
use std::path::Path;
use std::process::Command;

use crate::json;

#[derive(Default, Clone)]
struct Device {
    name: String,
    path: String,
    dev_type: String,
    hotplug: bool,
    removable: bool,
    label: String,
    uuid: String,
    fstype: String,
    size: String,
    mountpoints: Vec<String>,
}

pub fn run_devices() -> Result<(), String> {
    let out = lsblk(None)?;
    let mut devices: Vec<Device> = out
        .lines()
        .filter_map(parse_lsblk_line)
        .filter(show_device)
        .collect();
    devices.sort_unstable_by(|a, b| {
        device_priority(a)
            .cmp(&device_priority(b))
            .then_with(|| icmp(&device_title(a), &device_title(b)))
            .then_with(|| icmp(&a.path, &b.path))
    });
    println!("{}", json::array(&devices, device_to_json));
    Ok(())
}

pub fn run_mount(args: &[String], verb: &str, msg: &str) -> Result<(), String> {
    let path = args
        .first()
        .ok_or_else(|| format!("usage: explorer_backend {verb} <device_path>"))?;

    if verb == "mount" {
        if let Some(dev) = device_by_path(path)? {
            if let Some(existing) = primary_mount(&dev) {
                println!(
                    "{{\"ok\":true,\"mountPath\":\"{}\",\"message\":\"already-mounted\"}}",
                    json::escape(existing)
                );
                return Ok(());
            }
        }
    }

    let out = udisksctl(verb, path)?;
    let mount_path = if verb == "mount" {
        parse_udisks_path(&out)
            .or_else(|| {
                device_by_path(path)
                    .ok()
                    .flatten()
                    .and_then(|d| primary_mount(&d).map(str::to_string))
            })
            .unwrap_or_default()
    } else {
        String::new()
    };

    println!(
        "{{\"ok\":true,\"mountPath\":\"{}\",\"message\":\"{msg}\"}}",
        json::escape(&mount_path)
    );
    Ok(())
}

pub fn run_remount(args: &[String]) -> Result<(), String> {
    let path = args
        .first()
        .ok_or_else(|| "usage: explorer_backend remount <device_path>".to_string())?;

    if let Some(dev) = device_by_path(path)? {
        if primary_mount(&dev).is_some() {
            udisksctl("unmount", path)?;
        }
    }

    let out = udisksctl("mount", path)?;
    let mount_path = parse_udisks_path(&out)
        .or_else(|| {
            device_by_path(path)
                .ok()
                .flatten()
                .and_then(|d| primary_mount(&d).map(str::to_string))
        })
        .unwrap_or_default();

    println!(
        "{{\"ok\":true,\"mountPath\":\"{}\",\"message\":\"remounted\"}}",
        json::escape(&mount_path)
    );
    Ok(())
}

fn lsblk(device: Option<&str>) -> Result<String, String> {
    let mut cmd = Command::new("lsblk");
    cmd.args([
        "-P",
        "-o",
        "NAME,PATH,TYPE,HOTPLUG,RM,LABEL,UUID,FSTYPE,SIZE,MOUNTPOINTS",
    ]);
    if let Some(d) = device {
        cmd.arg(d);
    }
    let out = cmd.output().map_err(|e| format!("lsblk: {e}"))?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).trim().to_string());
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn device_by_path(path: &str) -> Result<Option<Device>, String> {
    match lsblk(Some(path)) {
        Ok(out) => {
            let found = out
                .lines()
                .filter_map(parse_lsblk_line)
                .find(|d| d.path == path);
            if found.is_some() {
                return Ok(found);
            }
        }
        Err(_) => {}
    }

    Ok(lsblk(None)?
        .lines()
        .filter_map(parse_lsblk_line)
        .find(|d| d.path == path))
}

fn udisksctl(verb: &str, device: &str) -> Result<String, String> {
    let out = Command::new("udisksctl")
        .args([verb, "-b", device])
        .output()
        .map_err(|e| format!("udisksctl: {e}"))?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
        let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
        let msg = if !err.is_empty() { err } else { stdout };
        return Err(if msg.is_empty() {
            format!("{verb} failed")
        } else {
            msg
        });
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn parse_udisks_path(out: &str) -> Option<String> {
    out.lines()
        .find_map(|l| l.split(" at ").nth(1))
        .map(|s| s.trim().trim_end_matches('.').to_string())
}

fn parse_lsblk_line(line: &str) -> Option<Device> {
    let mut dev = Device::default();
    let mut chars = line.chars().peekable();

    loop {
        while chars.peek().map(|c| c.is_whitespace()).unwrap_or(false) {
            chars.next();
        }
        if chars.peek().is_none() {
            break;
        }

        let key: String = chars.by_ref().take_while(|&c| c != '=').collect();
        if chars.next() != Some('"') {
            break;
        }

        let mut val = String::new();
        loop {
            match chars.next() {
                Some('"') => break,
                Some('\\') => match chars.next() {
                    Some('x') => {
                        let (h, l) = (chars.next(), chars.next());
                        if let (Some(h), Some(l)) = (h, l) {
                            if let Ok(b) = u8::from_str_radix(&format!("{h}{l}"), 16) {
                                val.push(b as char);
                                continue;
                            }
                            val.push('x');
                            val.push(h);
                            val.push(l);
                        }
                    }
                    Some(c) => val.push(c),
                    None => break,
                },
                Some(c) => val.push(c),
                None => break,
            }
        }

        match key.as_str() {
            "NAME" => dev.name = val,
            "PATH" => dev.path = val,
            "TYPE" => dev.dev_type = val,
            "HOTPLUG" => dev.hotplug = val == "1",
            "RM" => dev.removable = val == "1",
            "LABEL" => dev.label = val,
            "UUID" => dev.uuid = val,
            "FSTYPE" => dev.fstype = val,
            "SIZE" => dev.size = val,
            "MOUNTPOINTS" => {
                dev.mountpoints = val
                    .split('\n')
                    .map(str::trim)
                    .filter(|m| !m.is_empty() && *m != "[SWAP]")
                    .map(str::to_string)
                    .collect()
            }
            _ => {}
        }
    }

    if dev.path.is_empty() { None } else { Some(dev) }
}

fn show_device(d: &Device) -> bool {
    !d.path.is_empty()
        && !d.fstype.eq_ignore_ascii_case("swap")
        && ((matches!(d.dev_type.as_str(), "part" | "disk" | "crypt" | "lvm")
            && !d.fstype.is_empty())
            || d.mountpoints.iter().any(|m| is_user_mount(m)))
        && !d.mountpoints.iter().any(|m| is_system_mount(m))
}

fn device_priority(d: &Device) -> i32 {
    if d.removable || d.hotplug {
        1
    } else if !d.mountpoints.is_empty() {
        0
    } else {
        2
    }
}

fn primary_mount(d: &Device) -> Option<&str> {
    d.mountpoints
        .iter()
        .find(|m| is_user_mount(m))
        .or_else(|| d.mountpoints.first())
        .map(String::as_str)
}

fn device_title(d: &Device) -> String {
    let label = d.label.trim();
    if !label.is_empty() {
        return label.to_string();
    }
    if let Some(m) = primary_mount(d) {
        if m == "/" {
            return "Sistema".into();
        }
        if let Some(n) = Path::new(m).file_name().and_then(|v| v.to_str()) {
            if !n.is_empty() {
                return n.to_string();
            }
        }
    }
    d.name.clone()
}

fn is_user_mount(m: &str) -> bool {
    m.starts_with("/run/media/") || m.starts_with("/media/") || m.starts_with("/mnt/")
}

fn desired_label_mount_path(d: &Device) -> Option<String> {
    let label = d.label.trim();
    let mount = primary_mount(d)?;
    if label.is_empty() || !(mount.starts_with("/run/media/") || mount.starts_with("/media/")) {
        return None;
    }

    let mount_path = Path::new(mount);
    let parent = mount_path.parent()?;
    let current_name = mount_path.file_name()?.to_str()?;
    if current_name == label {
        return None;
    }

    Some(parent.join(label).to_string_lossy().into_owned())
}

fn is_system_mount(m: &str) -> bool {
    matches!(m, "/" | "/boot" | "/boot/efi")
        || m.starts_with("/home/")
        || m.starts_with("/var/")
        || m.starts_with("/usr/")
        || m.starts_with("/etc/")
        || m.starts_with("/root")
        || m.starts_with("/srv/")
}

fn device_to_json(d: &Device) -> String {
    let mount = primary_mount(d).unwrap_or("");
    let desired_mount = desired_label_mount_path(d).unwrap_or_default();
    let can_remount = !desired_mount.is_empty();
    let id = if !d.uuid.is_empty() {
        format!("uuid:{}", d.uuid)
    } else {
        format!("path:{}", d.path)
    };
    let subtitle = {
        let mut p = Vec::<String>::with_capacity(4);
        if !d.size.is_empty() {
            p.push(d.size.clone());
        }
        if !d.fstype.is_empty() {
            p.push(d.fstype.to_uppercase());
        }
        p.push(if d.removable || d.hotplug {
            "Removível".into()
        } else {
            "Interno".into()
        });
        if !mount.is_empty() {
            p.push(mount.to_string());
        }
        p.join(" · ")
    };
    format!(
        "{{\"id\":\"{}\",\"devicePath\":\"{}\",\"title\":\"{}\",\"subtitle\":\"{}\",\
         \"mountPath\":\"{}\",\"desiredMountPath\":\"{}\",\"mounted\":{},\"canMount\":{},\"canUnmount\":{},\"canRemount\":{},\
         \"removable\":{},\"icon\":\"{}\"}}",
        json::escape(&id),
        json::escape(&d.path),
        json::escape(&device_title(d)),
        json::escape(&subtitle),
        json::escape(mount),
        json::escape(&desired_mount),
        !mount.is_empty(),
        mount.is_empty(),
        !mount.is_empty() && is_user_mount(mount),
        can_remount,
        d.removable || d.hotplug,
        if d.removable || d.hotplug {
            "drive-removable-media"
        } else {
            "drive-harddisk"
        },
    )
}

fn icmp(a: &str, b: &str) -> Ordering {
    a.to_lowercase().cmp(&b.to_lowercase())
}
