# Just a Shader

Shader exclusivo do modpack **Just a Explorer** (Just a Farmer, Just an Archeologist e o resto da família JUST).

Visual aconchegante e rural: luz dourada, golden hour mais longo, horizonte quente, névoa baixa de manhã e verdes mais vivos.

## Créditos

Criado por **LeitzkeCo**: https://github.com/LeitzkeCo

Just a Shader é uma versão modificada do **Complementary Reimagined r5.9.3**, de EminGT.

- Site oficial do Complementary: https://www.complementary.dev
- A licença original está em [License.txt](License.txt) e precisa continuar dentro do pack, sem alterações.

## O que muda em relação ao original

| Área | Arquivo | Mudança |
| --- | --- | --- |
| Luz do sol e ambiente | `shaders/lib/colors/lightAndAmbientColors.glsl` | Sol mais dourado, sombras menos azuladas, golden hour mais longo |
| Céu | `shaders/lib/colors/skyColors.glsl` | Horizonte quente de dia, pôr do sol âmbar que dura mais |
| Névoa | `shaders/lib/atmospherics/fog/mainFog.glsl` | Névoa matinal baixa (opções `MORNING_MIST` e `MORNING_MIST_I`) |
| Cor final | `shaders/program/composite5.glsl` | `DoJustGrade`: realces quentes, sombras suaves, verdes mais ricos (opção `JUST_WARMTH`) |
| Padrões | `shaders/lib/common.glsl` | Saturação, vibrance e bloom |

## Requisitos

Minecraft 1.20.1, 1.21.1, 1.21.11 e 26.3, com Iris. São as mesmas versões cobertas pela base r5.9.3.

## Instalação

Copie esta pasta (ou um `.zip` dela) para `shaderpacks/` e escolha **JustAShader** no menu de shaders.

## Plantações dos mods JUST

Para uma plantação balançar com o vento, acrescente o id do bloco ao final da primeira linha `block.10005` em
`shaders/block.properties`, por exemplo `justafarmer:rice`.
