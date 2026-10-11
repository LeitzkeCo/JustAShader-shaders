# Just a Shader

Shader feito para o modpack **Just a Explorer** (Just a Farmer, Just an Archeologist e o resto da família JUST).

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
| Cor final | `shaders/program/composite5.glsl` | `DoJustGrade`: realces quentes, sombras suaves, meios-tons e verdes mais ricos (opções `JUST_WARMTH` e `JUST_RICHNESS`) |
| Nuvens | `shaders/lib/atmospherics/clouds/reimaginedClouds.glsl` | Nuvens com altura: topo em relevo que cresce no meio das massas de nuvem (opção `CLOUD_RISE`) |
| Outline por bloco | `shaders/lib/misc/blockOutline.glsl`, `shaders/program/deferred1.glsl` | Contorno claro nas arestas expostas, com um corte em cada quina de bloco (opções `BLOCK_OUTLINE`, `BLOCK_OUTLINE_I`, `BLOCK_OUTLINE_THICKNESS`) |
| Aberração cromática | `shaders/program/final.glsl` | Centro da tela limpo, efeito cresce em direção às bordas; ligada por padrão |
| Vento | `shaders/lib/materials/materialMethods/wavingBlocks.glsl` | Rajadas que atravessam o campo e dobram as plantas juntas (opções `WIND_GUSTS`, `WIND_GUST_I`) |
| Clima por bioma | `mainFog.glsl`, `composite5.glsl`, `final.glsl` | Poeira e calor tremulando em desertos, névoa esverdeada em pântanos, ar frio na neve (opção `BIOME_MOOD`) |
| Subterrâneo | `composite5.glsl`, `common.glsl`, `blocklightColors.glsl` | Sombras frias, escuridão azulada e tochas mais quentes |
| Pôr do sol nas nuvens | `reimaginedClouds.glsl` | Topos dourados e bases arroxeadas conforme a altura |
| Sol e lua | `sky.glsl`, `gbuffers_skytextured.glsl` | Halo largo, sol mais dourado, lua mais clara e fria |
| Chuva | `gbuffers_terrain.glsl` | Chão exposto escurece ao molhar (opção `WET_GROUND`) |
| Diorama | `final.glsl` | Desfoque em cima e embaixo da tela, desligado por padrão (opções `TILT_SHIFT`, `TILT_SHIFT_I`) |
| Clima geral | `composite5.glsl` | Opção `JUST_MOOD`: Farm Morning, Expedition, Campfire Night |
| Perfis | `shaders.properties`, `en_US.lang` | Perfis de desempenho com nomes de fazenda: Seed, Sprout, Seedling, Garden, Field, Orchard, Harvest, Bounty |
| End: céu | `shaders/lib/atmospherics/endSky.glsl` | Espaço profundo: estrelas frias, faixa de galáxia, quatro constelações com linhas (opções `END_GALAXY`, `END_CONSTELLATIONS`) |
| End: tempestade | `shaders/lib/atmospherics/endStorm.glsl` | Tempestade sem nuvens: clarões no céu e raios em zigue-zague (opções `END_STORM`, `END_STORM_I`) |
| End: ciclo de cor | `shaders/lib/common.glsl`, `lightAndAmbientColors.glsl` | A cor do End vai de azul para roxo, menta e volta ao azul (opções `END_COLOR_CYCLE`, `END_COLOR_CYCLE_TIME`) |
| Meteoros | `shaders/lib/atmospherics/meteors.glsl` | Meteoros com cauda e raridades de cor à noite; no End também há chuvas de meteoros (opções `METEORS`, `METEOR_I`) |
| Menu | `shaders/shaders.properties` | Tela **Just a Shader** em primeiro lugar, com as opções que definem o visual |
| Padrões | `shaders/lib/common.glsl` | Saturação, vibrance e bloom |

## Requisitos

Minecraft 1.20.1, 1.21.1, 1.21.11 e 26.3, com Iris. São as mesmas versões cobertas pela base r5.9.3.

## Instalação

Copie esta pasta (ou um `.zip` dela) para `shaderpacks/` e escolha **JustAShader** no menu de shaders.

## Plantações dos mods JUST

Para uma plantação balançar com o vento, acrescente o id do bloco ao final da primeira linha `block.10005` em
`shaders/block.properties`, por exemplo `justafarmer:rice`.
