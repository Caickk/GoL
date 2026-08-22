# Profiling em CPU: Game of Life

## Discentes

- [Camila De Araújo Bastos](https://github.com/camilaab)
- [Caick Wendell Lopes dos Santos](https://github.com/caickkk)
# Descrição do algoritmo

O código implementa uma versão serial do **Conway's Game of Life (Jogo da Vida)**, um autômato celular criado pelo matemático John Horton Conway. O algoritmo simula a evolução de uma grade bidimensional de células (vivas ou mortas) ao longo de sucessivas gerações, baseando-se no estado da vizinhança imediata (as 8 células ao redor) de cada posição.

### Regras do Jogo
A transição de uma geração para a seguinte ocorre de forma simultânea para todo o tabuleiro, seguindo quatro regras matemáticas estritas:
1. **Subpopulação:** Uma célula viva com menos de dois vizinhos vivos morre.
2. **Sobrevivência:** Uma célula viva com dois ou três vizinhos vivos permanece viva na próxima geração.
3. **Superpopulação:** Uma célula viva com mais de três vizinhos vivos morre.
4. **Reprodução:** Uma célula morta com exatamente três vizinhos vivos se torna uma célula viva.

### Arquitetura da Implementação
Para atender a essas regras computacionalmente, a arquitetura do algoritmo foi estruturada da seguinte forma:

*   **Estrutura de Dados (Matrizes de Estado):** O programa utiliza duas matrizes bidimensionais na memória. A matriz original (`univ`) representa a geração atual, enquanto uma matriz temporária (`new`) armazena a próxima geração. Isso garante que as atualizações ocorram de forma síncrona, evitando que o nascimento ou morte de uma célula afete o cálculo de suas vizinhas no mesmo ciclo.
*   **Topologia do Universo (Matriz Toroidal):** As regras assumem uma grade infinita. Para simular isso na memória RAM sem causar falhas de acesso (*segmentation fault*), o algoritmo adota uma topologia toroidal. Usando a operação de módulo (`%`), as bordas da matriz se conectam: a borda direita encosta na esquerda, e a inferior na superior.
*   **Lógica de Transição (Hotspot):** A função `evolve` é o núcleo do processamento. Nela, as quatro regras clássicas descritas acima foram otimizadas e condensadas em uma única expressão booleana eficiente para a CPU: `new[y][x] = (n == 3 || (n == 2 && univ[y][x]));`.

# Detalhes de compilação para cada um dos métodos utilizados

Para atender aos requisitos do trabalho e garantir a correta medição pelas diferentes ferramentas de profiling, foram utilizados dois métodos distintos de compilação.

## Compilação Base (time, perf, Valgrind e strace)
Para a execução padrão e análise com ferramentas que leem eventos do sistema ou de hardware (`/usr/bin/time`, `perf`, `Valgrind`, `strace`), o código deve ser compilado via terminal com otimização desativada e inclusão de símbolos de depuração.

* **Comando utilizado:** 
  `gcc -O0 -g -o gol gol.c`

* **Detalhes das flags:**
  * `-O0`: Desativa as otimizações do compilador. Isso é obrigatório para garantir que o tempo de execução alcance pelo menos 2 segundos (wall-clock time) com um volume de dados suficiente, sem que o compilador altere a estrutura serial do código.
  * `-g`: Adiciona símbolos de debug, permitindo que ferramentas como o *perf* e o *Valgrind* consigam mapear as instruções de máquina de volta para as linhas exatas do código-fonte em C.
  * `-o gol`: Define o nome do arquivo executável gerado.

## Compilação para Profiling com gprof
O `gprof` exige uma compilação específica com instrumentação de código para conseguir rastrear o grafo de chamadas (call graph) e os tempos de execução internos das funções (flat profile).

* **Comando utilizado:** 
  `gcc -pg -O0 -g -o gol gol.c`

* **Detalhes da flag adicional:**
  * `-pg`: Habilita o suporte a perfilamento. O compilador insere um código extra no executável que registra as informações de tempo e contagem de chamadas de cada função executada, gerando o arquivo `gmon.out` necessário para a leitura do `gprof`.
  
# Execução e Parâmetros de Linha de Comando

O código fonte foi estruturado de forma a manter quatro parâmetros numéricos fixos: a largura da placa, a altura da placa, o número máximo de iterações e a frequência de salvamento das iterações (parâmetro XX). 

O formato de execução padrão segue a estrutura:
`./gol `

* **Exemplo de execução:** `./gol `

Para satisfazer os critérios do experimento, os parâmetros de entrada (dimensões da matriz e número de iterações) devem ser grandes o suficiente para que o programa processe um volume de dados adequado, garantindo que o tempo de execução alcance pelo menos 2 segundos em *wall-clock time* utilizando a compilação base.

Durante a coleta de métricas, a execução do binário foi encapsulada pelas ferramentas de profiling exigidas. Utilizando o exemplo de parâmetros acima, os comandos executados foram:

* **Medição de tempo total e recursos:** `/usr/bin/time -v ./gol`
* **Contagem de eventos de hardware:** `perf stat ./gol`
* **Gravação do overhead por função:** `perf record -g ./gol`
* **Leitura do relatório de overhead do perf:** `perf report --stdio`
* **Simulação de instruções de CPU:** `valgrind --tool=callgrind ./gol`
* **Simulação de acessos e misses de memória L1/L2:** `valgrind --tool=cachegrind ./gol`
* **Anotação dos resultados do Cachegrind:** `cg_annotate cachegrind.out.<PID>`
* **Rastreamento de chamadas de sistema:** `strace -c ./gol`
  
# Tabelas de resultados do time, gprof, perf, Valgrind e strace

Abaixo estão os resultados extraídos de cada ferramenta de profiling em dois ambientes de hardware distintos, seguindo os parâmetros definidos na especificação do projeto.

## Especificações dos Ambientes de Teste

**Ambiente 1 (CPU 1)**
* **Processador (CPU):** AMD Ryzen 5 7520U (4 Núcleos / 8 Threads)
* **Memória Cache:** L1: 128 KiB / L2: 2 MiB / L3: 4 MiB
* **Memória RAM:** 16 GB (2x 8GB) LPDDR5 Samsung @ 5500 MT/s (Dual-Channel)
* **Sistema Operacional:** Ubuntu 26
* **Kernel Linux:** 7.0.0-27-generic

**Ambiente 2 (CPU 2)**
* **Processador (CPU):** Intel® Core™ i5-1135G7 (4 Núcleos / 8 Threads)
* **Memória Cache:** L1: 320 KiB / L2: 5MB / L3: 8MB 
* **Memória RAM:** 12 GB DDR4
* **Sistema Operacional:** Ubuntu 26.04 
* **Kernel Linux:** 7.0.0-29-generic

## Medição de Tempo (`/usr/bin/time`)

---

### Dados coletados

| **Dado** | **CPU 1** | **CPU 2** |
|---|---:|---:|
| Wall-clock time | 5,71 s | 2,40 s |
| User time | 5,70 s | 2,40 s |
| System time | 0,00 s | 0,00 s |
| Maximum RSS | 2056 KB | 2220 KB |
| Page faults (minor/major) | 157 / 0 | 157 / 0 |
| Context switches (vol/invol) | 1 / 47 | 1 / 25 |

### Métricas

| **Métrica** | **Fórmula** | **CPU 1** | **CPU 2** | **O que faz / para que serve** |
|---|---|---:|---:|---|
| Speedup (tempo real) | `t1_wall / t2_wall` | — | **2,38x** | Compara o tempo total de execução entre as duas CPUs. |
| CPU utilization | `(user + sys) / wall × 100` | 99,82% | 100% | Mede a fração do tempo total em que a CPU esteve efetivamente ocupada processando, em vez de esperando por I/O, bloqueios ou sincronização. |
| Context switches/s | `switches / wall` | 8,41/s | 10,83/s | Mede a frequência de trocas de contexto do escalonador durante a execução. |
| Overhead de memória (RSS) | `RSS2 − RSS1` | Referência | +164 KB | Mede a diferença de pico de uso de memória residente entre as execuções. |

### Análise: CPU-bound ou I/O-bound?

A relação entre o tempo de CPU (`user + system`) e o tempo total decorrido (`wall-clock`) é praticamente **1:1** nas duas execuções (**99,82%** e **100%**).

O `system time` é **0,00 s** em ambas as execuções, ou seja, não há tempo relevante gasto esperando por chamadas de sistema, disco ou rede. Isso caracteriza a aplicação como **CPU-bound**: praticamente todo o tempo de execução é consumido pelo processamento na CPU, sem gargalos significativos de entrada/saída (I/O). Essa conclusão também é reforçada pelos dados do `strace` (Seção 5), onde o tempo gasto em modo kernel é irrisório em comparação ao `wall-clock`.

## Profiling com `gprof`

---

### Dados coletados, Flat Profile

| **Dado** | **CPU 1** | **CPU 2** |
|---|---:|---:|
| Hotspot | `evolve` | `evolve` |
| Self time do hotspot | 5,62 s | 2,39 s |
| % do tempo total | 100,00% | 100,00% |
| Chamadas de `evolve` | 2001 | 2001 |
| Chamadas de `game` | 1 | 1 |

### Dados coletados, Call Graph

| **Função** | **Chamadas** | **Self CPU 1** | **Self CPU 2** | **Children CPU 1** | **Children CPU 2** | **Quem chamou** |
|---|---:|---:|---:|---:|---:|---|
| `evolve` | 2001 | 5,62 s | 2,39 s | 0,00 s | 0,00 s | `game` |
| `game` | 1 | 0,00 s | 0,00 s | 5,62 s | 2,39 s | `main` |
| `main` | — | 0,00 s | 0,00 s | 5,62 s | 2,39 s | — |

### Métricas

| **Métrica** | **Fórmula** | **CPU 1** | **CPU 2** | **O que faz / para que serve** |
|---|---|---:|---:|---|
| Speedup do hotspot | `self1 / self2` | — | **2,35x** | Compara o tempo gasto na função crítica entre as duas execuções. |
| Overhead fora do hotspot | `wall − self` | 0,09 s | 0,01 s | Mede quanto do tempo total não está concentrado na função hotspot, incluindo inicialização, chamadas externas e overhead de medição. |

### Análise, hotspot, call graph e estrutura do código

A função **hotspot** identificada é `evolve`, com `self time` de **5,62 s** na CPU 1 e **2,39 s** na CPU 2, representando quase **100,00%** do tempo total de execução em ambas as CPUs.

O **call graph** confirma essa estrutura de forma hierárquica, `main` chama `game` uma única vez, `game` chama `evolve` **2001 vezes** dentro de um laço. Todo o tempo computado em `game` é 100% propagado de `evolve`, pela coluna `children`, enquanto nenhum tempo relevante é atribuído diretamente a `main`.

Isso mostra uma cadeia de chamada linear e simples, sem recursão, sem ciclos e sem múltiplos caminhos de chamada, típica de um programa estruturado em três camadas, inicialização em `main`, orquestração do laço de simulação em `game` e núcleo de cálculo em `evolve`. Como não existem múltiplas funções disputando tempo de CPU no **flat profile**, `evolve` concentra praticamente todo o processamento, enquanto `game` aparece somente como função chamadora, com uma única chamada e sem `self time` relevante.

Esse resultado mostra que a estrutura do código é dominada por um único núcleo computacional. O programa não distribui sua carga de processamento entre várias rotinas, sendo essencialmente um laço de simulação executado **2001 vezes**, com custo de inicialização e controle desprezível. Esse tipo de `flat profile` é característico de aplicações de simulação iterativa, como o **Game of Life**, nas quais uma função central concentra a maior parte do trabalho e as demais funções atuam principalmente na organização da execução.

### Análise de proporção, overhead de instrumentação

O `self time` apresentado pelo `gprof` não corresponde a 100% do `wall-clock` medido pelo `/usr/bin/time`.

Na **CPU 1**, `evolve` responde por **98,42%** do tempo total, considerando **5,62 s de 5,71 s**. Na **CPU 2**, a função responde por **99,58%**, considerando **2,39 s de 2,40 s**.

A diferença corresponde a **0,09 s na CPU 1** e **0,01 s na CPU 2**, representando o tempo associado à inicialização, instrumentação e outras atividades que não são atribuídas diretamente a uma função específica pelo profiler. Dessa forma, os resultados do `gprof` reforçam a conclusão obtida anteriormente, o desempenho da aplicação é determinado quase completamente pela função `evolve`, tornando essa função o principal ponto de interesse para otimizações e paralelização.


# Profiling com `perf stat`

## Dados Coletados

| **Dado** | **CPU 1** | **CPU 2** |
|---|---:|---:|
| Cycles | 21.684.196.173 | 10.089.609.249 |
| Instructions | 27.947.432.505 | 27.897.569.960 |
| IPC | 1,29 | 2,77 |
| Cache-references | 42.957.759 | 147.740 |
| Cache-misses | 2.211.458 | 46.645 |
| Branches | 2.745.341.904 | 2.734.621.544 |
| Branch-misses | 15.732.391 | 11.582.149 |
| L1-dcache-load-misses | 22.761.356 | 20.816.599 |
| LLC-load-misses | não suportado | 3.732 |

### Dados Coletados, Overhead por Função

Obtidos com `perf record -g` e `perf report --stdio`.

| **Função** | **Children CPU 1** | **Self CPU 1** | **Children CPU 2** | **Self CPU 2** |
|---|---:|---:|---:|---:|
| `evolve` | 99,98% | 99,44% | 99,98% | 99,85% |
| `game` | 99,99% | 0,00% | 99,99% | 0,01% |
| `main` | 99,99% | 0,00% | 99,99% | 0,00% |
| `_start / startup da libc` | 99,99% | 0,00% | 99,99% | 0,00% |

## Métricas Derivadas

| **Métrica** | **Fórmula** | **CPU 1** | **CPU 2** | **O que faz / para que serve** |
|---|---|---:|---:|---|
| IPC | `instructions / cycles` | 1,29 | 2,77 | Mede quantas instruções são executadas, em média, por ciclo de clock. |
| Speedup, ciclos | `cyc1 / cyc2` | — | **2,15x** | Compara o número de ciclos de clock consumidos, isolando o ganho de eficiência de hardware da frequência do processador. |
| Taxa de cache-miss | `misses / refs × 100` | 5,15% | 31,58% | Mede a proporção de acessos à cache monitorada pelo evento genérico que resultaram em miss. |
| MPKI, cache | `misses / instr × 1000` | 0,079 | 0,0017 | Mede o número de cache-misses a cada mil instruções executadas, normalizando pelo trabalho útil. |
| Taxa de branch-misprediction | `branch-misses / branches × 100` | 0,57% | 0,42% | Mede a proporção de desvios condicionais previstos incorretamente pelo preditor de branch. |
| MPKI, branch-misses | `branch-misses / instr × 1000` | 0,563 | 0,415 | Mede o número de mispredictions de desvio a cada mil instruções. |
| Branches por instrução | `branches / instr` | 9,82% | 9,80% | Mede a densidade de instruções de desvio dentro do total de instruções executadas. |

## Análise de Execução e Arquitetura

### Overhead por Função, `perf report` vs `gprof`

O `perf report` confirma `evolve` como o principal gargalo da aplicação, concentrando mais de **99,4% do self time** na CPU 1 e **99,85%** na CPU 2.

Ao contrário do `gprof`, que utiliza instrumentação por software e pode introduzir algum overhead durante a execução, o `perf` utiliza contadores de desempenho da própria CPU, reduzindo possíveis distorções na medição do tempo. A correlação do speedup também é consistente entre as ferramentas, o `gprof` registrou aproximadamente **2,35x**, enquanto o `perf` apresentou **2,15x**. Essa pequena diferença é esperada, pois as ferramentas utilizam métodos diferentes para realizar a coleta das métricas.


## Valgrind — Callgrind / Cachegrind

---

### Dados coletados

| **Dado** | **CPU 1** | **CPU 2** |
|---|---:|---:|
| Instruções totais (Callgrind) | 27.867.724.398 | 27.868.099.001 |
| Chamadas: `evolve / game` | 2001 / 1 | 2001 / 1 |
| Acessos L1 (Cachegrind) | 39.850.628.064 | 39.876.906.692 |
| L1 misses | 20.089.847 | 20.077.762 |
| LL misses | 7.819 | 7.815 |

### Dados coletados, `cg_annotate`

Linhas mais custosas de `evolve`, em instruções `Ir`:

| **Linha do código** | **CPU 1 (AMD), Instruções (Ir)** | **% do total, CPU 1** | **CPU 2 (Intel), Instruções (Ir)** | **% do total, CPU 2** |
|---|---:|---:|---:|---:|
| `if (univ[(y1+h)%h][(x1+w)%w])` | 15.847.920.000 | 56,82% | 15.847.920.000 | 56,83% |
| `for (x1 = x-1; x1 <= x+1; x1++)` | 5.522.760.000 | 19,80% | 5.522.760.000 | 19,80% |
| `for (y1 = y-1; y1 <= y+1; y1++)` | 1.840.920.000 | 6,60% | 1.840.920.000 | 6,60% |
| `univ[y][x] = new[y][x]` (cópia de volta) | 1.600.800.000 | 5,74% | 1.600.800.000 | 5,74% |
| `new[y][x] = (n==3 \|\| (n==2 && univ[y][x]))` | 1.349.292.548 | 4,84% | 1.349.482.061 | 4,84% |
| `if (univ[y][x]) n--` | 964.063.129 | 3,46% | 963.969.341 | 3,46% |

### Dados coletados, acessos e misses de dados

| **Métrica** | **CPU 1 (AMD), Valor** | **CPU 1, Taxa** | **CPU 2 (Intel), Valor** | **CPU 2, Taxa** |
|---|---:|---:|---:|---:|
| Data reads (Dr) | 11.418.080.214 | — | 11.426.053.615 | — |
| D1 read misses (D1mr) | 10.111.099 | 0,0886% | 10.105.100 | 0,0884% |
| LL read misses (DLmr) | 78 | 0,00068% (sobre D1mr) | 79 | 0,00078% (sobre D1mr) |
| Data writes (Dw) | 561.190.640 | — | 561.190.640 | — |
| D1 write misses (D1mw) | 9.975.480 | 1,777% | 9.969.474 | 1,7765% |
| LL write misses (DLmw) | 4.824 | 0,0484% (sobre D1mw) | 4.825 | 0,0484% (sobre D1mw) |

### Métricas

| **Métrica** | **Fórmula** | **CPU 1** | **CPU 2** | **O que faz / para que serve** |
|---|---|---:|---:|---|
| Taxa de L1-miss simulada | `L1miss / L1acc × 100` | 0,0504% | 0,0504% | Mede a proporção de acessos simulados à cache L1 que resultam em miss, com base no padrão de acesso à memória do programa. |
| Taxa de LL-miss, local | `LLmiss / L1miss × 100` | 0,0389% | 0,0389% | Mede quantos dos misses de L1 se propagam até o último nível de cache. |
| Instruções por chamada de `evolve` | `instr / 2001` | 13.927.398 | 13.927.586 | Mede a carga de trabalho média executada em cada chamada da função hotspot. |

### Análise, localidade espacial e temporal

O `cg_annotate` mostra que **56,82%** de todas as instruções do programa estão concentradas em uma única linha, `if (univ[(y1+h)%h][(x1+w)%w])`, executada 9 vezes por célula, uma vez para cada vizinho da janela 3x3.

O principal motivo é a operação de módulo (`%`), utilizada para tratar a borda toroidal da matriz. Essa operação é aritmeticamente equivalente a uma divisão inteira, sendo mais custosa em número de ciclos do que operações simples como soma, comparação ou acesso à memória.

Ao mesmo tempo, as taxas de miss de cache são muito baixas, com **D1 read miss de apenas 0,0886%** e **LL miss praticamente nulo**, apenas 78 misses em 11,4 bilhões de leituras.

Isso indica boa **localidade espacial**, pois a janela 3x3 acessa células vizinhas, que tendem a estar na mesma linha de cache ou em linhas adjacentes já carregadas, e boa **localidade temporal**, pois a mesma linha `y` da matriz é revisitada repetidamente pelos laços aninhados, mantendo os dados ativos na L1.

A taxa de `write-miss` é um pouco maior, aproximadamente **1,78%**, o que é esperado, já que cada chamada de `evolve()` utiliza uma nova matriz `new[h][w]` na stack. Assim, as primeiras escritas nessa região podem resultar em misses, pois a memória ainda não está presente na cache.

**Conclusão:** o algoritmo não apresenta um problema significativo de localidade de memória. O principal gargalo está na **computação redundante**, especialmente no cálculo repetido do módulo para tratar a borda toroidal.

Esse resultado é coerente com o IPC relativamente baixo observado no `perf stat`, **1,29 na CPU 1**. Os stalls do pipeline não parecem ser causados principalmente por cache misses, que são raros, mas pela latência da própria operação de divisão/módulo e pelas dependências de dados envolvidas no cálculo dos índices.

### Análise de proporção, validação cruzada `perf` × Valgrind

| **Verificação cruzada** | **CPU 1** | **CPU 2** |
|---|---:|---:|
| Divergência, instructions (`perf`) × `Ir` (Callgrind) | 0,29% | 0,11% |
| Divergência, `L1-dcache-load-misses` (`perf`) × D1 miss (Cachegrind) | 13,3% | 3,7% |
| Taxa de miss L1 (Cachegrind) | 0,0504% | 0,0503% |
| Misses no último nível por geração (`LL ÷ 2001` chamadas) | 3,91 | 3,91 |

A contagem de instruções diverge menos de **0,3%** entre `perf` e Callgrind nas duas CPUs, o que representa uma forte validação cruzada, considerando que uma ferramenta utiliza amostragem de hardware, enquanto a outra realiza uma simulação determinística das instruções executadas.

Observa-se, entretanto, uma aparente inconsistência ao comparar as métricas de cache geradas pelo `perf stat` e pelo Cachegrind entre as duas arquiteturas avaliadas.

### 1. Natureza determinística do Cachegrind

O Cachegrind não coleta métricas diretamente do hardware real. Ele funciona como um simulador em nível de software, avaliando o comportamento de uma cache idealizada e genérica com base no padrão de acesso à memória determinado pelo código-fonte, neste caso, o algoritmo do Game of Life.

Como as duas execuções processam o mesmo algoritmo, com o mesmo padrão de acesso à memória, a simulação naturalmente produz números muito próximos ou iguais. Isso evidencia que a carga de trabalho do software permaneceu inalterada.

### 2. Ambiguidade dos eventos genéricos no `perf`

A divergência observada pelo `perf stat` está relacionada à forma como a ferramenta mapeia eventos genéricos. A CPU 1 e a CPU 2 possuem microarquiteturas e PMUs, Performance Monitoring Units, diferentes.

Quando um evento genérico, como `cache-references`, é solicitado, o driver de cada processador seleciona internamente o contador físico que melhor representa essa definição para aquela arquitetura específica. Em arquiteturas diferentes, essa métrica abstrata pode ser mapeada para níveis distintos da hierarquia de cache, por exemplo, L2 em uma máquina, L3 ou LLC em outra. Assim, embora o rótulo da medição, `cache-references`, permaneça igual para o usuário, o hardware efetivamente avaliado não é necessariamente equivalente. Por isso, essa métrica deve ser utilizada com cautela em comparações entre arquiteturas diferentes.

### Comprovação empírica

Para verificar se o desvio decorre dessa abstração da PMU, e não de um problema no hardware, pode-se avaliar um evento mais específico e arquiteturalmente delimitado, `L1-dcache-load-misses`.

| **Ferramenta / Métrica** | **CPU 1** | **CPU 2** |
|---|---:|---:|
| `perf stat`, `L1-dcache-load-misses` | 22.761.356 | 20.816.599 |
| Cachegrind, L1 misses | 20.089.847 | 20.077.762 |

Os resultados mostram que, apesar da diferença entre as medições realizadas diretamente pelo `perf` e as simulações do Cachegrind, os valores permanecem na mesma ordem de grandeza. Isso reforça a conclusão de que o padrão de acesso à memória do algoritmo é semelhante nas duas arquiteturas, enquanto parte das diferenças observadas está relacionada à forma como cada ferramenta obtém e interpreta as métricas de hardware.
## 5. Rastreamento com `strace`
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| 1ª Syscall mais frequente | execve (65,38%) | execve (57,91%) |
| 2ª Syscall mais frequente | mmap (11,81%) | mmap (16,12%) |
| 3ª Syscall mais frequente | mprotect (4,18%) | mprotect (6,27%) |
| Tempo total despendido em modo kernel | 0,000982 s (982 µs) |      0,000670 s (670 µs) |

O programa possui comportamento exclusivo em User Space (Modo Usuário).

A classificação é confirmada por:

Syscalls de Inicialização: As chamadas mais frequentes (execve, mmap, mprotect) ocorrem apenas durante o carregamento do binário e bibliotecas, sem chamadas de I/O (leitura/escrita) durante o processamento.

Tempo em Kernel Irrelevante: O tempo despendido em modo kernel é inferior a 1 milissegundo. O programa processa a lógica do jogo de forma isolada, sem interrupções ou necessidade de serviços do sistema operacional após o início da execução.

**Análise de Proporção — Tempo em Kernel como Fração do Total**

Normalizando o tempo em modo kernel pelo wall-clock total de cada execução: CPU 1 gasta 0,0172% do tempo em kernel (982 µs de 5,71 s); CPU 2 gasta 0,0279% (670 µs de 2,40 s). Embora o valor absoluto seja menor na CPU 2, a fração relativa é proporcionalmente maior — natural, já que o tempo de inicialização do processo (onde essas syscalls ocorrem) é praticamente fixo, independente da duração da carga de trabalho, então quanto mais rápida a execução, maior o peso relativo da inicialização no total.

# Diagnóstico e análise crítica sobre qual ferramenta foi mais útil para o diagnóstico

Cada ferramenta respondeu a uma pergunta diferente; nenhuma isolada bastaria.

/usr/bin/time deu o panorama inicial — confirmou CPU-bound (User ≈ Wall-clock, System ≈ 0) e descartou problemas de memória e I/O. Indispensável como ponto de partida, mas não diz onde no código o tempo é gasto.

gprof respondeu com mais clareza "onde otimizar": isolou evolve como responsável por 100% do tempo de CPU nas duas máquinas. Limitações: exige recompilar com -pg (overhead que pode distorcer tempos absolutos de funções pequenas) e não explica por que a função custa o que custa em hardware.

perf stat foi a mais útil para explicar "por quê", sem alterar o binário nem introduzir overhead relevante. Foi a única a revelar a causa real da diferença entre as CPUs — não o volume de trabalho (instruções quase idênticas), mas o IPC (1,29 vs. 2,77) — e a confirmar taxas mínimas de branch-miss e cache-miss em L1. Também expôs uma armadilha: métricas genéricas de cache não são portáveis entre vendors. perf record -g complementou com o call graph sem o overhead pesado do Valgrind.

Valgrind (Callgrind/Cachegrind) foi a mais precisa e determinística: seus números validaram de forma independente os resultados do perf (divergência < 0,3%). Melhor opção para contagens exatas e reprodutíveis, mas com overhead de execução altíssimo, inadequada para medir tempo real.

strace foi a menos útil para diagnóstico de desempenho aqui: confirmou ausência de syscalls relevantes na simulação — uma confirmação negativa, que diz o que não é o gargalo, sem apontar onde otimizar o cálculo.

Conclusão: a combinação mais eficiente foi gprof + perf stat — o primeiro localizou o hotspot (evolve) de forma direta e barata, o segundo explicou o comportamento de hardware por trás desse custo (CPU-bound, alta localidade de cache, poucos branch-misses, e a real causa da diferença entre as CPUs testadas: IPC, não volume de instruções). O Valgrind agregou valor como validação cruzada determinística, e o strace serviu só para descartar gargalo em I/O/sistema. Nenhuma ferramenta isolada permitiria concluir, ao mesmo tempo, onde, por quê e com que confiabilidade o programa se comporta como se comporta.

## Código de referencia: https://rosettacode.org/wiki/Conway%27s_Game_of_Life
