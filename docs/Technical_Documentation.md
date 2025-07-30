# Documentação Técnica: Implementação do Jogo Super Senha em Flutter

## Visão Geral

O projeto **Super Senha** é um jogo de adivinhação de palavras de 5 letras (estilo Wordle), com 6 tentativas por partida. O jogador deve digitar uma palavra válida, receber feedback visual (letra correta na posição certa, letra existente na posição errada e letra inexistente) e tentar adivinhar a senha secreta.

---

## Tecnologias

- **Framework:** Flutter
- **Linguagem:** Dart
- **Plataformas:** Android e iOS
- **Gerenciadores auxiliares:**
  - `flutter_launcher_icons` (ícone do app)
  - `flutter_native_splash` (splash screen)

---

## Estrutura do Projeto

```
supersenha/
├── android/
├── ios/
├── assets/
│   ├── splash_screen.png
│   ├── icon.png
│   ├── play_icon.png
│   ├── help_icon.png
│   ├── settings_icon.png
├── lib/
│   └── main.dart
├── pubspec.yaml
```

---

## Funcionalidades do Jogo

### 1. Tela de Splash
- Imagem de fundo: `assets/splash_screen.png`
- Exibição inicial (configurada com `flutter_native_splash`)

### 2. Tela Principal
- Grid 5x6 para exibir tentativas
- Teclado virtual customizado com as letras A–Z
- Botões: `Somar` e `Dica`
- Dica opcional destaca uma letra da senha
- Validação de palavras com dicionário local (opcional: usar JSON de palavras válidas)

### 3. Lógica do Jogo
- Senha gerada aleatoriamente (pode ser diária, com base na data)
- Cada letra recebe uma cor de feedback:
  - Verde escuro: letra correta e na posição certa
  - Verde claro: letra correta, mas na posição errada
  - Cinza: letra não existe na senha
- Até 6 tentativas permitidas
- Exibição de mensagem de vitória ou derrota

---

## Design e UI

- Tema escuro (`ThemeData.dark()`)
- Ícones do menu em `assets/`:
  - `play_icon.png`: iniciar nova partida
  - `help_icon.png`: exibe instruções
  - `settings_icon.png`: som, tema, idioma

---

## pubspec.yaml

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/splash_screen.png
    - assets/icon.png
    - assets/play_icon.png
    - assets/help_icon.png
    - assets/settings_icon.png

flutter_icons:
  android: true
  ios: true
  image_path: "assets/icon.png"
  min_sdk_android: 21

flutter_native_splash:
  image: assets/splash_screen.png
  color: "#121212"
  fullscreen: true
```

---

## Lógica de Palavras

- A senha deve ser uma palavra de 5 letras (sem acento)
- Lista de palavras pode ser carregada de `assets/words.json`
- Verificação de validade ao submeter

---

## Testes e Validação

- Validação de tentativa incompleta (menos de 5 letras)
- Não permitir palavras repetidas
- Exibir mensagem se palavra não estiver no dicionário
- Mostrar tela final (vitória ou derrota)

---

## Sugestões de Componentes

- `WordGrid`: Widget que representa o tabuleiro de 6 linhas x 5 colunas
- `LetterTile`: Widget individual para cada letra da grade
- `VirtualKeyboard`: Teclado personalizado (A-Z + backspace + enter)
- `GameController`: Classe de controle de estado e lógica principal

---

## Extras

- Adicionar sons simples ao acertar ou errar
- Modo claro/escuro configurável
- Possibilidade de compartilhar pontuação
- Futuro: salvar histórico de vitórias/derrotas localmente

---

## Recursos Visuais

- Splash screen: `assets/splash_screen.png`
- Ícone do app: `assets/icon.png`
- Ícones de menu: 256x256 pixels

---

## Roadmap Sugerido

1. Estrutura básica do app (telas, navegação, assets)
2. Tela de splash e ícone do app
3. Grid de tentativas e teclado virtual
4. Validação da palavra e feedback visual
5. Botões “Somar” e “Dica”
6. Finalização (mensagens, reinício)
7. Testes
8. Screenshots promocionais e publicação

---

## Contato

Desenvolvido por: [Vinicius Perdigão]
Projeto inicial: [https://vini.me/supersenha](https://vini.me/supersenha)
