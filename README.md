# Super Senha

Este repositório contém os arquivos iniciais para o projeto **Super Senha**, um jogo de adivinhação de palavras de 5 letras inspirado em Wordle.

Consulte o arquivo [`docs/Technical_Documentation.md`](docs/Technical_Documentation.md) para detalhes completos de implementação.

## Problemas de build no Android
Se ao compilar surgir a mensagem `Build failed due to use of deleted Android v1 embedding`, certifique-se de que o projeto está configurado para o Android v2 embedding. Siga os passos abaixo:

1. Abra `android/app/src/main/AndroidManifest.xml` e verifique se a tag `<application>` contém `android:name="${applicationName}"`.
2. Dentro da `<activity>` principal (`.MainActivity`), remova qualquer meta‑data do v1 embedding, como:

   ```xml
   <meta-data
       android:name="io.flutter.app.android.SplashScreenUntilFirstFrame"
       android:value="true" />
   ```

3. Ainda na `<activity>` principal, garanta que existe a meta‑data abaixo para habilitar o v2 embedding:

   ```xml
   <meta-data
       android:name="flutterEmbedding"
       android:value="2" />
   ```

4. Confira se o arquivo `android/app/src/main/kotlin/me/vini/super_senha/MainActivity.kt` estende `io.flutter.embedding.android.FlutterActivity`.
5. Após ajustar os arquivos, execute `flutter clean` e `flutter pub get` para reconstruir o projeto.

Esta versão do repositório já está configurada para o v2 embedding, mas caso a pasta `android/` tenha sido removida execute `flutter create .` para gerá-la novamente.

## Configurações

No menu de configurações do aplicativo é possível escolher se prefere usar o teclado virtual da aplicação ou o teclado do dispositivo. Por padrão, o teclado do dispositivo é utilizado.
