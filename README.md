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

## 1. Medição de Tempo (`/usr/bin/time`)
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Wall-clock time | 0:05.71 (5.71 s) |      0:02.40 (2.40 s) |
| User time | 5.70 s |      2.40 s |
| System time | 0.00 s |      0.00 s |
| Maximum RSS (uso de memória) | 2056 KB | 2220 KB |
| Page faults | 157 (Minor) / 0 (Major) |  157 (Minor) / 0 (Major) |
| Context switches | 48 (1 vol / 47 invol) |      26 (1 vol / 25 invol) |

O tempo gasto processando cálculos (User time) é praticamente igual ao tempo total de execução (Wall-clock time). Na CPU 1 (5.70s de 5.71s) e na CPU 2 (2.40s de 2.40s), o processador foi utilizado em quase 100% do tempo.

**Análise de Proporção — Speedup entre CPUs**

A CPU 2 executa a carga completa **2,38× mais rápido** que a CPU 1 (5,71 s ÷ 2,40 s), com a mesma proporção refletida no user time (5,70 s ÷ 2,40 s = 2,38×). Esse ganho será decomposto na seção de `perf stat` em seus dois componentes reais: eficiência por ciclo (IPC) e frequência de clock.

## 2. Profiling com `gprof`
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Função hotspot (maior self time) | `evolve` |  `evolve` |
| Tempo gasto na função hotspot (Self time) | 5.62 s |      2.39 s |
| Percentual de impacto no tempo total | 100.00% |      100.00% |

Função Hotspot: A função evolve é o hotspot absoluto do programa.

Percentual de Impacto: Ela é responsável por 100.00% do tempo total de execução em ambas as CPUs.

**Análise de Proporção — Overhead de Instrumentação**

O self time do gprof não cobre 100% do wall-clock medido pelo `/usr/bin/time`: na CPU 1, `evolve` responde por 98,42% do tempo total (5,62 s de 5,71 s); na CPU 2, por 99,58% (2,39 s de 2,40 s). A diferença — 0,09 s na CPU 1 e 0,01 s na CPU 2 — corresponde a overhead de inicialização e instrumentação não atribuído a nenhuma função específica pelo profiler, sendo proporcionalmente maior na CPU 1 por seu tempo total de execução ser maior.

## 3. Profiling de Hardware (`perf stat`)
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Cycles | 21.684.196.173 | 10.089.609.249 |
| Instructions | 27.947.432.505 |      27.897.569.960 |
| IPC (Instruções por Ciclo) | 1,29 | 2,77 |
| Cache-references | 42.957.759 | 147.740 |
| Cache-misses | 2.211.458 |      46.645 |
| Branches | 2.745.341.904 | 2.734.621.544 |
| Branch-misses | 15.732.391 | 11.582.149 |
| L1-dcache-load-misses | 22.761.356 | 20.816.599 |
| LLC-load-misses | Não suportado | 3.732 |

gprof (Instrumentação): Insere código no binário para rastrear funções. Gera overhead e altera o tempo real, mas é ideal para achar o gargalo lógico (a função evolve).

perf (Amostragem): Lê contadores do hardware sem modificar o código. Fornece dados reais e exatos de como o processador lida com a execução.

Avaliação do IPC (Instruções por Ciclo): Ambas processam ~27,9 bilhões de instruções, mas a CPU 2 (IPC 2,77) é muito mais eficiente que a CPU 1 (IPC 1,29). A CPU 2 consegue resolver mais do dobro de instruções no mesmo pulso de clock (melhor paralelismo interno do processador).

Branches: A taxa de falha de predição (branch-misses) é de apenas ~0,5%. O processador quase nunca erra o caminho dos laços for e ifs.

Cache: O erro de L1 é mínimo. O mais importante é o registro de apenas 3.732 LLC-load-misses na CPU 2, o que prova que os dados (as matrizes) cabem inteiramente no Cache L3. O processador não perde tempo buscando dados na Memória RAM, confirmando a alta localidade de dados e o comportamento estritamente CPU-bound.

**Análise de Proporção — Decomposição do Speedup (IPC × Frequência)**

O ganho de 2,38× no tempo de execução não vem de menos trabalho: o volume de instruções é praticamente idêntico entre as CPUs (diferença de apenas 0,18%). Ele se decompõe em dois fatores multiplicativos:
- **Ganho de IPC:** 2,77 ÷ 1,29 = **2,15×** mais instruções resolvidas por ciclo na CPU 2.
- **Ganho de frequência efetiva:** calculando `ciclos ÷ user time`, a CPU 1 operou a ~3,80 GHz e a CPU 2 a ~4,20 GHz — um ganho de **1,11×**.
- **Produto dos dois fatores:** 2,15 × 1,11 = **2,37×**, praticamente idêntico ao speedup real observado (2,38×). Isso confirma que a diferença de desempenho é explicada quase inteiramente por arquitetura (IPC) e clock, não por trabalho computacional distinto.

**Análise de Proporção — Cache-miss Rate não é Portável entre Fabricantes**

| Métrica (taxa) | CPU 1 (AMD) | CPU 2 (Intel) |
| :--- | :--- | :--- |
| Cache-miss rate (misses/references) | 5,15% | 31,57% |
| Branch-miss rate (misses/branches) | 0,57% | 0,42% |
| L1-dcache-miss por instrução | 0,0814% | 0,0746% |

À primeira vista, a taxa de cache-miss da CPU 2 parece 6× pior que a da CPU 1. Essa diferença **não reflete o comportamento real do algoritmo** — é um artefato de como o `perf` mapeia os nomes genéricos `cache-references`/`cache-misses` para os contadores físicos de PMU de cada fabricante. AMD e Intel não implementam os mesmos registradores de hardware nem organizam a hierarquia de cache da mesma forma, então o perf escolhe, por baixo dos panos, eventos fisicamente diferentes em cada arquitetura para responder por esse mesmo nome genérico. Isso fica evidente no volume absoluto: a CPU 2 registrou 291× menos `cache-references` (147.740 vs. 42.957.759) — sinal de que o evento capturado ali provavelmente corresponde a um nível de cache mais profundo (perto do LLC) do que na CPU 1, não porque a CPU 2 acessa a memória 291× menos.

A métrica confiável para comparar as duas CPUs é o **L1-dcache-load-misses relativo às instruções executadas** — um evento com definição mais padronizada entre arquiteturas — que se mantém baixo e consistente em ambas (~0,08%), confirmando que o padrão real de acesso à memória do algoritmo independe do hardware.

## 4. Profiling com Valgrind (Callgrind e Cachegrind)
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Número exato de instruções (Callgrind) | 27.867.724.398 (total) | 27.868.099.001 (total) |
| Chamadas por função (Callgrind) | evolve: 2001 chamadas / game: 1 chamada |    evolve: 2001 chamadas / game: 1 chamada |
| Acessos de memória L1 e L2 (Cachegrind) | L1: 39.850.628.064 | L1: 39.876.906.692 |
| Misses de memória L1 e L2 (Cachegrind) | L1 miss: 20.089.847 / LL miss: 7.819 | L1 miss: 20.077.762 / LL miss: 7.815|

Localidade Espacial (Acesso Sequencial): A taxa de falha no Cache L1 é mínima, de apenas ~0,05% (20 milhões de misses em quase 40 bilhões de acessos). O processador aproveita os dados carregados nos blocos do cache (cache lines) sem desperdício.

Localidade Temporal (Reuso de Dados): Houve apenas ~7.800 falhas no Último Nível (LL misses) durante todas as 2001 chamadas de evolve. Isso comprova que as matrizes do jogo cabem perfeitamente no cache do processador e são reutilizadas iterativamente, praticamente eliminando a necessidade de buscar dados na lenta Memória RAM.

**Análise de Proporção — Validação Cruzada perf vs. Valgrind**

| Verificação cruzada | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Divergência instructions (perf) × Ir (Callgrind) | 0,29% | 0,11% |
| Divergência L1-dcache-load-misses (perf) × D1 miss (Cachegrind) | 13,3% | 3,7% |
| Taxa de miss L1 (Cachegrind) | 0,0504% | 0,0503% |
| Misses no último nível por geração (LL ÷ 2001 chamadas) | 3,91 | 3,91 |

A contagem de instruções diverge menos de 0,3% entre `perf` e Callgrind em ambas as CPUs — validação forte, já que uma ferramenta mede por amostragem de hardware e a outra por simulação determinística de cada instrução executada.

Já a divergência nos misses de cache (13,3% na CPU 1; 3,7% na CPU 2) tem uma causa **diferente** da discrepância discutida no item 3: ali o problema era portabilidade de um evento genérico entre fabricantes; aqui, é a distinção entre **medir hardware real** e **simular um modelo idealizado**. O `perf` lê contadores físicos da CPU, que refletem todo o comportamento real do silício — incluindo o *prefetcher* de hardware, que antecipa e pré-carrega dados de acessos sequenciais (como a varredura da matriz do Game of Life), reduzindo misses reais. O Cachegrind, por sua vez, não usa hardware algum: ele simula, em software, um modelo de cache simplificado (tipicamente LRU puro, sem os mecanismos proprietários de prefetching de cada fabricante). A divergência não é igual nas duas CPUs porque o Cachegrind tenta calibrar automaticamente sua simulação com base na geometria de cache detectada via CPUID — e o quão bem esse modelo genérico se aproxima do comportamento real varia conforme as peculiaridades de cada microarquitetura (AMD Zen vs. Intel Tiger Lake implementam prefetching e associatividade de forma distinta).

Nenhum dos dois valores é "o errado" — são dois métodos válidos medindo fenômenos diferentes (silício real vs. modelo idealizado). O que valida a conclusão de alta localidade de memória não é a concordância exata entre os números, mas a concordância na **ordem de grandeza**: ambas as ferramentas, por caminhos independentes, apontam taxas de miss muito baixas.

A taxa de miss em L1 do Cachegrind, por sua vez, é praticamente **idêntica** entre as CPUs (0,0504% vs. 0,0503%) — evidência de que, como o Cachegrind simula um cache genérico (não o cache real de cada CPU), o padrão de acesso à memória capturado ali é determinado pela estrutura do código-fonte, não pelo hardware onde roda.

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
