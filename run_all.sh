#!/usr/bin/env bash
#
# run_all.sh - Script de Reprodutibilidade e Geração de Tabelas HPC
# Trabalho de "Paralelismo com Memoria Compartilhada" (PGCC011).

set -uo pipefail

# ============================================================
# 0. CONFIGURACAO
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C_DIR="$ROOT_DIR/C"
PY_DIR="$ROOT_DIR/Python"
OUT_DIR="$ROOT_DIR/results"
BIN_DIR="$OUT_DIR/bin"
LOG_DIR="$OUT_DIR/logs"
PERF_DIR="$OUT_DIR/perf"
VALGRIND_DIR="$OUT_DIR/valgrind"
WORK_DIR="$OUT_DIR/workdir" 

GOL_W=500
GOL_H=500
GOL_ITER=5000
COUNTS=(1 2 4 8)
SCALE_ITER="${SCALE_ITER:-$GOL_ITER}"
RUN_TIMEOUT="${RUN_TIMEOUT:-1800}"

mkdir -p "$BIN_DIR" "$LOG_DIR" "$PERF_DIR" "$VALGRIND_DIR" "$WORK_DIR"

CSV_TIME_V="$OUT_DIR/summary_time_v.csv"
CSV_SCALE="$OUT_DIR/summary_scalability.csv"
REPORT_MD="$OUT_DIR/RELATORIO_FINAL.md"

# ============================================================
# 1. DETECCAO DE FERRAMENTAS
# ============================================================

HAVE_TIME=0;      command -v /usr/bin/time  >/dev/null 2>&1 && HAVE_TIME=1
HAVE_PERF=0;      command -v perf           >/dev/null 2>&1 && HAVE_PERF=1
HAVE_VALGRIND=0;  command -v valgrind       >/dev/null 2>&1 && HAVE_VALGRIND=1
HAVE_STRACE=0;    command -v strace         >/dev/null 2>&1 && HAVE_STRACE=1
HAVE_GPROF=0;     command -v gprof          >/dev/null 2>&1 && HAVE_GPROF=1
HAVE_CA=0;        command -v callgrind_annotate >/dev/null 2>&1 && HAVE_CA=1

# ============================================================
# 2. FUNCOES AUXILIARES DE PROFILING
# ============================================================

section() { echo; echo "==================================================================="; echo "== $1"; echo "==================================================================="; }

extract_time_v_csv() {
    local label="$1" logfile="$2"
    [ -f "$logfile" ] || return 0
    local wall user sys cpu maxrss majpf minpf volcs invcs
    wall=$(grep -oP '(?<=Elapsed \(wall clock\) time \(h:mm:ss or m:ss\): ).*' "$logfile" || echo "NA")
    user=$(grep -oP '(?<=User time \(seconds\): ).*' "$logfile" || echo "NA")
    sys=$(grep -oP '(?<=System time \(seconds\): ).*' "$logfile" || echo "NA")
    cpu=$(grep -oP '(?<=Percent of CPU this job got: ).*' "$logfile" || echo "NA")
    maxrss=$(grep -oP '(?<=Maximum resident set size \(kbytes\): ).*' "$logfile" || echo "NA")
    majpf=$(grep -oP '(?<=Major \(requiring I/O\) page faults: ).*' "$logfile" || echo "NA")
    minpf=$(grep -oP '(?<=Minor \(reclaiming a frame\) page faults: ).*' "$logfile" || echo "NA")
    volcs=$(grep -oP '(?<=Voluntary context switches: ).*' "$logfile" || echo "NA")
    invcs=$(grep -oP '(?<=Involuntary context switches: ).*' "$logfile" || echo "NA")
    echo "$label,$wall,$user,$sys,$cpu,$maxrss,$majpf,$minpf,$volcs,$invcs" >> "$CSV_TIME_V"
}

run_time_v() {
    local label="$1"; shift
    local err_time="$LOG_DIR/${label}_time.log"
    echo "  [time -v] $label"
    if [ "$HAVE_TIME" -eq 1 ]; then
        timeout "$RUN_TIMEOUT" /usr/bin/time -v -o "$err_time" "$@" > "$LOG_DIR/${label}_stdout.log" 2>>"$err_time" || true
        extract_time_v_csv "$label" "$err_time"
    fi
}

run_perf_stat() {
    local label="$1"; shift
    if [ "$HAVE_PERF" -eq 1 ]; then
        echo "  [perf stat] $label"
        timeout "$RUN_TIMEOUT" perf stat \
            -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses,context-switches,cpu-migrations \
            -o "$PERF_DIR/${label}_stat.log" -- "$@" > "$LOG_DIR/${label}_perfstat_stdout.log" 2>&1 || true
    fi
}

run_perf_record() {
    local label="$1"; shift
    if [ "$HAVE_PERF" -eq 1 ]; then
        echo "  [perf record] $label"
        ( cd "$PERF_DIR" && timeout "$RUN_TIMEOUT" perf record -g -o "${label}.perf.data" -- "$@" > /dev/null 2>&1 ) || true
        [ -f "$PERF_DIR/${label}.perf.data" ] && perf report --stdio -i "$PERF_DIR/${label}.perf.data" > "$PERF_DIR/${label}_report.txt" 2>&1
    fi
}

run_strace() {
    local label="$1"; shift
    if [ "$HAVE_STRACE" -eq 1 ]; then
        echo "  [strace -c] $label"
        timeout "$RUN_TIMEOUT" strace -c -o "$LOG_DIR/${label}_strace.log" -- "$@" > /dev/null 2>&1 || true
    fi
}

scalability_sweep() {
    local prefix="$1" envvar="$2"; shift 2
    for n in "${COUNTS[@]}"; do
        local label="${prefix}_n${n}"
        echo "  [escalabilidade] $prefix com $envvar=$n"
        local err_time="$LOG_DIR/${label}_time.log"
        env "$envvar=$n" timeout "$RUN_TIMEOUT" /usr/bin/time -v -o "$err_time" "$@" > /dev/null 2>>"$err_time" || true
        local wall=$(grep -oP '(?<=Elapsed \(wall clock\) time \(h:mm:ss or m:ss\): ).*' "$err_time" 2>/dev/null || echo "NA")
        echo "$prefix,$n,$wall" >> "$CSV_SCALE"
    done
}

# ============================================================
# 3. SETUP 
# ============================================================
echo "label,Wall-clock,User_Time,System_Time,CPU_%,Max_RSS(KB),Major_PF,Minor_PF,Vol_CS,Invol_CS" > "$CSV_TIME_V"
echo "prefix,n_threads_ou_processos,wall_clock" > "$CSV_SCALE"

cd "$WORK_DIR" || exit 1

# ============================================================
# 4. COMPILACAO DAS VERSOES C
# ============================================================
section "Compilando versoes C"
gcc -O2 -g         -o "$BIN_DIR/gol_serial"        "$C_DIR/gol.c"
gcc -pg -O2 -g       -o "$BIN_DIR/gol_serial_gprof" "$C_DIR/gol.c"
gcc -O2 -g -fopenmp    -o "$BIN_DIR/gol_omp"          "$C_DIR/gol_omp.c"

# ============================================================
# 5. C SERIAL
# ============================================================
section "Profiling: C Serial"
run_time_v "c_serial" "$BIN_DIR/gol_serial"
run_perf_stat "c_serial" "$BIN_DIR/gol_serial"
run_perf_record "c_serial" "$BIN_DIR/gol_serial"
run_strace "c_serial" "$BIN_DIR/gol_serial"

if [ "$HAVE_VALGRIND" -eq 1 ]; then
    echo "  [valgrind callgrind+cache] c_serial"
    ( cd "$VALGRIND_DIR" && timeout "$RUN_TIMEOUT" valgrind --tool=callgrind --cache-sim=yes \
        --callgrind-out-file=callgrind.out.c_serial "$BIN_DIR/gol_serial" > /dev/null 2>&1 )
    if [ "$HAVE_CA" -eq 1 ] && [ -f "$VALGRIND_DIR/callgrind.out.c_serial" ]; then
        callgrind_annotate --auto=yes "$VALGRIND_DIR/callgrind.out.c_serial" > "$VALGRIND_DIR/callgrind_c_serial_annotate.txt"
    fi
fi

# ============================================================
# 6. C OPENMP
# ============================================================
section "Profiling: C OpenMP"
OMP_NUM_THREADS=4 run_perf_stat "c_omp_4t" "$BIN_DIR/gol_omp"
OMP_NUM_THREADS=4 run_perf_record "c_omp_4t" "$BIN_DIR/gol_omp"
scalability_sweep "c_omp" "OMP_NUM_THREADS" "$BIN_DIR/gol_omp"

# ============================================================
# 7. PYTHON SERIAL
# ============================================================
section "Profiling: Python Serial"

# Aqui a correcao: o env e repassado DENTRO da chamada, antes de python3
run_time_v "py_serial" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 "$PY_DIR/gol.py"

# Para chamadas que nao usam funcoes do bash, o env fica no inicio como ja estava
env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 -m cProfile -s cumulative "$PY_DIR/gol.py" > "$LOG_DIR/py_serial_cprofile.txt" 2>&1

run_perf_stat "py_serial" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 "$PY_DIR/gol.py"

run_perf_record "py_serial" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 "$PY_DIR/gol.py"

run_strace "py_serial" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 "$PY_DIR/gol.py"

# ============================================================
# 8. PYTHON THREADING
# ============================================================
section "Profiling: Python Multithreading"

env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 -m cProfile -s cumulative "$PY_DIR/gol_multithread.py" > "$LOG_DIR/py_thread_4t_cprofile.txt" 2>&1

run_perf_stat "py_thread_4t" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 "$PY_DIR/gol_multithread.py"

run_perf_record "py_thread_4t" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 "$PY_DIR/gol_multithread.py"

scalability_sweep "py_thread" "GOL_WORKERS" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$SCALE_ITER python3 "$PY_DIR/gol_multithread.py"

# ============================================================
# 9. PYTHON MULTIPROCESSING
# ============================================================
section "Profiling: Python Multiprocessing"
for VARIANT in "gol_multiprocess.py:mp_pipe" "gol_multiprocess_shared_memory.py:mp_shm"; do
    SCRIPT_NAME="${VARIANT%%:*}"
    TAG="${VARIANT##*:}"
    
    env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 -m cProfile -s cumulative "$PY_DIR/$SCRIPT_NAME" > "$LOG_DIR/py_${TAG}_4p_cprofile.txt" 2>&1
    
    run_perf_stat "py_${TAG}_4p" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 "$PY_DIR/$SCRIPT_NAME"
    
    run_perf_record "py_${TAG}_4p" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 "$PY_DIR/$SCRIPT_NAME"
    
    scalability_sweep "py_${TAG}" "GOL_WORKERS" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$SCALE_ITER python3 "$PY_DIR/$SCRIPT_NAME"
done

# ============================================================
# 11. GERAÇÃO DE TABELAS E RELATÓRIO FINAL
# ============================================================
section "GERANDO RELATÓRIOS E TABELAS ANALÍTICAS..."

{
    echo "# RELATÓRIO DE DESEMPENHO - HPC"
    echo "Gerado automaticamente pelo script de reprodutibilidade."
    echo

    echo "## 1. TABELA GERAL (Todas as Versões - time -v)"
    echo '```text'
    column -s, -t "$CSV_TIME_V"
    echo '```'
    echo

    echo "## 2. ANÁLISE C SERIAL"
    echo "### Métricas de Hardware (perf stat)"
    echo '```text'
    grep -E "cycles|instructions|insn per cycle|cache-misses|cache-references|branch-misses|branches|L1-dcache|LLC" "$PERF_DIR/c_serial_stat.log" || echo "Dados indisponíveis."
    echo '```'
    
    echo "### Top Hotspot e Overhead (perf report)"
    echo '```text'
    grep -v "^#" "$PERF_DIR/c_serial_report.txt" | awk 'NF' | head -n 5 || echo "Dados indisponíveis."
    echo '```'

    echo "### Métricas de Cache por Função (Callgrind Annotate)"
    echo "Inclui Ir (Instruções), Dr (Acessos), D1mr (L1 Misses), DLmr (LLC Misses)"
    echo '```text'
    if [ -f "$VALGRIND_DIR/callgrind_c_serial_annotate.txt" ]; then
        grep -A 15 "PROGRAM TOTALS" "$VALGRIND_DIR/callgrind_c_serial_annotate.txt"
    else
        echo "Dados indisponíveis."
    fi
    echo '```'

    echo "### Top 3 Syscalls mais Frequentes (strace)"
    echo '```text'
    if [ -f "$LOG_DIR/c_serial_strace.log" ]; then
        grep -v -E "------|total" "$LOG_DIR/c_serial_strace.log" | sort -k4 -n -r | head -n 3
    else
        echo "Dados indisponíveis."
    fi
    echo '```'
    echo

    echo "## 3. ANÁLISE PYTHON SERIAL"
    echo "### Métricas de Hardware (perf stat)"
    echo '```text'
    grep -E "cycles|instructions|insn per cycle|cache-misses|cache-references|branch-misses|branches|L1-dcache|LLC" "$PERF_DIR/py_serial_stat.log" || echo "Dados indisponíveis."
    echo '```'

    echo "### Top Hotspots Python (cProfile)"
    echo '```text'
    head -n 15 "$LOG_DIR/py_serial_cprofile.txt" || echo "Dados indisponíveis."
    echo '```'

    echo "### Top 3 Syscalls mais Frequentes (strace)"
    echo '```text'
    if [ -f "$LOG_DIR/py_serial_strace.log" ]; then
        grep -v -E "------|total" "$LOG_DIR/py_serial_strace.log" | sort -k4 -n -r | head -n 3
    else
        echo "Dados indisponíveis."
    fi
    echo '```'
    echo

    echo "## 4. ANÁLISE C PARALELO (OpenMP)"
    echo "### Tabela de Métricas Paralelas (perf stat)"
    echo '```text'
    grep -E "insn per cycle|cache-misses|branch-misses|context-switches|cpu-migrations" "$PERF_DIR/c_omp_4t_stat.log" || echo "Dados indisponíveis."
    echo '```'

    echo "### Funções Paralelizadas e Overhead OpenMP (perf report)"
    echo '```text'
    echo "--- Funções do motor (hotspot) ---"
    grep -E "evolve" "$PERF_DIR/c_omp_4t_report.txt" | head -n 3
    echo "--- Overhead OpenMP (GOMP) ---"
    grep -E "GOMP|omp" "$PERF_DIR/c_omp_4t_report.txt" | head -n 5 || echo "Sem overhead detectado"
    echo '```'

    echo "### Scalability (Wall-clock 1, 2, 4, 8 threads)"
    echo '```text'
    grep "c_omp," "$CSV_SCALE" | column -s, -t
    echo '```'
    echo

    echo "## 5. ANÁLISE PYTHON MULTITHREADING"
    echo "### Custos e Bloqueios em C/Interpretador (perf report)"
    echo '```text'
    grep -E "_PyEval_EvalFrameDefault|PyThread_acquire_lock|sem_wait|pthread" "$PERF_DIR/py_thread_4t_report.txt" | head -n 10 || echo "Dados indisponíveis."
    echo '```'

    echo "### Custos Nativos Python (cProfile - Threading)"
    echo '```text'
    grep -E "Thread.start|Thread.join|acquire" "$LOG_DIR/py_thread_4t_cprofile.txt" || echo "Dados indisponíveis."
    echo '```'

    echo "### Scalability (Wall-clock 1, 2, 4, 8 threads)"
    echo '```text'
    grep "py_thread," "$CSV_SCALE" | column -s, -t
    echo '```'
    echo

    echo "## 6. ANÁLISE PYTHON MULTIPROCESSING (Pipe e Shared Memory)"
    echo "### Pipe - Instructions e IPC"
    echo '```text'
    grep -E "instructions|insn per cycle" "$PERF_DIR/py_mp_pipe_4p_stat.log" || echo "Dados indisponíveis."
    echo '```'

    echo "### Pipe - Overhead Criação e Comunicação (cProfile)"
    echo '```text'
    grep -E "Process.start|Pipe|send|recv|wait" "$LOG_DIR/py_mp_pipe_4p_cprofile.txt" | head -n 10 || echo "Dados indisponíveis."
    echo '```'

    echo "### Shared Memory - Instructions e IPC"
    echo '```text'
    grep -E "instructions|insn per cycle" "$PERF_DIR/py_mp_shm_4p_stat.log" || echo "Dados indisponíveis."
    echo '```'

    echo "### Shared Memory - Overhead Criação e Comunicação (cProfile)"
    echo '```text'
    grep -E "Process.start|SharedMemory|recv|wait" "$LOG_DIR/py_mp_shm_4p_cprofile.txt" | head -n 10 || echo "Dados indisponíveis."
    echo '```'

    echo "### Scalability MP (Wall-clock 1, 2, 4, 8 processos)"
    echo '```text'
    grep -E "py_mp_" "$CSV_SCALE" | sort -t, -k1,1 -k2,2n | column -s, -t
    echo '```'
    echo

} > "$REPORT_MD"

echo "Tabelas e extracoes estruturadas foram salvas em:"
echo " => $REPORT_MD"
echo