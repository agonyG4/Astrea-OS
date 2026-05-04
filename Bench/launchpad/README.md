# Launchpad Test

Versão seca: só grade com os ícones dos apps reais do sistema.

## Gerar a lista de apps

```bash
cd /home/agony/GitHub/Bench/launchpad
python3 generate_apps.py
```

Isso recria o arquivo `apps.js` a partir dos `.desktop` em:

- `/usr/share/applications`
- `/usr/local/share/applications`
- `~/.local/share/applications`

## Rodar

```bash
cd /home/agony/GitHub/Bench/launchpad
QT_QUICK_BACKEND=software qmlscene Main.qml
```
