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
REPORT_CSV="$OUT_DIR/RESULTADOS_PLANILHA.csv"

# ============================================================
# 1. VERIFICACAO DE KERNEL (Para o Perf Report funcionar)
# ============================================================
# Se kptr_restrict estiver alto, o perf report não consegue ler os nomes das funções (gera apenas endereços hexadecimais).
if [ -f /proc/sys/kernel/kptr_restrict ]; then
    KPTR=$(cat /proc/sys/kernel/kptr_restrict)
    if [ "$KPTR" -ne 0 ]; then
        echo -e "\n[ATENCAO] O 'kernel.kptr_restrict' está ativado ($KPTR)."
        echo "Isso bloqueia a leitura das funcoes (Hotspots) pelo 'perf report'."
        echo "Para tabelas 100% completas, cancele (Ctrl+C), rode:"
        echo "   sudo sysctl -w kernel.kptr_restrict=0"
        echo "e inicie o script novamente."
        echo "Aguardando 5 segundos para continuar mesmo assim...\n"
        sleep 5
    fi
fi

# ============================================================
# 2. FUNCOES AUXILIARES DE PROFILING
# ============================================================

HAVE_TIME=0;      command -v /usr/bin/time  >/dev/null 2>&1 && HAVE_TIME=1
HAVE_PERF=0;      command -v perf           >/dev/null 2>&1 && HAVE_PERF=1
HAVE_VALGRIND=0;  command -v valgrind       >/dev/null 2>&1 && HAVE_VALGRIND=1
HAVE_STRACE=0;    command -v strace         >/dev/null 2>&1 && HAVE_STRACE=1
HAVE_GPROF=0;     command -v gprof          >/dev/null 2>&1 && HAVE_GPROF=1

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
# 4. COMPILACAO C
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
if [ "$HAVE_GPROF" -eq 1 ]; then
    ( cd "$WORK_DIR" && "$BIN_DIR/gol_serial_gprof" >/dev/null 2>&1 )
    [ -f "$WORK_DIR/gmon.out" ] && gprof "$BIN_DIR/gol_serial_gprof" "$WORK_DIR/gmon.out" > "$LOG_DIR/c_serial_gprof_report.txt"
fi
run_perf_stat "c_serial" "$BIN_DIR/gol_serial"
run_perf_record "c_serial" "$BIN_DIR/gol_serial"
run_strace "c_serial" "$BIN_DIR/gol_serial"

if [ "$HAVE_VALGRIND" -eq 1 ]; then
    echo "  [valgrind callgrind+cache] c_serial"
    ( cd "$VALGRIND_DIR" && timeout "$RUN_TIMEOUT" valgrind --tool=callgrind --cache-sim=yes \
        --callgrind-out-file=callgrind.out.c_serial "$BIN_DIR/gol_serial" > /dev/null 2>&1 )
    [ -f "$VALGRIND_DIR/callgrind.out.c_serial" ] && callgrind_annotate --auto=yes "$VALGRIND_DIR/callgrind.out.c_serial" > "$VALGRIND_DIR/callgrind_c_serial_annotate.txt"
fi

# ============================================================
# 6. C OPENMP
# ============================================================
section "Profiling: C OpenMP"
OMP_NUM_THREADS=4 run_time_v "c_omp_4t" "$BIN_DIR/gol_omp"
OMP_NUM_THREADS=4 run_perf_stat "c_omp_4t" "$BIN_DIR/gol_omp"
OMP_NUM_THREADS=4 run_perf_record "c_omp_4t" "$BIN_DIR/gol_omp"
scalability_sweep "c_omp" "OMP_NUM_THREADS" "$BIN_DIR/gol_omp"

# ============================================================
# 7. PYTHON SERIAL
# ============================================================
section "Profiling: Python Serial"
run_time_v "py_serial" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 "$PY_DIR/gol.py"
env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 -m cProfile -s cumulative "$PY_DIR/gol.py" > "$LOG_DIR/py_serial_cprofile.txt" 2>&1
run_perf_stat "py_serial" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 "$PY_DIR/gol.py"
run_perf_record "py_serial" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 "$PY_DIR/gol.py"
run_strace "py_serial" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER python3 "$PY_DIR/gol.py"

# ============================================================
# 8. PYTHON THREADING
# ============================================================
section "Profiling: Python Multithreading"
run_time_v "py_thread_4t" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 "$PY_DIR/gol_multithread.py"
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
    run_time_v "py_${TAG}_4p" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 "$PY_DIR/$SCRIPT_NAME"
    env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 -m cProfile -s cumulative "$PY_DIR/$SCRIPT_NAME" > "$LOG_DIR/py_${TAG}_4p_cprofile.txt" 2>&1
    run_perf_stat "py_${TAG}_4p" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 "$PY_DIR/$SCRIPT_NAME"
    run_perf_record "py_${TAG}_4p" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 python3 "$PY_DIR/$SCRIPT_NAME"
    scalability_sweep "py_${TAG}" "GOL_WORKERS" env GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$SCALE_ITER python3 "$PY_DIR/$SCRIPT_NAME"
done

# ============================================================
# 11. GERAÇÃO DO RELATÓRIO .MD E EXPORTAÇÃO PARA PLANILHA .CSV
# ============================================================
section "CONSOLIDANDO DADOS E GERANDO TABELAS..."

> "$REPORT_CSV"
> "$REPORT_MD"

function add_to_reports() {
    local title="$1"
    local content="$2"
    
    # Adiciona ao MD
    echo -e "### $title\n\`\`\`text\n$content\n\`\`\`\n" >> "$REPORT_MD"
    
    # Adiciona ao CSV (Substitui múltiplos espaços por vírgula para manter as colunas na planilha)
    echo "===== $title =====" >> "$REPORT_CSV"
    echo "$content" \vert{} sed -E 's/^[ \t]+//' \vert{} tr -s ' \t' ',' >> "$REPORT_CSV"
    echo "" >> "$REPORT_CSV"
}

echo "# RELATÓRIO DE DESEMPENHO E HPC" > "$REPORT_MD"
echo "Arquivo exportavel gerado para análise." >> "$REPORT_MD"
echo "===== TABELAS DE DESEMPENHO =====" > "$REPORT_CSV"

# 1. TABELA GERAL
echo -e "## 1. TABELA GERAL (/usr/bin/time -v)" >> "$REPORT_MD"
echo '```text' >> "$REPORT_MD"
column -s, -t "$CSV_TIME_V" >> "$REPORT_MD"
echo -e '```\n' >> "$REPORT_MD"
echo "===== 1. TABELA GERAL =====" >> "$REPORT_CSV"
cat "$CSV_TIME_V" >> "$REPORT_CSV"
echo "" >> "$REPORT_CSV"

# 2. C SERIAL
echo "## 2. ANÁLISE C SERIAL" >> "$REPORT_MD"
add_to_reports "C Serial: Métricas de Hardware e IPC (perf stat)" "$(grep -E "cycles|instructions|insn per cycle|cache-misses|cache-references|branch-misses|branches|L1-dcache|LLC" "$PERF_DIR/c_serial_stat.log" || echo "Dados indisponíveis")"
add_to_reports "C Serial: Hotspot % e Chamadas, Self e Inclusive (gprof)" "$(sed -n '/^ *[0-9]/p' "$LOG_DIR/c_serial_gprof_report.txt" 2>/dev/null | head -n 5 || echo "Gprof indisponível")"
add_to_reports "C Serial: Callgrind Cache (Ir, Dr, D1mr, DLmr)" "$(grep -A 10 "PROGRAM TOTALS" "$VALGRIND_DIR/callgrind_c_serial_annotate.txt" 2>/dev/null || echo "Callgrind indisponível")"
add_to_reports "C Serial: Top 3 Syscalls (strace)" "$(sed -n '/^ \+[0-9]/p' "$LOG_DIR/c_serial_strace.log" 2>/dev/null | sort -k4 -nr | head -n 3 || echo "Strace indisponível")"

# 3. PYTHON SERIAL
echo "## 3. ANÁLISE PYTHON SERIAL" >> "$REPORT_MD"
add_to_reports "Py Serial: Métricas de Hardware e IPC (perf stat)" "$(grep -E "cycles|instructions|insn per cycle|cache-misses|cache-references|branch-misses|branches|L1-dcache|LLC" "$PERF_DIR/py_serial_stat.log" || echo "Dados indisponíveis")"
add_to_reports "Py Serial: Hotspot e Overhead (cProfile)" "$(sed -n '/ ncalls /,/^$/p' "$LOG_DIR/py_serial_cprofile.txt" 2>/dev/null | head -n 10 || echo "cProfile indisponível")"
add_to_reports "Py Serial: Custo Interno em C (perf report)" "$(grep -v "^#" "$PERF_DIR/py_serial_report.txt" 2>/dev/null | awk 'NF' | head -n 5 || echo "Perf Report indisponível")"
add_to_reports "Py Serial: Top 3 Syscalls (strace)" "$(sed -n '/^ \+[0-9]/p' "$LOG_DIR/py_serial_strace.log" 2>/dev/null | sort -k4 -nr | head -n 3 || echo "Strace indisponível")"

# 4. C OPENMP
echo "## 4. ANÁLISE C PARALELO (OpenMP)" >> "$REPORT_MD"
add_to_reports "C OpenMP: IPC, Cache e Trocas de Contexto (perf stat)" "$(grep -E "cycles|instructions|insn per cycle|cache-misses|branch-misses|context-switches|cpu-migrations" "$PERF_DIR/c_omp_4t_stat.log" || echo "Dados indisponíveis")"
add_to_reports "C OpenMP: Overhead Diretivas OpenMP (perf report)" "$(grep -iE "gomp\vert{}omp" "$PERF_DIR/c_omp_4t_report.txt" 2>/dev/null | head -n 10 || echo "Nenhuma função GOMP identificada no topo do profiling.")"

# 5. PYTHON THREADING
echo "## 5. ANÁLISE PYTHON MULTITHREADING" >> "$REPORT_MD"
add_to_reports "Py MT: Gasto de Threading Nativo C (perf report)" "$(grep -iE "evalframe\vert{}acquire\vert{}sem_wait\vert{}thread\vert{}lock" "$PERF_DIR/py_thread_4t_report.txt" 2>/dev/null | head -n 10 || echo "Símbolos não encontrados")"
add_to_reports "Py MT: Gasto Threading Nível Python (cProfile)" "$(grep -iE "thread.*start\vert{}thread.*join\vert{}acquire\vert{}lock" "$LOG_DIR/py_thread_4t_cprofile.txt" 2>/dev/null || echo "Funções não registraram gargalo significativo")"

# 6. PYTHON MULTIPROCESSING
echo "## 6. ANÁLISE PYTHON MULTIPROCESSING (Pipe e Shared Memory)" >> "$REPORT_MD"
add_to_reports "Py MP (Pipe): IPC e Instructions (perf stat)" "$(grep -E "cycles|instructions|insn per cycle" "$PERF_DIR/py_mp_pipe_4p_stat.log" || echo "Dados indisponíveis")"
add_to_reports "Py MP (Pipe): Criação e Comunicação (cProfile)" "$(grep -iE "process\vert{}pipe\vert{}connection\vert{}send\vert{}recv\vert{}pickle\vert{}wait" "$LOG_DIR/py_mp_pipe_4p_cprofile.txt" 2>/dev/null || echo "Dados indisponíveis")
* Nota: Filas (Queue.put/get) ou Pool.map = N/A (Implementação direta via Process + Pipe)"

add_to_reports "Py MP (Shm): IPC e Instructions (perf stat)" "$(grep -E "cycles|instructions|insn per cycle" "$PERF_DIR/py_mp_shm_4p_stat.log" || echo "Dados indisponíveis")"
add_to_reports "Py MP (Shm): Criação e Memoria (cProfile)" "$(grep -iE "process\vert{}sharedmemory\vert{}recv\vert{}wait" "$LOG_DIR/py_mp_shm_4p_cprofile.txt" 2>/dev/null || echo "Dados indisponíveis")"

# 7. ESCALABILIDADE (SPEEDUP)
echo -e "## 7. DADOS DE ESCALABILIDADE BRUTOS\n\`\`\`text" >> "$REPORT_MD"
column -s, -t "$CSV_SCALE" >> "$REPORT_MD"
echo -e "\`\`\`\n" >> "$REPORT_MD"
echo "===== 7. ESCALABILIDADE (1,2,4,8) =====" >> "$REPORT_CSV"
cat "$CSV_SCALE" >> "$REPORT_CSV"

echo "SUCESSO! Seus dados estao prontos para o trabalho em:"
echo " -> Relatorio formatado: $REPORT_MD"
echo " -> Planilha CSV direta: $REPORT_CSV"