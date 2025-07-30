# Super Senha

Este repositório contém os arquivos iniciais para o projeto **Super Senha**, um jogo de adivinhação de palavras de 5 letras inspirado em Wordle.

Consulte o arquivo [`docs/Technical_Documentation.md`](docs/Technical_Documentation.md) para detalhes completos de implementação.

## Problemas de build no Android
Se ao compilar surgir a mensagem `Build failed due to use of deleted Android v1 embedding`, verifique se o arquivo `android/app/src/main/kotlin/com/example/supersenha/MainActivity.kt` utiliza `FlutterActivity` (embeddig v2). Esta versão do repositório já está atualizada, mas caso a pasta `android/` tenha sido removida execute `flutter create .` para gerá-la novamente.
