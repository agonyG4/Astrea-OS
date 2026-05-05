# Desktop Icons Overlay

Overlay Quickshell para mostrar atalhos de aplicativos direto na area de trabalho.

Ele gera uma lista pequena a partir dos `.desktop` em:

- `~/.local/share/applications`
- `/usr/local/share/applications`
- `/usr/share/applications`

Entradas do usuario tem prioridade sobre as do sistema quando existe um `.desktop`
com o mesmo nome de arquivo.

## Gerar apps

```bash
cd /home/agony/GitHub/Bench/desktop-icons
python3 generate_apps.py
```

Isso atualiza `apps.js` e `apps.json`. O overlay tambem consegue atualizar a
lista pelo menu de contexto do fundo.

## Rodar

```bash
qs -p /home/agony/GitHub/Bench/desktop-icons
```

Para deixar solto em background:

```bash
qs -d -p /home/agony/GitHub/Bench/desktop-icons
```

Duplo clique em um icone abre o aplicativo com `gio launch`.

O estado da grade fica em:

```bash
~/.local/state/Astrea/desktop-icons/state.json
```
