import urllib.request
import urllib.parse
import json
import base64
import os
import hashlib
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
import threading

# Chave pública para bypassar limites de secret (PKCE)
CLIENT_ID = "65b708073fc0480ea92a077233ca87bd"
REDIRECT_URI = "http://127.0.0.1:8989/login"

AUTH_URL = "https://accounts.spotify.com/authorize"
TOKEN_URL = "https://accounts.spotify.com/api/token"
API_BASE_URL = "https://api.spotify.com/v1"

ACCESS_TOKEN = None

# ==========================================
# 1. CORE API DO SPOTIFY (Autenticação)
# ==========================================
def generate_pkce_pair():
    verifier = base64.urlsafe_b64encode(os.urandom(64)).decode('utf-8').rstrip('=')
    challenge_bytes = hashlib.sha256(verifier.encode('utf-8')).digest()
    challenge = base64.urlsafe_b64encode(challenge_bytes).decode('utf-8').rstrip('=')
    return verifier, challenge

def auth_flow():
    global ACCESS_TOKEN
    verifier, challenge = generate_pkce_pair()
    scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private"
    
    params = {
        "client_id": CLIENT_ID,
        "response_type": "code",
        "redirect_uri": REDIRECT_URI,
        "scope": scopes,
        "code_challenge_method": "S256",
        "code_challenge": challenge
    }
    url = f"{AUTH_URL}?{urllib.parse.urlencode(params)}"
    
    print("Abra no navegador e autorize o AgonyBackend:")
    print(url)
    try: webbrowser.open(url)
    except: pass

    redirected_url = input("\n👉 Cole o link do erro e dê ENTER para subir o Backend: ").strip()

    if "code=" in redirected_url:
        parsed_url = urllib.parse.urlparse(redirected_url)
        code = urllib.parse.parse_qs(parsed_url.query).get('code', [None])[0]
        if code:
            data = urllib.parse.urlencode({
                "grant_type": "authorization_code",
                "client_id": CLIENT_ID,
                "code": code,
                "redirect_uri": REDIRECT_URI,
                "code_verifier": verifier
            }).encode()
            
            req = urllib.request.Request(TOKEN_URL, data=data)
            req.add_header("Content-Type", "application/x-www-form-urlencoded")
            
            try:
                response = urllib.request.urlopen(req)
                resp_json = json.loads(response.read())
                ACCESS_TOKEN = resp_json.get("access_token")
                print("\n[!] BACKEND CONECTADO AO SPOTIFY COM SUCESSO!\n")
            except Exception as e:
                print("[-] Erro Auth:", e)
        else: print("[-] Código não encontrado!")
    else: print("[-] Link inválido!")


# ==========================================
# 2. O NOSSO PRÓPRIO SERVIDOR WEB (Porta 9999)
# ==========================================
# O QML vai conversar apenas com esse Servidor Python local!
class AgonyAPIHandler(BaseHTTPRequestHandler):
    def api_request(self, endpoint, method="GET", body=None):
        req = urllib.request.Request(f"{API_BASE_URL}{endpoint}", method=method)
        req.add_header("Authorization", f"Bearer {ACCESS_TOKEN}")
        if body:
            req.add_header("Content-Type", "application/json")
            req.data = json.dumps(body).encode()
            
        try:
            response = urllib.request.urlopen(req)
            if response.getcode() == 204: # Sem conteúdo / Sucesso mas vazio
                return {}
            return json.loads(response.read())
        except urllib.error.HTTPError as e:
            print(f"[-] API Req Error: {e.code}")
            return {"error": str(e.code)}
        except Exception as e:
            return {"error": str(e)}

    def do_GET(self):
        # Ignora logs pra não flodar terminal
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        # Permite que QML (ou navegador) conecte solto
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()

        # Rota 1: /status -> Pega a musica tocando
        if self.path == '/status':
            data = self.api_request("/me/player")
            self.wfile.write(json.dumps(data).encode())
            
        # Rota 2: /playlists -> Pega todas as Playlists
        elif self.path == '/playlists':
            data = self.api_request("/me/playlists?limit=50")
            self.wfile.write(json.dumps(data).encode())
            
        else:
            self.wfile.write(b'{"status": "API Ativa"}')

    def do_POST(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        
        # Rota 3: /play -> Dá play numa playlist
        if self.path.startswith('/play?id='):
            playlist_id = self.path.split('=')[1]
            # Manda ordem para API do Spotify preencher a "Caxinha De Som invisivel"
            self.api_request("/me/player/play", method="PUT", body={"context_uri": f"spotify:playlist:{playlist_id}"})
            
        self.wfile.write(b'{"status": "ok"}')

    def log_message(self, format, *args):
        pass # Remove poluição do log Web
        
def start_server():
    server = HTTPServer(('127.0.0.1', 9999), AgonyAPIHandler)
    print("🚀 Agony Backend de API Online! Odiando a porta 9999.")
    print("O seu QML agora pode chamar http://127.0.0.1:9999/status para ler direto do motor Cérebro!")
    server.serve_forever()

if __name__ == "__main__":
    print("--- INICIANDO AGONY ENGINE ---")
    auth_flow()
    if ACCESS_TOKEN:
        start_server()
