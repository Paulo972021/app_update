# Escopo e rotina de atualização do app mobile

## Objetivo

Padronizar um fluxo simples e confiável para validar e publicar mudanças no app mobile, mantendo validação local obrigatória antes de qualquer envio para EAS.

## Regras de decisão

### Use **EAS Update** quando a mudança for apenas JS/TS/UI/lógica

Exemplos:
- Arquivos em `src/`
- Telas, componentes, estilos
- Validações, navegação, lógica de exercícios
- Mensagens e textos
- Correções sem alteração de dependências/configuração nativa

### Use **EAS Build** quando houver mudança nativa/config/dependência/asset

Gatilhos de build:
- `app.json`, `package.json`, `package-lock.json`, `eas.json`
- Qualquer `expo install` ou `npm install`
- `assets/icon.png`, splash, adaptive icon
- Plugins Expo
- Configurações Android/iOS
- Permissões
- Qualquer ajuste com impacto em build nativo

## Validação obrigatória (sempre antes de publicar)

Na pasta `english-exercises-mobile`, executar:

1. Validar `app.json`

```bat
node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
```

2. Validar bundle/export

```bat
npx expo export --platform android --platform ios
```

3. Conferir e registrar Git

```bat
git status
git add .
git commit -m "descrição curta da mudança"
```

> Regra crítica: **não publicar** (`eas update`/`eas build`) se o `expo export` falhar.

## Comandos de publicação

### Cenário A — Atualização rápida sem novo APK

```bat
cd english-exercises-mobile
node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
npx expo export --platform android --platform ios
git status
git add .
git commit -m "Update app logic/UI"
eas update --branch preview --message "Update app logic/UI"
```

### Cenário B — Novo APK

```bat
cd english-exercises-mobile
node -e "JSON.parse(require('fs').readFileSync('app.json','utf8')); console.log('app.json OK')"
npx expo export --platform android --platform ios
git status
git add .
git commit -m "Prepare new Android build"
eas build -p android --profile preview --clear-cache
```


### Saída do build: link e QR

Ao escolher **Gerar novo APK (EAS Build)** no `deploy_mobile.bat`, o script tenta extrair automaticamente o link da build e mostra:
- link da build no EAS;
- URL de QR Code para abrir esse link no celular.

Se não conseguir extrair automaticamente, ele orienta usar:

```bat
eas build:list -p android --limit 1
```

## Regras técnicas adicionais

1. Não usar `npm audit fix --force` sem avaliação.
2. Preservar no `app.json`:
   - `expo.extra.eas.projectId`
   - `expo.android.package`
   - plugins necessários, incluindo:
     - `"expo-asset"`
     - `["expo-build-properties", { "android": { "kotlinVersion": "1.9.25" } }]`

## Regra para ZIP importado pelo app

Estrutura esperada:

```text
pack.zip
├─ manifest.json
├─ exercises.jsonl
└─ audio/
```

Checklist:
- `manifest.json` na raiz do ZIP
- `exercises.jsonl` no caminho indicado no manifest
- Cada exercício com `exercise_id`, `modality` e `ui_model`
- Paths de áudio relativos
- Sem pasta extra encapsulando todo conteúdo

## Automação local

Use o script `deploy_mobile.bat` (na raiz) para:
1. Validar projeto
2. Publicar update (EAS Update)
3. Gerar novo APK (EAS Build)
4. Mostrar status do git
5. Stage seguro + status (faz `git add .` e remove do stage apenas o ruído comum de `.expo/`, `dist/` e `node_modules/`)

### Situação comum: mudanças não staged + untracked temporários

Se o `git status` mostrar muitos arquivos temporários (ex.: `.expo/`, `dist/`, `node_modules/`) junto com alterações reais, use a opção **5** do script antes de publicar.

Esse fluxo evita o erro "no changes added to commit" por falta de stage e reduz chance de commitar artefatos temporários.


### Compatibilidade de pasta do projeto

O `deploy_mobile.bat` detecta automaticamente estes cenários:
- script ao lado da pasta `english-exercises-mobile`;
- script dentro da própria raiz do app (onde existe `app.json`).

Assim, o mesmo script funciona nos dois formatos de organização.
