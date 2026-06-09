use astrea_filechooser_portal::{
    DialogMode, PortalOptions, PortalSelection, run_dialog, save_file_names_from_options,
    uris_for_save_files, uris_from_selection,
};
use std::collections::HashMap;
use zbus::connection;
use zvariant::{OwnedObjectPath, OwnedValue, Value};

const BUS_NAME: &str = "org.freedesktop.impl.portal.desktop.astrea";
const OBJECT_PATH: &str = "/org/freedesktop/portal/desktop";
const RESPONSE_SUCCESS: u32 = 0;
const RESPONSE_CANCELLED: u32 = 1;

type PortalResponse = (u32, HashMap<String, OwnedValue>);

struct AstreaFileChooser;

#[zbus::interface(name = "org.freedesktop.impl.portal.FileChooser")]
impl AstreaFileChooser {
    #[zbus(name = "OpenFile")]
    #[zbus(out_args("response", "results"))]
    fn open_file(
        &self,
        handle: OwnedObjectPath,
        app_id: String,
        parent_window: String,
        title: String,
        options: PortalOptions,
    ) -> zbus::fdo::Result<(u32, HashMap<String, OwnedValue>)> {
        let _ = (handle, app_id, parent_window);
        let mode = DialogMode::OpenFile;
        Ok(response_from_selection(run_dialog(mode, &title, &options)))
    }

    #[zbus(name = "SaveFile")]
    #[zbus(out_args("response", "results"))]
    fn save_file(
        &self,
        handle: OwnedObjectPath,
        app_id: String,
        parent_window: String,
        title: String,
        options: PortalOptions,
    ) -> zbus::fdo::Result<(u32, HashMap<String, OwnedValue>)> {
        let _ = (handle, app_id, parent_window);
        let mode = DialogMode::SaveFile;
        Ok(response_from_selection(run_dialog(mode, &title, &options)))
    }

    #[zbus(name = "SaveFiles")]
    #[zbus(out_args("response", "results"))]
    fn save_files(
        &self,
        handle: OwnedObjectPath,
        app_id: String,
        parent_window: String,
        title: String,
        options: PortalOptions,
    ) -> zbus::fdo::Result<(u32, HashMap<String, OwnedValue>)> {
        let _ = (handle, app_id, parent_window);
        let selection = match run_dialog(DialogMode::SelectFolder, &title, &options) {
            Ok(selection) if selection.accepted => selection,
            Ok(_) | Err(_) => return Ok(cancelled_response()),
        };
        let file_names = save_file_names_from_options(&options);
        match uris_for_save_files(&selection, &file_names) {
            Ok(uris) => Ok(success_response(uris)),
            Err(_) => Ok(cancelled_response()),
        }
    }
}

fn response_from_selection(
    selection: Result<PortalSelection, impl std::fmt::Display>,
) -> PortalResponse {
    match selection {
        Ok(selection) if selection.accepted => match uris_from_selection(&selection) {
            Ok(uris) => success_response(uris),
            Err(_) => cancelled_response(),
        },
        Ok(_) | Err(_) => cancelled_response(),
    }
}

fn success_response(uris: Vec<String>) -> PortalResponse {
    let mut results = HashMap::new();
    if let Ok(value) = OwnedValue::try_from(Value::from(uris)) {
        results.insert("uris".to_string(), value);
    }
    (RESPONSE_SUCCESS, results)
}

fn cancelled_response() -> PortalResponse {
    (RESPONSE_CANCELLED, HashMap::new())
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> zbus::Result<()> {
    let _connection = connection::Builder::session()?
        .name(BUS_NAME)?
        .serve_at(OBJECT_PATH, AstreaFileChooser)?
        .build()
        .await?;
    std::future::pending::<()>().await;
    Ok(())
}
