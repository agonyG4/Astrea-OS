import urllib.request
import urllib.parse
import json
import base64
import os
import hashlib
import webbrowser

# ==========================================
# 1. Chaves copiadas do código-fonte do spotify_player
# ==========================================
# Não precisamos de .env ou Painel de Desenvolvedor. 
# Usaremos o Client ID público deles e o método PKCE (sem Client Secret)
CLIENT_ID = "65b708073fc0480ea92a077233ca87bd"
REDIRECT_URI = "http://127.0.0.1:8989/login"

AUTH_URL = "https://accounts.spotify.com/authorize"
TOKEN_URL = "https://accounts.spotify.com/api/token"
API_BASE_URL = "https://api.spotify.com/v1"

ACCESS_TOKEN = None

# Gerador de Chaves para o fluxo PKCE (Padrão para apps desktop sem Password/Secret)
def generate_pkce_pair():
    verifier = base64.urlsafe_b64encode(os.urandom(64)).decode('utf-8').rstrip('=')
    challenge_bytes = hashlib.sha256(verifier.encode('utf-8')).digest()
    challenge = base64.urlsafe_b64encode(challenge_bytes).decode('utf-8').rstrip('=')
    return verifier, challenge

# ==========================================
# 2. Autenticação PKCE
# ==========================================
def authorize():
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
    
    print("\n--- ETAPA 1: AUTORIZAÇÃO CLONADA DO SPOTIFY_PLAYER ---")
    print("Vou tentar abrir o navegador. Pode autorizar o app oficial do spotify_player lá!")
    print("Quando der erro de 'Não foi possível conectar', COPIE E COLE o link gigantesco cheio de códigos.\n")
    print("Se não abrir, clique: " + url + "\n")
    
    try:
        webbrowser.open(url)
    except:
        pass

    redirected_url = input("\n👉 Cole o link completo que tem o erro aqui: ").strip()

    if "code=" in redirected_url:
        parsed_url = urllib.parse.urlparse(redirected_url)
        code = urllib.parse.parse_qs(parsed_url.query).get('code', [None])[0]
        
        if code:
            # Troca do Token com o Verifier (Sem precisar de Client Secret)
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
                print("\n[+] BINGO! Hackeado e Autorizado usando o ID do spotify_player sem .env!")
            except Exception as e:
                print("[-] Erro ao obter o token na troca:", e)
        else:
            print("[-] Não consegui achar o 'code=' no link copiado.")
    else:
        print("[-] Você não colou um link válido da página de erro.")

# ==========================================
# 3. Consumo da API Real
# ==========================================
def get_current_playback():
    req = urllib.request.Request(f"{API_BASE_URL}/me/player")
    req.add_header("Authorization", f"Bearer {ACCESS_TOKEN}")
    try:
        response = urllib.request.urlopen(req)
        if response.getcode() == 204:
            return None
        return json.loads(response.read())
    except urllib.error.HTTPError as e:
        print("[-] HTTP Error API:", e.code, e.reason)
        return None
    except Exception as e:
        print("[-] Erro ao pegar playback:", e)
        return None

def main():
    authorize()
    
    if ACCESS_TOKEN:
        print("\n--- ETAPA 2: DADOS CAPTURADOS ---")
        pb = get_current_playback()
        if pb and pb.get("item"):
            print(f"> Tocando agora: {pb['item']['name']} por {pb['item']['artists'][0]['name']}")
            print(f"> Album: {pb['item']['album']['name']}")
            print(f"> Progresso: {(pb['progress_ms']/1000/60):.2f}m / {(pb['item']['duration_ms']/1000/60):.2f}m")
            print(f"> Dispositivo: {pb.get('device', {}).get('name')}")
            print("\nSUCESSO! Evitamos todo o Dashboard copiando a estratégia deles de PKCE!")
        else:
            print("\nNenhuma musica tocando no momento em NENHUM dispositivo.")
            print("(Deixe uma música tocando no seu celular ou app desktop e rode o programa de novo!)")
            
if __name__ == "__main__":
    main()
