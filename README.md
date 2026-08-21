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

O código fonte foi estruturado para receber quatro parâmetros numéricos via linha de comando: a largura da placa, a altura da placa, o número máximo de iterações e a frequência de salvamento das iterações (parâmetro XX). 

O formato de execução padrão segue a estrutura:
`./gol [largura] [altura] [max_iter] [print_freq]`

* **Exemplo de execução:** `./gol 1000 1000 500 50`

Para satisfazer os critérios do experimento, os parâmetros de entrada (dimensões da matriz e número de iterações) devem ser grandes o suficiente para que o programa processe um volume de dados adequado, garantindo que o tempo de execução alcance pelo menos 2 segundos em *wall-clock time* utilizando a compilação base.

Durante a coleta de métricas, a execução do binário foi encapsulada pelas ferramentas de profiling exigidas. Utilizando o exemplo de parâmetros acima, os comandos executados foram:

* **Medição de tempo total e recursos:** `/usr/bin/time -v ./gol 1000 1000 500 50`
* **Contagem de eventos de hardware:** `perf stat ./gol 1000 1000 500 50`
* **Gravação do overhead por função:** `perf record -g ./gol 1000 1000 500 50`
* **Simulação de instruções de CPU:** `valgrind --tool=callgrind ./gol 1000 1000 500 50`
* **Simulação de acessos e misses de memória L1/L2:** `valgrind --tool=cachegrind ./gol 1000 1000 500 50`
* **Rastreamento de chamadas de sistema:** `strace -c ./gol 1000 1000 500 50`
  
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
* **Memória Cache:** L1: 320 / L2: 5MB / L3: 8MB 
* **Memória RAM:** 12 GB DDR4
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

## 2. Profiling com `gprof`
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Função hotspot (maior self time) | `evolve` |  `evolve` |
| Tempo gasto na função hotspot (Self time) | 5.62 s |      2.39 s |
| Percentual de impacto no tempo total | 100.00% |      100.00% |

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

## 4. Profiling com Valgrind (Callgrind e Cachegrind)
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| Número exato de instruções (Callgrind) | 27.867.724.398 (total) | 27.868.099.001 (total) |
| Chamadas por função (Callgrind) | evolve: 2001 chamadas / game: 1 chamada |    evolve: 2001 chamadas / game: 1 chamada |
| Acessos de memória L1 e L2 (Cachegrind) | L1: 39.850.628.064 | L1: 39.876.906.692 |
| Misses de memória L1 e L2 (Cachegrind) | L1 miss: 20.089.847 / LL miss: 7.819 | L1 miss: 20.077.762 / LL miss: 7.815|

## 5. Rastreamento com `strace`
| Métrica | CPU 1 | CPU 2 |
| :--- | :--- | :--- |
| 1ª Syscall mais frequente | execve (65,38%) | execve (57,91%) |
| 2ª Syscall mais frequente | mmap (11,81%) | mmap (16,12%) |
| 3ª Syscall mais frequente | mprotect (4,18%) | mprotect (6,27%) |
| Tempo total despendido em modo kernel | 0,000982 s (982 µs) |      0,000670 s (670 µs) |

# Diagnóstico e análise crítica sobre qual ferramenta foi mais útil para o diagnóstico
## Código de referencia: https://rosettacode.org/wiki/Conway%27s_Game_of_Life
