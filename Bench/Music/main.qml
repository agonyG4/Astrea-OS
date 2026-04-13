import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Window {
    id: root
    width: 650
    height: 420
    visible: true
    title: "Agony Spotify Player"
    color: "#0f0f0f"

    property string songTitle: "Carregando..."
    property string songArtist: ""
    property string songCover: ""
    property bool isPlaying: false
    property real progressRatio: 0

    // Comandos de Controle de Música INSTANTÂNEO (via DBus do kernel Linux)
    Process { id: cmdPlayPause; command: ["playerctl", "-p", "spotify_player", "play-pause"]; running: false }
    Process { id: cmdNext; command: ["playerctl", "-p", "spotify_player", "next"]; running: false }
    Process { id: cmdPrev; command: ["playerctl", "-p", "spotify_player", "previous"]; running: false }

    // Comando dinâmico para PLAYLIST
    Process {
        id: cmdPlayPlaylist
        property string playlistId: ""
        command: ["spotify_player", "playback", "start", "context", "--id", playlistId, "playlist"]
        running: false
    }

    function togglePlay() { cmdPlayPause.running = false; Qt.callLater(() => { cmdPlayPause.running = true; }) }
    function nextSong()   { cmdNext.running = false; Qt.callLater(() => { cmdNext.running = true; }) }
    function prevSong()   { cmdPrev.running = false; Qt.callLater(() => { cmdPrev.running = true; }) }
    
    // Tocar a playlist usando ID oficial 
    function playPlayist(id) { 
        cmdPlayPlaylist.playlistId = id; 
        cmdPlayPlaylist.running = false; 
        Qt.callLater(() => { cmdPlayPlaylist.running = true; }) 
    }

    // Monitor do estado atual p/ preencher os dados
    Process {
        id: monitorPlayback
        command: ["spotify_player", "get", "key", "playback"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var json = null;
                try { json = JSON.parse(data.trim()); } catch(e) { return; }
                
                if (!json || !json.item) {
                    root.songTitle = "Nenhuma música";
                    root.songArtist = "Selecione uma Playlist!";
                    root.isPlaying = false;
                    root.progressRatio = 0;
                    root.songCover = "";
                    return;
                }

                root.isPlaying = json.is_playing;
                root.songTitle = json.item.name;

                var artists = [];
                for (var i = 0; i < json.item.artists.length; i++) {
                    artists.push(json.item.artists[i].name);
                }
                root.songArtist = artists.join(", ");

                if (json.item.duration_ms > 0) {
                    root.progressRatio = json.progress_ms / json.item.duration_ms;
                }

                if (json.item.album && json.item.album.images && json.item.album.images.length > 0) {
                    root.songCover = json.item.album.images[0].url;
                }
            }
        }
    }

    // Busca das Playlists p/ preencher o Menu
    ListModel { id: playlistModel }

    Process {
        id: fetchPlaylists
        command: ["spotify_player", "get", "key", "user-playlists"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                var json = [];
                try { json = JSON.parse(data.trim()); } catch(e) { return; }
                playlistModel.clear();
                for (var i = 0; i < json.length; i++) {
                    playlistModel.append({
                        "pId": json[i].id,
                        "pName": json[i].name
                    });
                }
            }
        }
    }

    // O Player se atualiza automaticamente
    Timer {
        interval: 1000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            monitorPlayback.running = false;
            Qt.callLater(() => { monitorPlayback.running = true });
        }
    }

    // Traz as playlists ao Iniciar o App
    Component.onCompleted: {
        fetchPlaylists.running = true;
    }

    // ==========================================
    // FRONTEND NOVO COM ESTRUTURA METADE-METADE
    // ==========================================
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        // =======================
        // ESQUERDA: O SEU PLAYER
        // =======================
        Rectangle {
            Layout.fillHeight: true
            width: 320
            color: "#181818"
            radius: 16

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 200; height: 200
                    radius: 12
                    color: "#282828"
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: root.songCover
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 5
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.songTitle
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.maximumWidth: 280
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.songArtist
                        color: "#b3b3b3"
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        Layout.maximumWidth: 280
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 4
                    radius: 2
                    color: "#535353"
                    Rectangle {
                        width: parent.width * root.progressRatio
                        height: parent.height
                        radius: 2
                        color: "#1DB954"
                        Behavior on width { NumberAnimation { duration: 1000 } }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 30
                    Rectangle {
                        width: 40; height: 40; radius: 20; color: "transparent"
                        Text { anchors.centerIn: parent; text: "⏮"; color: "white"; font.pixelSize: 24 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.prevSong() }
                    }
                    Rectangle {
                        width: 50; height: 50; radius: 25; color: "white"
                        Text { anchors.centerIn: parent; text: root.isPlaying ? "⏸" : "▶"; color: "black"; font.pixelSize: 24 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePlay() }
                    }
                    Rectangle {
                        width: 40; height: 40; radius: 20; color: "transparent"
                        Text { anchors.centerIn: parent; text: "⏭"; color: "white"; font.pixelSize: 24 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextSong() }
                    }
                }
                
                Item { Layout.fillHeight: true } // Espaçador dinâmico
            }
        }

        // =======================
        // DIREITA: AS PLAYLISTS
        // =======================
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: true
            color: "#181818"
            radius: 16
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 15
                
                Text {
                    text: "Sua Coleção Spotify"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.bottomMargin: 10
                }

                ListView {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    model: playlistModel
                    spacing: 5
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 48
                        color: hoverArea.containsMouse ? "#2f2f2f" : "#212121"
                        radius: 8
                        
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 15
                            text: pName
                            color: hoverArea.containsMouse ? "#1DB954" : "white"
                            font.pixelSize: 14
                            font.bold: hoverArea.containsMouse
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onClicked: {
                                // O usuário clicando dispara o comando pro CLI
                                root.playPlayist(pId);
                            }
                        }
                    }
                }
            }
        }
    }
}
