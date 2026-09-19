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

# 3. Metodologia, Compilação e Execução das 5 Versões

Para avaliar o impacto das estratégias de paralelização, foram implementadas cinco versões do algoritmo partindo da mesma condição inicial e topologia toroidal. A matriz base processada é de 500×500 células ao longo de 5.000 iterações (totalizando ~11,25 bilhões de verificações de vizinhos).

### 3.1 C Serial
Base de referência de mais baixo nível, sem diretivas de paralelismo. Utiliza matrizes alocadas na pilha e laços aninhados simples, aplicando *double buffering* explícito. Apenas a contagem final isolada utiliza uma redução OpenMP.
* **Compilação:** `gcc -O2 -g -o programa_serial programa_serial.c`
* **Execução (Exemplo perf):** `perf stat ./programa_serial`

### 3.2 C Paralelo com OpenMP
Paraleliza a fase de evolução aplicando a diretiva `#pragma omp parallel for` ao laço externo, particionando a matriz por colunas. O *runtime* gere as *threads* e as barreiras implícitas de sincronização, sem causar condições de corrida na escrita.
* **Compilação:** `gcc -O2 -g -fopenmp -o programa_openmp programa_openmp.c`
* **Controle de Threads:** Variável de ambiente `OMP_NUM_THREADS` (1, 2, 4 e 8).

### 3.3 Python Serial
Base de corretude interpretada, utilizando apenas estruturas nativas. É a tradução literal da versão em C, varrendo a matriz célula a célula e atualizando estados sequencialmente.
* **Execução:** `python3 programa_serial.py`

### 3.4 Python Paralelo com Multithreading
Usa um `ThreadPoolExecutor` para decompor a matriz em colunas. Partilha o mesmo espaço de memória (evitando troca de mensagens), mas sincroniza cálculo e cópia em duas fases. A concorrência sofre forte impacto do *Global Interpreter Lock* (GIL).
* **Execução:** `python3 programa_thread.py`

### 3.5 Python Paralelo com Multiprocessing
Contorna o GIL alocando múltiplos interpretadores independentes (processos):
*   **Via Pipe:** Cada processo mantém apenas o seu próprio bloco de colunas. A comunicação de bordas ("colunas fantasma") exige envios constantes através de *Pipes* bidirecionais, causando alto custo de serialização de dados (*pickling*).
*   **Via Shared Memory:** Substitui os *Pipes* por leitura direta num único bloco global de memória RAM partilhada. Elimina o *pickling*, mas exige barreiras rigorosas de sistema operativo (`multiprocessing.Barrier`) para orquestrar a troca de gerações.
* **Execução:** `python3 programa_multiprocess.py`

---
Durante a recolha de métricas, a execução dos binários foi encapsulada pelas seguintes ferramentas e comandos:
* **Medição de tempo total e recursos:** `/usr/bin/time -v ./gol`
* **Contagem de eventos de hardware:** `perf stat ./gol`
* **Gravação do overhead por função:** `perf record -g ./gol`
* **Leitura do relatório de overhead do perf:** `perf report --stdio`
* **Simulação de instruções de CPU:** `valgrind --tool=callgrind ./gol`
* **Simulação de acessos e misses de memória L1/L2:** `valgrind --tool=cachegrind ./gol`
* **Anotação dos resultados do Cachegrind:** `cg_annotate cachegrind.out.<PID>`
* **Rastreamento de chamadas de sistema:** `strace -c ./gol`
  
# 4. Especificações dos Ambientes de Teste

**Ambiente 1 (CPU 1)**
* **Processador:** AMD Ryzen 5 7520U (4 Núcleos / 8 Threads)
* **Memória Cache:** L1: 128 KiB / L2: 2 MiB / L3: 4 MiB
* **Memória RAM:** 16 GB (2x 8GB) LPDDR5 Samsung @ 5500 MT/s (Dual-Channel)
* **SO / Kernel:** Ubuntu 26 / Linux 7.0.0-27-generic

**Ambiente 2 (CPU 2)**
* **Processador:** Intel® Core™ i5-1135G7 (4 Núcleos / 8 Threads)
* **Memória Cache:** L1: 320 KiB / L2: 5MB / L3: 8MB
* **Memória RAM:** 12 GB DDR4
* **SO / Kernel:** Ubuntu 26.04 / Linux 7.0.0-29-generic

# 5. Tabelas de Profiling Detalhado por Ferramenta e Versão

## 5.1 Medição de Tempo e Recursos (`/usr/bin/time -v`)

Avaliação do tempo real de execução (Wall-clock), tempo de CPU em modo utilizador, consumo máximo de memória residente (Max RSS) e trocas de contexto impostas pelo sistema operativo para cada estratégia.

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

**Constatação sobre Microarquitetura (AMD vs. Intel):** Apesar da mesma configuração lógica (4C/8T), a disparidade nos barramentos de cache afeta drasticamente o desempenho sob estresse. A CPU 2 (Intel) lida notavelmente melhor com a fragmentação de memória gerada pelas múltiplas *threads* do OpenMP e processos, pois possui capacidades maiores desde a base (L1 de 320 KB e L3 de 8 MB). Ela acomoda os blocos fragmentados com folga antes de recorrer a níveis mais lentos, sustentando um ganho de eficiência paralela muito superior ao do chip da AMD sob carga intensiva.

**Conclusão sobre Concorrência (OpenMP vs. Python):** O paralelismo nativo em C (OpenMP) introduz um overhead quase nulo de gestão, revertendo \~96% do tempo da CPU diretamente para os cálculos úteis. No outro extremo, a abordagem Multithreading do Python evidencia o estrangulamento causado pelo GIL: as *threads* entram num ciclo ocioso disputando o interpretador, o que faz os *Context Switches* voluntários saltarem para mais de 1,7 milhão (esgotando recursos à toa). Escapar via *Multiprocessing* resolve o bloqueio de CPU, mas transfere o gargalo para a infraestrutura do SO (custos excessivos de cópia no Pipe ou *locks* caros de controlo na Memória Partilhada).

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

Levantamento de eventos microarquiteturais da CPU, detalhando ciclos totais, instruções efetivamente processadas, vazão (IPC), faltas na cache L1 e erros de previsão de saltos.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Cycles (Ciclos Totais) | 212,6 Bilhões | 91,36 Bilhões |
| **C Serial** | Instructions (Instruções) | 161,2 Bilhões | 160,94 Bilhões |
| **C Serial** | IPC (Instructions Per Cycle) | 0,76 | 1,76 |
| **C Serial** | Cache-misses | 95,7 Milhões | 322 Milhões (L1) |
| **C Serial** | Branch-misses | 57,0 Milhões | 0,25% (Taxa) |
| **Python Serial** | Cycles (Ciclos Totais) | 5,3 Trilhões | 10.089.609.249 |
| **Python Serial** | Instructions (Instruções) | 17,5 Trilhões | 27.897.569.960 |
| **Python Serial** | IPC (Instructions Per Cycle) | 3,30 | 2,77 |
| **Python Serial** | Cache-misses | 342,5 Milhões | 46.645 |
| **Python Serial** | Branch-misses | 7,8 Bilhões | 11.582.149 |

**Observação sobre a Ilusão do IPC em Python:** A métrica de IPC no script Python (ex: 3,30) exibe uma capacidade espantosa da CPU em limpar as esteiras de instruções. No entanto, esse IPC massivo esconde um grande gargalo de eficiência: o processador está a operar freneticamente apenas para lidar com o *overhead* do próprio interpretador CPython (tipagem dinâmica, recolha de lixo, varreduras do GIL). A execução consome impressionantes \~17,5 trilhões de instruções artificiais que não agregam valor algorítmico face aos enxutos 161 bilhões do binário nativo em C.

## 5.4 Simulação de Memória e Instruções (`Valgrind`)

Contagem exata de instruções simuladas e rastreamento da hierarquia de memória para identificar perdas de localidade na cache L1 e no último nível (LLC).

| Versão do Programa | Ferramenta / Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Callgrind: Total de Instruções (Ir) | | 162.290.210.118 |
| **C Serial** | Cachegrind: Leitura de Dados (Dr) | | 11.426.810.980 |
| **C Serial** | Cachegrind: Misses L1 (D1mr) | | 10.106.438 |
| **C Serial** | Cachegrind: Misses Último Nível (DLmr) | | 1.187 |

**Análise sobre o Volume de Dados e Localidade de Cache:** O dimensionamento do problema (500x500) afeta diretamente o comportamento da memória. Como as matrizes ocupam cerca de 2 MB no total, toda a simulação cabe perfeitamente dentro da cache L3 de ambas as CPUs avaliadas. Na execução serial, a localidade espacial é excelente e as falhas de último nível (LLC misses) são quase nulas, indicando que a CPU raramente busca dados na RAM. O gargalo estrutural, portanto, não é a memória principal, mas sim o afunilamento de leitura na L1 causado pela fragmentação da matriz durante a execução paralela e pelo uso massivo do operador de módulo (`%`).

## 5.5 Chamadas de Sistema (`strace`)

Rastreamento do total de interrupções de kernel (syscalls) e identificação da chamada dominante para averiguar o nível de interação entre o programa e o sistema operativo.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Total de Syscalls | | 34 chamadas |
| **C Serial** | Syscall dominante | | `execve` |
| **Python Serial** | Total de Syscalls | | 80.446 chamadas |
| **Python Serial** | Syscall dominante | | `brk` |

## 5.6 Código de referência: https://rosettacode.org/wiki/Conway%27s_Game_of_Life

# 6. Conclusão

A presente análise corrobora a obrigatoriedade do uso de linguagens compiladas nativas para Computação de Alto Desempenho (HPC) em cargas densamente matemáticas. A sobrecarga introduzida na tradução de *bytecode*, as sistemáticas perdas de localidade na cache decorrentes do gestor de objetos do interpretador e a limitação inata do *Global Interpreter Lock* (GIL) inviabilizam o uso de *threads* nativas em Python para a otimização de ciclos computacionais fechados.

As rotas de fuga em Python demonstraram ser apenas paliativas para algoritmos *CPU-bound* restritos pela memória: embora o multiprocessamento contorne o bloqueio do GIL, ele apenas transfere o gargalo de desempenho para a infraestrutura do sistema operativo, incorrendo em altos custos de comunicação interprocessos (via serialização no *Pipe*) ou em latências severas de sincronização de estado global (*Shared Memory*). 

Em contrapartida, a linguagem C, coligada com as diretivas de memória partilhada do OpenMP, demonstrou um uso absoluto e escalável dos recursos físicos do hardware. A ausência de intermediários de *software* e a gestão nativa das *threads* permitiram contornar o estresse na cache L1 de forma eficiente, garantindo processamentos com latência controlada e previsibilidade operacional máxima na simulação do autômato celular.
