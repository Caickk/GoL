# 1. Profiling em CPU: Game of Life

## 1.1 Discentes

- [Camila De Araújo Bastos](https://github.com/camilaab)
- [Caick Wendell Lopes dos Santos](https://github.com/caickkk)
# 2. Descrição do algoritmo

O código implementa uma versão serial do **Conway's Game of Life (Jogo da Vida)**, um autômato celular criado pelo matemático John Horton Conway. O algoritmo simula a evolução de uma grade bidimensional de células (vivas ou mortas) ao longo de sucessivas gerações, baseando-se no estado da vizinhança imediata (as 8 células ao redor) de cada posição.

### 2.1 Regras do Jogo
A transição de uma geração para a seguinte ocorre de forma simultânea para todo o tabuleiro, seguindo quatro regras matemáticas estritas:
1. **Subpopulação:** Uma célula viva com menos de dois vizinhos vivos morre.
2. **Sobrevivência:** Uma célula viva com dois ou três vizinhos vivos permanece viva na próxima geração.
3. **Superpopulação:** Uma célula viva com mais de três vizinhos vivos morre.
4. **Reprodução:** Uma célula morta com exatamente três vizinhos vivos se torna uma célula viva.

### 2.2 Arquitetura da Implementação
Para atender a essas regras computacionalmente, a arquitetura do algoritmo foi estruturada da seguinte forma:

*   **Estrutura de Dados (Matrizes de Estado):** O programa utiliza duas matrizes bidimensionais na memória. A matriz original (`univ`) representa a geração atual, enquanto uma matriz temporária (`new`) armazena a próxima geração. Isso garante que as atualizações ocorram de forma síncrona, evitando que o nascimento ou morte de uma célula afete o cálculo de suas vizinhas no mesmo ciclo.
*   **Topologia do Universo (Matriz Toroidal):** As regras assumem uma grade infinita. Para simular isso na memória RAM sem causar falhas de acesso (*segmentation fault*), o algoritmo adota uma topologia toroidal. Usando a operação de módulo (`%`), as bordas da matriz se conectam: a borda direita encosta na esquerda, e a inferior na superior.
*   **Lógica de Transição (Hotspot):** A função `evolve` é o núcleo do processamento. Nela, as quatro regras clássicas descritas acima foram otimizadas e condensadas em uma única expressão booleana eficiente para a CPU: `new[y][x] = (n == 3 || (n == 2 && univ[y][x]));`.

# 3. Compilação e Execução das 5 Versões

Para atender aos requisitos de paralelismo e profiling, foram implementadas cinco versões do algoritmo. 

**Parâmetros base da simulação:** Matriz de 500×500 células processada por 5.000 iterações (totalizando ~11,25 bilhões de verificações de vizinhos).

### 3.1 C Serial
Implementação nativa de referência, sem diretivas de paralelização.
* **Compilação:** `gcc -O2 -g -o programa_serial programa_serial.c`
* **Execução (Exemplo perf):** `perf stat ./programa_serial`

### 3.2 C Paralelo com OpenMP
Paralelização via divisão do loop principal usando diretivas de memória compartilhada.
* **Compilação:** `gcc -O2 -g -fopenmp -o programa_openmp programa_openmp.c`
* **Controle de Threads:** Variável de ambiente `OMP_NUM_THREADS` (1, 2, 4 e 8).

### 3.3 Python Serial
Implementação pura em Python, sem bibliotecas externas (como NumPy), utilizando apenas estruturas nativas.
* **Execução:** `python3 programa_serial.py`

### 3.4 Python Paralelo com Multithreading
Distribuição de chunks da matriz entre threads usando o módulo `threading` do Python.
* **Execução:** `python3 programa_thread.py`

### 3.5 Python Paralelo com Multiprocessing
Contorno do Global Interpreter Lock (GIL) através da criação de processos independentes via módulo `multiprocessing` (Pipe e Shared Memory)[cite: 5, 6, 8].
* **Execução:** `python3 programa_multiprocess.py`

---
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
  
# 4. Tabelas de resultados do time, gprof, perf, Valgrind e strace

Abaixo estão os resultados extraídos de cada ferramenta de profiling em dois ambientes de hardware distintos, seguindo os parâmetros definidos na especificação do projeto.

## 4.1 Especificações dos Ambientes de Teste

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

# 5. Tabelas de Profiling Detalhado por Ferramenta e Versão

As tabelas a seguir detalham as métricas extraídas pelas ferramentas de profiling, categorizadas explicitamente pela versão do algoritmo (C Serial, C OpenMP, Python Serial, etc.) e separadas por arquitetura de hardware (CPU 1 e CPU 2).

## 5.1 Medição de Tempo e Recursos (`/usr/bin/time -v`)
Monitoramento do consumo de tempo e memória gerido pelo sistema operacional.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Wall-clock time (real) | 0:49.44 | 22.10s |
| **C Serial** | User time (CPU) | 49.43s | 22.08s |
| **C Serial** | System time | 0.00s | 0.00s |
| **C Serial** | Percentual de CPU | 99% | 99% |
| **C Serial** | Max RSS (KB) | 3.724 | 3.960 |
| **C Serial** | Context switches (vol/invol) | 1 / 565 | 1 / 709 |
| **C OpenMP (4 Threads)** | Wall-clock time | 0:13.15 | 7.90s |
| **C OpenMP (4 Threads)** | User time | 52.61s | 31.60s |
| **C OpenMP (4 Threads)** | Percentual de CPU | 399% | 399% |
| **C OpenMP (4 Threads)** | Max RSS (KB) | 4.144 | 4.252 |
| **Python Serial** | Wall-clock time | 20:56.63 | 24m 33s |
| **Python Serial** | User time | 1251.39s | ~1473s |
| **Python Serial** | Max RSS (KB) | 13.868 | ~19.000 |
| **Python Serial** | Context switches (vol/invol) | 1 / 14.948 | 1 / 10.048 |
| **Python Thread (8 Threads)** | Wall-clock time | 22:21.28 | 19m 56s |
| **Python Thread (8 Threads)** | Context switches (vol/invol) | 2.06M / 20k | 1.73M / 13.184 |
| **Python MP Pipe (4 Proc.)** | Wall-clock time | 3:18.89 | 4m 59s |
| **Python MP Pipe (4 Proc.)** | Max RSS (KB) | 19.084 | 19.140 |
| **Python MP SHM (4 Proc.)** | Wall-clock time | 4:18.25 | 5m 30s |
| **Python MP SHM (4 Proc.)** | Max RSS (KB) | 20.324 | 20.312 |

## 5.2 Rastreamento de Chamadas (`gprof` e `cProfile`)
Identificação do hotspot e tempo cumulativo das funções críticas na arquitetura.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** (`gprof`) | Função Hotspot | | `evolve` |
| **C Serial** (`gprof`) | % do tempo total | | 100.00% |
| **Python Serial** (`cProfile`) | Função Hotspot | | `evolve` |
| **Python Serial** (`cProfile`) | % do tempo total | | 99.9% |
| **Python Thread (8 Threads)** | Maior Overhead de Sistema | | `Thread.join` e `acquire` |
| **Python MP Pipe (4 Proc.)** | Maior Overhead de Sistema | | `posix.read` / `recv` |

## 5.3 Contadores de Desempenho Físico (`perf stat`)
Métricas em nível de hardware, evidenciando o impacto da linguagem compilada vs interpretada.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Cycles (Ciclos Totais) | 212,6 Bilhões | 91,36 Bilhões |
| **C Serial** | Instructions (Instruções) | 161,2 Bilhões | 160,94 Bilhões |
| **C Serial** | IPC (Instructions Per Cycle) | 0,76 | 1,76 |
| **C Serial** | Cache-misses | 95,7 Milhões | 322 Milhões (L1) |
| **C Serial** | Branch-misses | 57,0 Milhões | 0,25% (Taxa) |
| **Python Serial** | Cycles (Ciclos Totais) | 5,3 Trilhões | 10.089.609.249 |
| **Python Serial** | Instructions (Instruções) | 17,5 Trilhões |27.897.569.960 |
| **Python Serial** | IPC (Instructions Per Cycle) | 3,30 | 2,77|
| **Python Serial** | Cache-misses | 342,5 Milhões | 46.645|
| **Python Serial** | Branch-misses | 7,8 Bilhões | 11.582.149|

## 5.4 Simulação de Memória e Instruções (`Valgrind`)
Validação cruzada com instrumentação determinística para a versão **C Serial**.

| Versão do Programa | Ferramenta / Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Callgrind: Total de Instruções (Ir) | | 162.290.210.118 |
| **C Serial** | Cachegrind: Leitura de Dados (Dr) | | 11.426.810.980 |
| **C Serial** | Cachegrind: Misses L1 (D1mr) | | 10.106.438 |
| **C Serial** | Cachegrind: Misses Último Nível (DLmr) | | 1.187 |

## 5.5 Chamadas de Sistema (`strace`)
Mapeamento da comunicação entre o código do usuário e o Kernel do Sistema Operacional.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Total de Syscalls | | 34 chamadas |
| **C Serial** | Syscall dominante | | `execve` |
| **Python Serial** | Total de Syscalls | | 80.446 chamadas |
| **Python Serial** | Syscall dominante | | `brk` |

## 5.6 Código de referencia: https://rosettacode.org/wiki/Conway%27s_Game_of_Life
