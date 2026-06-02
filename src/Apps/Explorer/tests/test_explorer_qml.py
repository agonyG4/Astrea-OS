import unittest
from pathlib import Path


APP_ROOT = Path(__file__).resolve().parents[1]


class ExplorerQmlFeatureRemovalTests(unittest.TestCase):
    def test_quicklook_is_not_wired_in_main_app_state_or_preview_state(self):
        sources = {
            "Main.qml": APP_ROOT / "Main.qml",
            "AppState.qml": APP_ROOT / "AppState.qml",
            "state/PreviewState.qml": APP_ROOT / "state/PreviewState.qml",
        }
        combined = "\n".join(path.read_text(encoding="utf-8") for path in sources.values())

        for forbidden in [
            "openQuickLook",
            "syncQuickLookSelection",
            "quickLook",
            "quicklook",
            "explorer-quicklook",
            "ASTREA_QUICKLOOK",
        ]:
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, combined)


class ExplorerQmlShortcutWiringTests(unittest.TestCase):
    def test_main_qml_routes_clipboard_shortcuts_through_actions(self):
        main_qml = (APP_ROOT / "Main.qml").read_text(encoding="utf-8")

        self.assertIn("id: explorerCopyAction", main_qml)
        self.assertIn("id: explorerCutAction", main_qml)
        self.assertIn("id: explorerPasteAction", main_qml)
        self.assertIn("shortcut: StandardKey.Copy", main_qml)
        self.assertIn("shortcut: StandardKey.Cut", main_qml)
        self.assertIn("shortcut: StandardKey.Paste", main_qml)
        self.assertIn("fileClipboardShortcutAllowed", main_qml)

    def test_focus_file_surface_targets_content_item(self):
        main_qml = (APP_ROOT / "Main.qml").read_text(encoding="utf-8")

        self.assertIn("function focusFileSurface()", main_qml)
        self.assertIn("contentItem.forceActiveFocus", main_qml)
        self.assertNotIn("\n        forceActiveFocus()\n", main_qml)

    def test_archive_process_preserves_helper_errors_and_resets_password_state(self):
        file_ops_qml = (APP_ROOT / "state" / "FileOperationsState.qml").read_text(encoding="utf-8")

        self.assertIn('archivePassword = password !== undefined && password !== null ? String(password) : ""', file_ops_qml)
        self.assertIn('if (archivePassword !== "")', file_ops_qml)
        self.assertIn("id: archiveExtractStderr", file_ops_qml)
        self.assertIn("ops.archiveExtractionError || archiveErr", file_ops_qml)

    def test_archive_completion_navigates_to_extracted_destination(self):
        file_ops_qml = (APP_ROOT / "state" / "FileOperationsState.qml").read_text(encoding="utf-8")

        self.assertIn('ops.archiveOperationMode === "extract" && ops.archiveExtractionDestination !== ""', file_ops_qml)
        self.assertIn("app.navigateTo(ops.archiveExtractionDestination)", file_ops_qml)
        self.assertIn('interval: ops.archiveExtractionError !== "" ? 6000 : 1800', file_ops_qml)

    def test_archive_progress_card_takes_priority_over_file_operation_card(self):
        main_qml = (APP_ROOT / "Main.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property bool archiveVisible: AppState.archiveExtractionRunning", main_qml)
        self.assertIn("readonly property bool fileOpVisible: AppState.fileOperationRunning && !archiveVisible", main_qml)


class ExplorerDialogAndDragRegressionTests(unittest.TestCase):
    def test_views_do_not_assume_main_window_focus_helper_exists(self):
        for relative in [
            "components/views/FileIconView.qml",
            "components/views/FileListView.qml",
        ]:
            with self.subTest(relative=relative):
                source = (APP_ROOT / relative).read_text(encoding="utf-8")
                self.assertNotIn("root.Window.window.focusFileSurface()", source)
                self.assertIn("ViewShared.focusFileSurface(root)", source)

    def test_drag_drop_detects_internal_multi_selection_without_drop_source(self):
        drag_support = (APP_ROOT / "AstreaFiles" / "DragDropSupport.js").read_text(encoding="utf-8")
        icon_view = (APP_ROOT / "components" / "views" / "FileIconView.qml").read_text(encoding="utf-8")
        list_view = (APP_ROOT / "components" / "views" / "FileListView.qml").read_text(encoding="utf-8")

        self.assertIn("function dropModeFor(drop, appState)", drag_support)
        self.assertIn("selectedPathsInCurrentFolder", drag_support)
        self.assertIn("dropModeFor(drop, AppState)", icon_view)
        self.assertIn("handleDroppedUrls(AppState, drop, destinationPath)", list_view)

    def test_drag_drop_uses_normalized_paths_for_multi_file_moves(self):
        drag_support = (APP_ROOT / "AstreaFiles" / "DragDropSupport.js").read_text(encoding="utf-8")
        app_state = (APP_ROOT / "AppState.qml").read_text(encoding="utf-8")
        file_ops_qml = (APP_ROOT / "state" / "FileOperationsState.qml").read_text(encoding="utf-8")

        self.assertIn('dataAsString(drop, "text/uri-list")', drag_support)
        self.assertIn('dataAsString(drop, "text/plain")', drag_support)
        self.assertIn("appState.dropFilePaths(", drag_support)
        self.assertIn("DragDropSupport.dropPaths(drop)", (APP_ROOT / "components" / "views" / "FileIconView.qml").read_text(encoding="utf-8"))
        self.assertIn("function dropFilePaths(paths, destinationPath, mode)", app_state)
        self.assertIn("function dropFilePaths(paths, destinationPath, mode)", file_ops_qml)
        self.assertIn('cmd = cmd.concat(["--rename", pendingPasteRename])', file_ops_qml)
        self.assertNotIn("policy,\n            pendingPasteRename", file_ops_qml)

    def test_file_dialog_uses_astrea_components_and_multiple_selection(self):
        file_dialog = (APP_ROOT / "FileDialog.qml").read_text(encoding="utf-8")
        portal_dialog = (APP_ROOT / "PortalDialog.qml").read_text(encoding="utf-8")

        self.assertIn('import "AstreaComponents" as UI', file_dialog)
        self.assertIn("property bool allowMultiple", file_dialog)
        self.assertIn("signal filesChosen(var files)", file_dialog)
        self.assertIn("UI.Button", file_dialog)
        self.assertIn("UI.SearchField", file_dialog)
        self.assertIn("UI.TextLabel", file_dialog)
        self.assertIn("dialog.allowMultiple = Boolean(options.multiple)", portal_dialog)
        self.assertIn("onFilesChosen", portal_dialog)
        self.assertNotIn("Bench File Dialog", portal_dialog)

    def test_remote_directories_disable_watchers_and_thumbnail_warmup(self):
        app_state = (APP_ROOT / "AppState.qml").read_text(encoding="utf-8")
        navigation = (APP_ROOT / "state" / "NavigationState.qml").read_text(encoding="utf-8")
        preview = (APP_ROOT / "state" / "PreviewState.qml").read_text(encoding="utf-8")

        self.assertIn("property alias remoteDirectoryActive", app_state)
        self.assertIn("property bool remoteDirectoryActive", navigation)
        self.assertIn("function remotePathReason(path)", navigation)
        self.assertIn("updateRemoteStateFromItems(items)", navigation)
        self.assertIn("item.fileRemote", navigation)
        self.assertIn("remoteDirectoryActive", navigation)
        self.assertIn("app.remoteDirectoryActive", preview)


class ExplorerIconRenderingRegressionTests(unittest.TestCase):
    def test_icon_grid_decodes_theme_icons_at_stable_size_during_resize(self):
        icon_view = (APP_ROOT / "components" / "views" / "FileIconView.qml").read_text(encoding="utf-8")

        self.assertIn("readonly property int   iconDecodeSize", icon_view)
        self.assertIn("AppState.portalIconSource(tile.cachedIconName, grid.iconDecodeSize)", icon_view)
        self.assertIn("sourceSize: Qt.size(grid.iconDecodeSize, grid.iconDecodeSize)", icon_view)
        self.assertNotIn("sourceSize: Qt.size(grid.iconSize, grid.iconSize)", icon_view)

    def test_theme_icon_fallbacks_retain_cached_image_while_loading(self):
        for relative in [
            "components/views/FileIconView.qml",
            "components/views/FileListView.qml",
            "components/layout/PreviewPanel.qml",
        ]:
            with self.subTest(relative=relative):
                source = (APP_ROOT / relative).read_text(encoding="utf-8")
                self.assertIn("cache: true", source)
                self.assertIn("retainWhileLoading: true", source)

if __name__ == "__main__":
    unittest.main()
