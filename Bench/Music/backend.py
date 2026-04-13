import sys
from PyQt6.QtCore import QObject, pyqtSlot, pyqtProperty, pyqtSignal, QUrl
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

class SpotifyBackend(QObject):
    # Sinal emitido sempre que uma propriedade da música mudar
    songChanged = pyqtSignal()

    def __init__(self):
        super().__init__()
        # Estado inicial (música mockada)
        self._title = "Blinding Lights"
        self._artist = "The Weeknd"
        self._cover = "https://i.scdn.co/image/ab67616d00001e028863bc11d2aa12b54f5aeb36"
        self._is_playing = False

    # Propriedades expostas para o QML
    @pyqtProperty(str, notify=songChanged)
    def title(self):
        return self._title

    @pyqtProperty(str, notify=songChanged)
    def artist(self):
        return self._artist

    @pyqtProperty(str, notify=songChanged)
    def cover(self):
        return self._cover

    @pyqtProperty(bool, notify=songChanged)
    def isPlaying(self):
        return self._is_playing

    # Ações recebidas do QML
    @pyqtSlot()
    def togglePlay(self):
        self._is_playing = not self._is_playing
        self.songChanged.emit()

    @pyqtSlot()
    def nextSong(self):
        self._title = "Starboy"
        self._artist = "The Weeknd, Daft Punk"
        self._cover = "https://i.scdn.co/image/ab67616d00001e024718e2b124f79258be7bc452"
        self._is_playing = True
        self.songChanged.emit()

    @pyqtSlot()
    def prevSong(self):
        self._title = "Save Your Tears"
        self._artist = "The Weeknd"
        self._cover = "https://i.scdn.co/image/ab67616d00001e028863bc11d2aa12b54f5aeb36"
        self._is_playing = True
        self.songChanged.emit()

def main():
    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    
    # Instanciamos o backend e passamos para o contexto principal do QML
    backend = SpotifyBackend()
    engine.rootContext().setContextProperty("backend", backend)
    
    # Carregamos o arquivo da interface (Front)
    engine.load(QUrl.fromLocalFile("main.qml"))
    
    if not engine.rootObjects():
        sys.exit(-1)
        
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
