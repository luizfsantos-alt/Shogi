# Builds de teste

Os APKs de **teste** são assinados com uma chave gerada pelo próprio workflow **Godot app** na
primeira execução e guardada no cache do GitHub Actions (`shogi-test-keystore-v1`). Assim todo
APK de teste tem a mesma assinatura e instala por cima do anterior. A chave não fica no
repositório. Se o cache expirar (7 dias sem builds), uma chave nova é gerada e o próximo APK
pede para desinstalar o anterior uma vez.

A versão de loja será assinada com uma chave própria guardada nos segredos do GitHub.
