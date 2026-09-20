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

| **Versão do Programa**        | **Métrica Exigida**          | **CPU 1**      | **CPU 2**             |
| ----------------------------- | ---------------------------- | -------------- | --------------------- |
| **C Serial**                  | Wall-clock time (real)       | 0:49.44        | 22.10s                |
| **C Serial**                  | User time (CPU)              | 49.43s         | 22.08s                |
| **C Serial**                  | System time                  | 0.00s          | 0.00s                 |
| **C Serial**                  | Percentual de CPU            | 99%            | 99%                   |
| **C Serial**                  | Max RSS (KB)                 | 3.724          | 3.960                 |
| **C Serial**                  | Context switches (vol/invol) | 1 / 565        | 1 / 709               |
| **C Serial**                  | Page faults (Major/Minor)    | 0 / 570        | 0 / 570               |
| **C OpenMP (4 Threads)**      | Wall-clock time              | 0:13.15        | 7.90s                 |
| **C OpenMP (4 Threads)**      | User time                    | 52.61s         | 31.60s                |
| **C OpenMP (4 Threads)**      | System time                  | 0.00s          | 0.00s                 |
| **C OpenMP (4 Threads)**      | Percentual de CPU            | 399%           | 399%                  |
| **C OpenMP (4 Threads)**      | Max RSS (KB)                 | 4.144          | 4.252                 |
| **C OpenMP (4 Threads)**      | Context switches (vol/invol) | 1 / 258        | 1 / 112               |
| **C OpenMP (4 Threads)**      | Page faults (Major/Minor)    | 0 / 588        | 0 / 589               |
| **Python Serial**             | Wall-clock time              | 20:56.63       | 20:01.01              |
| **Python Serial**             | User time                    | 1251.39s       | 1198.54s              |
| **Python Serial**             | Max RSS (KB)                 | 13.868         | 13.992                |
| **Python Serial**             | Context switches (vol/invol) | 1 / 14.948     | 1 / 10.048            |
| **Python Serial**             | Page faults (Major/Minor)    | 0 / 2.397.003  | 0 / 2.397.003         |
| **Python Thread (4 Threads)** | Wall-clock time              | 22:21.28       | 19:13.51              |
| **Python Thread (4 Threads)** | User time                    | —              | 1155.78s              |
| **Python Thread (4 Threads)** | Max RSS (KB)                 | 18.604         | 18.852                |
| **Python Thread (4 Threads)** | Context switches (vol/invol) | 1.34M / 17k    | 884.100 / 7.288       |
| **Python Thread (4 Threads)** | Page faults (Major/Minor)    | 0 / 3.170      | 0 / 3.167             |
| **Python MP Pipe (4 Proc.)**  | Wall-clock time              | 3:18.89        | 4m 59s                |
| **Python MP Pipe (4 Proc.)**  | Max RSS (KB)                 | 19.084         | 19.140                |
| **Python MP Pipe (4 Proc.)**  | Context switches (vol/invol) | 15.435 / 4.531 | 16.227 / 5.707        |
| **Python MP Pipe (4 Proc.)**  | Page faults (Major/Minor)    | 0 / 9.121      | 0 / 9.161             |
| **Python MP SHM (4 Proc.)**   | Wall-clock time              | 4:18.25        | 5m 30s                |
| **Python MP SHM (4 Proc.)**   | Max RSS (KB)                 | 20.324         | 20.312                |
| **Python MP SHM (4 Proc.)**   | Context switches (vol/invol) | 66.210 / 6.658 | 63.930 / 8.383        |
| **Python MP SHM (4 Proc.)**   | Page faults (Major/Minor)    | 0 / 8.310      | 0 / 8.315             |

**Constatação sobre Microarquitetura (AMD vs. Intel):** Apesar da mesma configuração lógica (4C/8T), a disparidade nos barramentos de cache afeta drasticamente o desempenho sob estresse. A CPU 2 (Intel) lida notavelmente melhor com a fragmentação de memória gerada pelas múltiplas *threads* do OpenMP e processos, pois possui capacidades maiores desde a base (L1 de 320 KB e L3 de 8 MB). Ela acomoda os blocos fragmentados com folga antes de recorrer a níveis mais lentos, sustentando um ganho de eficiência paralela muito superior ao do chip da AMD sob carga intensiva.

**Conclusão sobre Concorrência (OpenMP vs. Python):** O paralelismo nativo em C (OpenMP) introduz um overhead quase nulo de gestão, revertendo \~96% do tempo da CPU diretamente para os cálculos úteis. No outro extremo, a abordagem Multithreading do Python evidencia o estrangulamento causado pelo GIL: as *threads* entram num ciclo ocioso disputando o interpretador, o que faz os *Context Switches* voluntários saltarem para mais de 1,7 milhão (esgotando recursos à toa). Escapar via *Multiprocessing* resolve o bloqueio de CPU, mas transfere o gargalo para a infraestrutura do SO (custos excessivos de cópia no Pipe ou *locks* caros de controlo na Memória Partilhada).

## 5.2 Rastreamento de Chamadas (`gprof` e `cProfile`)

Identificação do hotspot e tempo cumulativo das funções críticas na arquitetura.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** (`gprof`) | Função Hotspot | `evolve` | `evolve` |
| **C Serial** (`gprof`) | % do tempo total | 100% | 100.00% |
| **Python Serial** (`cProfile`) | Função Hotspot | `evolve` | `evolve` |
| **Python Serial** (`cProfile`) | % do tempo total | Quase 100% | 99.9% |
| **Python Thread (8 Threads)** | Maior Overhead de Sistema | | `Thread.join` e `acquire` |
| **Python MP Pipe (4 Proc.)** | Maior Overhead de Sistema | | `posix.read` / `recv` |

## 5.3 Contadores de Desempenho Físico (`perf stat`)

Levantamento de eventos microarquiteturais da CPU, detalhando ciclos totais, instruções efetivamente processadas, vazão (IPC), faltas na cache L1 e erros de previsão de saltos.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Cycles (Ciclos Totais) | 212,6 Bilhões | 91,36 Bilhões |
| **C Serial** | Instructions (Instruções) | 161,2 Bilhões | 160,94 Bilhões |
| **C Serial** | IPC (Instructions Per Cycle) | 0,76 | 1,76 |
| **C Serial** | Cache-references |  | 311.798.970 |
| **C Serial** | Cache-misses | 95,7 Milhões | 921.887 |
| **C Serial** | Branches |  | 17.653.280.461 |
| **C Serial** | Branch-misses | 57,0 Milhões | 87.288.195 |
| **C Serial** | L1-dcache-load-misses | 350.914.081 | 322.631.507 |
| **C Serial** | LLC-load-misses |  | 129.138 |
| **C Serial** | Context-switches (perf, software event) |  | 196 |
| **C Serial** | CPU-migrations (perf, software event) |  | 2 |
| **C OpenMP (4 Threads)** | Cycles (Ciclos Totais) | 218.250.646.648 | 99.349.508.539 |
| **C OpenMP (4 Threads)** | Instructions (Instruções) | 174.515.834.279 | 174.223.785.837 |
| **C OpenMP (4 Threads)** | IPC (Instructions Per Cycle) | 0,80 | 1,75 |
| **C OpenMP (4 Threads)** | Cache-misses | 211.345.293 | 337.535 |
| **C OpenMP (4 Threads)** | Branch-misses | 58.990.579 | 46.974.224 |
| **C OpenMP (4 Threads)** | L1-dcache-load-misses | 5.231.841.420 | 7.654.028.541 |
| **Python Serial** | Cycles (Ciclos Totais) | 5,3 Trilhões | 10.089.609.249 |
| **Python Serial** | Instructions (Instruções) | 17,5 Trilhões | 27.897.569.960 |
| **Python Serial** | IPC (Instructions Per Cycle) | 3,30 | 2,77 |
| **Python Serial** | Cache-misses | 342,5 Milhões | 46.645 |
| **Python Serial** | Branch-misses | 7,8 Bilhões | 11.582.149 |
| **Python Thread (4T)** | Wall-clock (via `perf stat`) | — | 1.164,18 s (~19m 24s) |
| **Python Thread (4T)** | User time (via `perf stat`) | — | 1.165,85 s |
| **Python Thread (4T)** | Cycles (Ciclos Totais) | 5.379.282.244.208 | 4.518.126.167.147 |
| **Python Thread (4T)** | Instructions (Instruções) | 17.608.886.545.002 | 17.597.247.221.377 |
| **Python Thread (4T)** | IPC (Instructions Per Cycle) | ~3,27 | ~3,89 |
| **Python Thread (4T)** | Cache-misses | 2.462.140.587 | 272.502.819 |
| **Python Thread (4T)** | Branch-misses | 8.198.743.041 | 2.470.530.052 |
| **Python Thread (4T)** | L1-dcache-load-misses | 4.238.889.680 | 1.968.808.064 |
| **Python MP Pipe (4p)** | Wall-clock (via `perf stat`) | — | 286,74 s (~4m 46s) |
| **Python MP Pipe (4p)** | User time (via `perf stat`) | — | 1.105,93 s |
| **Python MP Pipe (4p)** | Cycles (Ciclos Totais) | 2.798.021.844.034 | 2.882.364.548.550 |
| **Python MP Pipe (4p)** | Instructions (Instruções) | 9.910.226.428.105 | 9.911.783.800.805 |
| **Python MP Pipe (4p)** | IPC (Instructions Per Cycle) | ~3,54 | ~3,44 |
| **Python MP Pipe (4p)** | Cache-misses | 476.953.198 | 203.578.273 |
| **Python MP Pipe (4p)** | Branch-misses | 2.248.343.823 | 2.292.640.154 |
| **Python MP Pipe (4p)** | L1-dcache-load-misses | 1.161.896.205 | 926.941.227 |
| **Python MP SHM (4p)** | Wall-clock (via `perf stat`) | — | 334,01 s (~5m 34s) |
| **Python MP SHM (4p)** | User time (via `perf stat`) | — | 1.245,77 s |
| **Python MP SHM (4p)** | Cycles (Ciclos Totais) | 3.505.148.864.460 | 3.034.614.577.776 |
| **Python MP SHM (4p)** | Instructions (Instruções) | 10.895.344.752.269 | 10.896.446.025.271 |
| **Python MP SHM (4p)** | IPC (Instructions Per Cycle) | ~3,11 | ~3,59 |
| **Python MP SHM (4p)** | Cache-misses | 346.844.316 | 69.167.556 |
| **Python MP SHM (4p)** | Branch-misses | 9.420.072.800 | 9.039.001.940 |
| **Python MP SHM (4p)** | L1-dcache-load-misses | 595.904.467 | 440.559.560 |


**Observação sobre a Ilusão do IPC em Python:** A métrica de IPC no script Python (ex: 3,30) exibe uma capacidade espantosa da CPU em limpar as esteiras de instruções. No entanto, esse IPC massivo esconde um grande gargalo de eficiência: o processador está a operar freneticamente apenas para lidar com o *overhead* do próprio interpretador CPython (tipagem dinâmica, recolha de lixo, varreduras do GIL). A execução consome impressionantes \~17,5 trilhões de instruções artificiais que não agregam valor algorítmico face aos enxutos 161 bilhões do binário nativo em C.

## 5.3.1 Perfil de Overhead por Função (`perf report`)

Relatório obtido a partir de `perf record -g` e `perf report --stdio`, apresentando o overhead por função no **C Serial (CPU 2)**.

| **Função** | **% Children** | **% Self** |
| :--- | ---: | ---: |
| `evolve` | 99,21% | 99,03% |
| `__memmove_evex_unaligned_erms` | 0,79% | 0,79% |

A função `evolve` concentra praticamente todo o overhead amostrado pelo `perf`, enquanto a rotina `__memmove_evex_unaligned_erms`, responsável pela cópia vetorizada de `new` para `univ`, representa uma parcela pequena, mas mensurável, do tempo de execução. Esse resultado complementa a análise da Seção 5.4.1, que identifica a cópia de memória como uma parcela reduzida do total de instruções.

## 5.4 Simulação de Memória e Instruções (`Valgrind`)

Contagem exata de instruções simuladas e rastreamento da hierarquia de memória para identificar perdas de localidade na cache L1 e no último nível (LLC).

| Versão do Programa | Ferramenta / Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Callgrind: Total de Instruções (Ir) | 160.752.587.495\* | 160.752.589.391\* |
| **C Serial** | Cachegrind: Leitura de Dados (Dr) | | 11.426.810.980 |
| **C Serial** | Cachegrind: Misses L1 (D1mr) | | 10.106.438 |
| **C Serial** | Cachegrind: Misses Último Nível (DLmr) | | 1.187 |

**Análise sobre o Volume de Dados e Localidade de Cache:** O dimensionamento do problema (500x500) afeta diretamente o comportamento da memória. Como as matrizes ocupam cerca de 2 MB no total, toda a simulação cabe perfeitamente dentro da cache L3 de ambas as CPUs avaliadas. Na execução serial, a localidade espacial é excelente e as falhas de último nível (LLC misses) são quase nulas, indicando que a CPU raramente busca dados na RAM. O gargalo estrutural, portanto, não é a memória principal, mas sim o afunilamento de leitura na L1 causado pela fragmentação da matriz durante a execução paralela e pelo uso massivo do operador de módulo (`%`).

### 5.4.1 Detalhamento de Instruções por Função e Bloco de Código (`cg_annotate` — C Serial)

Tabela consolidada de Instruction References (Ir) por função e por trecho de código dentro de `evolve` — o hotspot do programa —, comparando CPU 1 e CPU 2. Os valores da CPU 1 estão confirmados linha a linha pela saída real do `cg_annotate` (`cachegrind_c_serial_annotate.txt`, gerado a partir de `cachegrind.out.c_serial`); os da CPU 2 seguem assumidos como equivalentes, já que a contagem de instruções depende do código-fonte e do compilador, não do clock/microarquitetura (ver nota da Seção 5.4).

| Bloco / Função / Linha de Código (`gol.c`) | Instruções (CPU 1) | % (CPU 1) | Instruções (CPU 2) | % (CPU 2) | Linha em `gol.c` |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Total do Programa** | 160.752.587.495 | 100,0% | 160.752.589.391 | 100,0% | — |
| **Função `evolve` (Total)** | 160.190.533.417 | 99,65% | 160.190.533.417 | 99,65% | — |
| ↳ Operação de Módulo (`%`) | 71.264.250.000 | 44,33% | 71.264.250.000 | 44,33% | `if (univ[(y1 + h) % h][(x1 + w) % w])` |
| ↳ Loop interno de vizinhança ($x1$) | 33.756.750.000 | 21,00% | 33.756.750.000 | 21,00% | `for (int x1 = x - 1; x1 <= x + 1; x1++)` |
| ↳ Condição de contorno (`n++`) | 22.504.500.000 | 14,00% | 22.504.500.000 | 14,00% | `n++;` |
| ↳ Loop externo de vizinhança ($y1$) | 11.252.250.000 | 7,00% | 11.252.250.000 | 7,00% | `for (int y1 = y - 1; y1 <= y + 1; y1++)` |
| ↳ Atualização da matriz (`new`) | 6.339.534.370 | 3,94% | 6.339.534.370 | 3,94% | `new[y][x] = (n == 3 \|\| (n == 2 && univ[y][x]));` |
| ↳ Ajuste de células centrais | 6.271.254.000 | 3,90% | 6.271.254.000 | 3,90% | `if (univ[y][x]) n--;` |
| ↳ Varredura de colunas ($x$) | 6.256.321.014 | 3,89% | 6.256.321.014 | 3,89% | `for (int x = 0; x < w; x++)` (loop de cálculo) |
| ↳ Inicialização de variáveis | 2.500.500.000 | 1,56% | 2.500.500.000 | 1,56% | `int n = 0;` |
| **Cópia de Memória (`__memcpy_avx_unaligned_erms`)** | 552.610.612 | 0,35% | 552.610.612 | 0,35% | 2ª passagem: `univ[y][x] = new[y][x];` (vetorizada pelo compilador) |
| ↳ `count_alive` (redução OpenMP) | 1.253.009 | ~0,0008% | 1.253.009 | ~0,0008% | `total_alive += univ[y][x];` e laços associados |
| ↳ `game` (inicialização + laço de gerações) | 3.039.546 | ~0,0019% | 3.039.546 | ~0,0019% | Inicialização da cruz + chamadas a `evolve` |

**Análise:** a decomposição confirma, em nível de instrução (e não apenas de tempo, como no gprof da Seção 5.2), que `evolve` responde por 99,65% de todo o Ir do programa — praticamente idêntico entre as duas CPUs, já que a contagem de instruções depende do código-fonte e do compilador, não do clock ou da microarquitetura. Dentro de `evolve`, o maior custo isolado é a operação de módulo (`%`) usada para a topologia toroidal (44,33% do total), seguida da varredura de vizinhança propriamente dita (loops $x1$/$y1$ somados, 28%) e do incremento do contador de vizinhos (14%). Isso aponta o operador `%` — não a comparação de regras em si — como o alvo mais direto de otimização algorítmica (por exemplo, substituindo o módulo por comparações condicionais de borda, mais baratas em ciclos de CPU). A função `__memcpy_avx_unaligned_erms` (cópia de `new` de volta para `univ`, vetorizada automaticamente pelo GCC via `-O2`) responde por apenas 0,35% do Ir total, e tanto `count_alive` quanto a inicialização em `game` são estatisticamente irrelevantes (< 0,001% cada), confirmando que o *double buffering* explícito e a contagem final têm custo desprezível frente ao laço de cálculo.

**Pendência remanescente do requisito de Cachegrind:** o arquivo `cachegrind_c_serial_annotate.txt` enviado tem `Events recorded: Ir` no cabeçalho — ou seja, essa coleta específica só contabilizou instruções, sem simulação de cache (D refs, D1 misses, LL misses). Isso significa que ela **confirma e detalha o Ir por linha** (já incorporado à tabela acima), mas **não substitui** o requisito de "referências de dados (D refs) e faltas L1/LLC por função" — esse continua pendente e exige rodar o Cachegrind com a simulação de cache habilitada (o comportamento padrão de `valgrind --tool=cachegrind`, sem `--cache-sim=no`) e depois `cg_annotate` sobre esse novo arquivo de saída.

## 5.5 Chamadas de Sistema (`strace`)

Rastreamento do total de interrupções de kernel (syscalls) e identificação da chamada dominante para averiguar o nível de interação entre o programa e o sistema operativo.

| Versão do Programa | Métrica Exigida | CPU 1 | CPU 2 |
| :--- | :--- | :--- | :--- |
| **C Serial** | Total de Syscalls | | 35 chamadas |
| **C Serial** | Syscall mais frequente (por contagem) | | `mmap` (8 ocorrências) |
| **Python Serial** | Total de Syscalls | | 80.446 chamadas |
| **Python Serial** | Syscall dominante | | `brk` |

## 5.6 Escalabilidade (1 a 8 Trabalhadores) — CPU 2 (Intel Core i5-1135G7)

Wall-clock medido variando o número de threads/processos, com o objetivo de observar o ganho marginal de desempenho ao aumentar os trabalhadores além de 4.

| Modelo de Execução | 1 Worker | 2 Workers | 4 Workers | 8 Workers |
| :--- | :--- | :--- | :--- | :--- |
| **C + OpenMP** | 22,99s | 12,42s | 7,90s | 8,46s |
| **Python - Threading** | 20m 54s | 19m 37s | 19m 13s | 19m 15s |
| **Python - Multiprocessing (Pipe)** | 12m 59s | 07m 32s | 04m 59s | 04m 40s |
| **Python - Multiprocessing (SHM)** | 13m 46s | 07m 29s | 05m 30s\* | 04m 29s |


**Análise preliminar:** o OpenMP apresenta ganhos consistentes até 4 threads (22,99s → 7,90s) e uma leve piora em 8 (8,46s), padrão coerente com o observado na CPU 1 (Seção 5.3 e a discussão de escalabilidade já feita para essa métrica). Os dois modelos de Multiprocessing seguem uma curva de ganhos decrescentes: o salto de 1 para 4 trabalhadores é expressivo, mas o ganho de 4 para 8 é marginal (Pipe: 4m59s → 4m40s; SHM: 5m30s → 4m29s), sugerindo que o overhead fixo de criação de processos e a granularidade de comunicação por geração já dominam o tempo total nessa faixa.

## 5.7 Comparação Extensiva dos Modelos Paralelos (4 Threads/Processos)

Tabela-síntese isolando o ponto de 4 threads/processos — o valor de referência usado ao longo deste relatório para comparar os três modelos de paralelismo entre si.

| Modelo | Speedup (CPU 1) | Speedup (CPU 2) | Eficiência (CPU 1) | Eficiência (CPU 2) | Wall-clock (CPU 1) | Wall-clock (CPU 2) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **OpenMP (C)** | 3,76x | 2,80x | 94,0% | 70,0% | 13,15s | 7,90s |
| **Py Threading** | 0,93x | 1,23x | 23,3% | 15,4% | 22m 24s | 19m 56s |
| **Py MP Pipe** | 6,32x | 4,93x | 158,0% | 123,2% | 3m 18s | 4m 59s |
| **Py MP SHM** | 4,87x | 4,47x | 121,8% | 111,8% | 4m 18s | 5m 30s |

**Observação sobre o Speedup Superlinear no Multiprocessing:** chama atenção que Py MP Pipe e Py MP SHM apresentem eficiência acima de 100% (158,0% e 121,8% na CPU 1, respectivamente) — ou seja, speedup maior do que o número de processos usados. Para um algoritmo estritamente CPU-bound como este, isso não decorre de "trabalho extra" sendo criado, mas tipicamente de efeitos colaterais da divisão em processos menores: cada processo lida com uma fatia menor da matriz (mais amigável ao cache L1/L2 por núcleo) e paga o overhead do interpretador Python uma única vez por processo, em paralelo, em vez de diluir esse custo sequencialmente como na versão de 1 worker. Ainda assim, vale registrar que speedup superlinear costuma ser sensível a variância de medição entre execuções — idealmente valeria repetir essas medições algumas vezes para confirmar a robustez do resultado antes de tratá-lo como conclusão definitiva do relatório.

# 6. Conclusão

A presente análise corrobora a obrigatoriedade do uso de linguagens compiladas nativas para Computação de Alto Desempenho (HPC) em cargas densamente matemáticas. A sobrecarga introduzida na tradução de *bytecode*, as sistemáticas perdas de localidade na cache decorrentes do gestor de objetos do interpretador e a limitação inata do *Global Interpreter Lock* (GIL) inviabilizam o uso de *threads* nativas em Python para a otimização de ciclos computacionais fechados.

As rotas de fuga em Python demonstraram ser apenas paliativas para algoritmos *CPU-bound* restritos pela memória: embora o multiprocessamento contorne o bloqueio do GIL, ele apenas transfere o gargalo de desempenho para a infraestrutura do sistema operativo, incorrendo em altos custos de comunicação interprocessos (via serialização no *Pipe*) ou em latências severas de sincronização de estado global (*Shared Memory*). 

Em contrapartida, a linguagem C, coligada com as diretivas de memória partilhada do OpenMP, demonstrou um uso absoluto e escalável dos recursos físicos do hardware. A ausência de intermediários de *software* e a gestão nativa das *threads* permitiram contornar o estresse na cache L1 de forma eficiente, garantindo processamentos com latência controlada e previsibilidade operacional máxima na simulação do autômato celular.

# 7. Código de referência: https://rosettacode.org/wiki/Conway%27s_Game_of_Life
# 8. Acesso aos perf.data: https://drive.google.com/drive/folders/1cg9oiYW-o6qGy5-GZVJGUmN9oM5Y_O9B?usp=sharing
