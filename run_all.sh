#!/usr/bin/env bash
#
# run_all.sh - script de reprodutibilidade para o trabalho de
# "Paralelismo com Memoria Compartilhada" (PGCC011).
#
# Roda TODAS as versoes exigidas pelo enunciado (C serial, C+OpenMP,
# Python serial, Python threading, Python multiprocessing) e faz o
# profiling completo pedido nas secoes 3.2 a 3.7: /usr/bin/time -v,
# gprof, perf stat/record, valgrind (callgrind/cachegrind), strace,
# cProfile, e a varredura de escalabilidade com 1/2/4/8 threads/processos.
#
# Como este grupo implementou DUAS versoes de multiprocessing
# (gol_multiprocess.py, baseada em Pipe, e gol_multiprocess_shared_memory.py,
# baseada em multiprocessing.shared_memory), o script roda o profiling
# completo da secao 3.7 para as DUAS, lado a lado, para permitir comparar
# IPC via mensagens vs. memoria compartilhada dentro do proprio
# multiprocessing (alem da comparacao geral com OpenMP e threading).
#
# Uso:
#   chmod +x run_all.sh
#   ./run_all.sh
#
# Ajuste as variaveis de configuracao abaixo ANTES de rodar, sobretudo
# GOL_ITER e SCALE_ITER, dependendo da velocidade da sua maquina (veja
# os comentarios de cada uma).

set -uo pipefail
# (Nao uso 'set -e': se uma ferramenta de profiling individual falhar,
#  quero que o script registre o erro e continue para as demais etapas,
#  em vez de abortar a reproducao inteira no meio.)

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
WORK_DIR="$OUT_DIR/workdir"   # aqui rodamos os binarios (evita sujar o repo com gol_*.pbm)

# Volume de dados. Requisito 3.1.1: a versao C serial deve rodar >=20s
# com -O2. Testado neste ambiente (1 nucleo): 500x500x5000 ~ 32s no C
# serial. AJUSTE conforme sua maquina: se sua versao C rodar em menos
# de 20s, aumente GOL_ITER (e edite o mesmo valor hardcoded dentro de
# gol.c e gol_omp.c, ja que esses .c NAO leem variavel de ambiente).
GOL_W=500
GOL_H=500
GOL_ITER=5000

# Contagens de thread/processo exigidas pelo enunciado (secoes 3.1.2,
# 3.1.4, 3.1.5): 1, 2, 4 e 8.
COUNTS=(1 2 4 8)

# Iteracoes usadas especificamente na VARREDURA de escalabilidade
# (1/2/4/8 threads/processos). Por padrao igual a GOL_ITER, mas em
# Python puro isso pode levar HORAS no total (4 configuracoes x varias
# versoes). Se estiver testando o script ou sua maquina for lenta,
# reduza SCALE_ITER (ex.: 500) so para a varredura de escalabilidade;
# mantenha GOL_ITER cheio para os profilings individuais (gprof, perf
# record, valgrind), que rodam uma unica vez por versao.
SCALE_ITER="${SCALE_ITER:-$GOL_ITER}"

# Timeout de seguranca por execucao individual (segundos). Evita que
# uma configuracao lenta trave o script inteiro indefinidamente.
RUN_TIMEOUT="${RUN_TIMEOUT:-1800}"

# Reducao de entrada para valgrind --tool=callgrind (spec sugere N/10).
VALGRIND_ITER=$((GOL_ITER / 10))
[ "$VALGRIND_ITER" -lt 10 ] && VALGRIND_ITER=10

mkdir -p "$BIN_DIR" "$LOG_DIR" "$PERF_DIR" "$VALGRIND_DIR" "$WORK_DIR"

CSV_TIME_V="$OUT_DIR/summary_time_v.csv"
CSV_SCALE="$OUT_DIR/summary_scalability.csv"

# ============================================================
# 1. DETECCAO DE FERRAMENTAS (degrada graciosamente se faltar)
# ============================================================

HAVE_TIME=0;     command -v /usr/bin/time  >/dev/null 2>&1 && HAVE_TIME=1
HAVE_PERF=0;     command -v perf           >/dev/null 2>&1 && HAVE_PERF=1
HAVE_VALGRIND=0; command -v valgrind       >/dev/null 2>&1 && HAVE_VALGRIND=1
HAVE_STRACE=0;   command -v strace         >/dev/null 2>&1 && HAVE_STRACE=1
HAVE_GPROF=0;    command -v gprof          >/dev/null 2>&1 && HAVE_GPROF=1
HAVE_CACHEGRIND_ANNOTATE=0; command -v cg_annotate >/dev/null 2>&1 && HAVE_CACHEGRIND_ANNOTATE=1
HAVE_CALLGRIND_ANNOTATE=0;  command -v callgrind_annotate >/dev/null 2>&1 && HAVE_CALLGRIND_ANNOTATE=1

warn_missing() {
    echo "[AVISO] '$1' nao encontrado no PATH - etapa pulada. Instale com: $2"
}

# ============================================================
# 2. FUNCOES AUXILIARES
# ============================================================

section() { echo; echo "==================================================================="; echo "== $1"; echo "==================================================================="; }

# extract_time_v_csv <label> <arquivo_time_v.log>
# Faz o parse do relatorio do `/usr/bin/time -v` e acrescenta uma linha
# ao CSV consolidado (requisito 3.2: tabela comparativa das 5 versoes).
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

# run_time_v <label> <comando...>
# Roda /usr/bin/time -v (se disponivel; senao cai para o `time` do
# bash, com metricas mais limitadas) e grava stdout/stderr separados.
run_time_v() {
    local label="$1"; shift
    local out="$LOG_DIR/${label}_stdout.log"
    local err_time="$LOG_DIR/${label}_time.log"
    echo "  [time -v] $label"

    if [ "$HAVE_TIME" -eq 1 ]; then
        timeout "$RUN_TIMEOUT" /usr/bin/time -v -o "$err_time" "$@" > "$out" 2>>"$err_time" \
            || echo "  [AVISO] '$label' terminou com erro/timeout (ver $err_time)"
        extract_time_v_csv "$label" "$err_time"
    else
        # Fallback sem metricas de RSS/page faults/context switches:
        # 'time' aqui e a keyword do bash (nao um binario), entao nao
        # pode passar por env/timeout como comando - precisa envolver
        # a chamada inteira (incluindo o timeout) num bloco { }.
        echo "  [AVISO] /usr/bin/time nao encontrado - usando 'time' do bash (metricas limitadas: sem RSS/page faults/context switches)"
        { time timeout "$RUN_TIMEOUT" "$@" ; } > "$out" 2>"$err_time" \
            || echo "  [AVISO] '$label' terminou com erro/timeout (ver $err_time)"
    fi
}

# run_perf_stat <label> <comando...>
run_perf_stat() {
    local label="$1"; shift
    if [ "$HAVE_PERF" -ne 1 ]; then warn_missing perf "sudo apt install linux-tools-common linux-tools-\$(uname -r)"; return; fi
    echo "  [perf stat] $label"
    timeout "$RUN_TIMEOUT" perf stat \
        -e cycles,instructions,cache-references,cache-misses,branches,branch-misses,L1-dcache-load-misses,LLC-load-misses \
        -o "$PERF_DIR/${label}_stat.log" -- "$@" > "$LOG_DIR/${label}_perfstat_stdout.log" 2>&1 \
        || echo "  [AVISO] perf stat de '$label' falhou/timeout"
}

# run_perf_record <label> <comando...>
# Gera perf.data (requisito 4.2: "Arquivo perf.data compactado") e o
# relatorio textual via `perf report --stdio`.
run_perf_record() {
    local label="$1"; shift
    if [ "$HAVE_PERF" -ne 1 ]; then return; fi
    echo "  [perf record] $label"
    ( cd "$PERF_DIR" && timeout "$RUN_TIMEOUT" perf record -g -o "${label}.perf.data" -- "$@" \
        > "$LOG_DIR/${label}_perfrecord_stdout.log" 2>&1 ) \
        || echo "  [AVISO] perf record de '$label' falhou/timeout"
    if [ -f "$PERF_DIR/${label}.perf.data" ]; then
        perf report --stdio -i "$PERF_DIR/${label}.perf.data" > "$PERF_DIR/${label}_report.txt" 2>&1
    fi
}

run_strace() {
    local label="$1"; shift
    if [ "$HAVE_STRACE" -ne 1 ]; then warn_missing strace "sudo apt install strace"; return; fi
    echo "  [strace -c] $label"
    timeout "$RUN_TIMEOUT" strace -c -o "$LOG_DIR/${label}_strace.log" -- "$@" \
        > "$LOG_DIR/${label}_strace_stdout.log" 2>&1 \
        || echo "  [AVISO] strace de '$label' falhou/timeout"
}

# scalability_sweep <prefixo> <lista_de_env_extra_por_run> <comando...>
# Roda o comando com cada valor de COUNTS, medindo wall-clock via
# /usr/bin/time -v, e grava uma linha no CSV de escalabilidade.
# $2 e o NOME da variavel de ambiente que carrega a contagem
# (ex.: "OMP_NUM_THREADS" ou "GOL_WORKERS").
scalability_sweep() {
    local prefix="$1" envvar="$2"; shift 2
    for n in "${COUNTS[@]}"; do
        local label="${prefix}_n${n}"
        echo "  [escalabilidade] $prefix com $envvar=$n"
        local err_time="$LOG_DIR/${label}_time.log"
        if [ "$HAVE_TIME" -eq 1 ]; then
            env "$envvar=$n" timeout "$RUN_TIMEOUT" /usr/bin/time -v -o "$err_time" "$@" \
                > "$LOG_DIR/${label}_stdout.log" 2>>"$err_time" \
                || echo "    [AVISO] '$label' terminou com erro/timeout"
        else
            # 'time' e keyword do bash, nao pode ser argumento de env;
            # exporta a variavel dentro de uma subshell e usa 'time' ali.
            ( export "$envvar=$n"; time timeout "$RUN_TIMEOUT" "$@" ) \
                > "$LOG_DIR/${label}_stdout.log" 2>"$err_time" \
                || echo "    [AVISO] '$label' terminou com erro/timeout"
        fi
        local wall
        if [ "$HAVE_TIME" -eq 1 ]; then
            wall=$(grep -oP '(?<=Elapsed \(wall clock\) time \(h:mm:ss or m:ss\): ).*' "$err_time" 2>/dev/null)
        else
            # fallback: saida do 'time' do bash, formato "real\t0mX.Ys"
            wall=$(grep -oP '(?<=^real\t).*' "$err_time" 2>/dev/null)
        fi
        [ -z "${wall:-}" ] && wall="NA"
        echo "$prefix,$n,$wall" >> "$CSV_SCALE"
    done
}

# ============================================================
# 3. lscpu (exigido em 2. ORGANIZACAO)
# ============================================================

section "Informacoes de hardware (lscpu)"
lscpu | tee "$OUT_DIR/lscpu.txt"

echo "" > "$CSV_TIME_V"
echo "label,wall_clock,user_s,sys_s,cpu_pct,maxrss_kb,major_pf,minor_pf,vol_ctxsw,invol_ctxsw" > "$CSV_TIME_V"
echo "prefix,n_threads_ou_processos,wall_clock" > "$CSV_SCALE"

cd "$WORK_DIR" || exit 1

# ============================================================
# 4. COMPILACAO DAS VERSOES C
# ============================================================

section "Compilando versoes C"
gcc -O2 -g            -o "$BIN_DIR/gol_serial"       "$C_DIR/gol.c"
gcc -pg -O2 -g         -o "$BIN_DIR/gol_serial_gprof" "$C_DIR/gol.c"
gcc -O2 -g -fopenmp    -o "$BIN_DIR/gol_omp"          "$C_DIR/gol_omp.c"
echo "Binarios em $BIN_DIR"

# ============================================================
# 5. C SERIAL (3.2 + 3.3)
# ============================================================

section "C Serial: /usr/bin/time -v"
run_time_v "c_serial" "$BIN_DIR/gol_serial"

section "C Serial: gprof (3.3.1)"
if [ "$HAVE_GPROF" -eq 1 ]; then
    ( cd "$WORK_DIR" && "$BIN_DIR/gol_serial_gprof" > "$LOG_DIR/c_serial_gprof_stdout.log" )
    if [ -f "$WORK_DIR/gmon.out" ]; then
        gprof "$BIN_DIR/gol_serial_gprof" "$WORK_DIR/gmon.out" > "$LOG_DIR/c_serial_gprof_report.txt"
        echo "  relatorio em $LOG_DIR/c_serial_gprof_report.txt"
    else
        echo "  [AVISO] gmon.out nao foi gerado"
    fi
else
    warn_missing gprof "sudo apt install binutils"
fi

section "C Serial: perf stat + perf record (3.3.2)"
run_perf_stat   "c_serial" "$BIN_DIR/gol_serial"
run_perf_record  "c_serial" "$BIN_DIR/gol_serial"

section "C Serial: valgrind --tool=callgrind (3.3.3, entrada reduzida ~N/10)"
if [ "$HAVE_VALGRIND" -eq 1 ]; then
    # gol.c tem w/h/max_iter fixos no codigo-fonte; nao ha como passar
    # VALGRIND_ITER via env. Compile uma variante reduzida se quiser
    # rodar o callgrind/cachegrind com o N/10 exato do enunciado -
    # ver nota no final do script. Aqui rodamos com timeout generoso
    # sobre o binario padrao para nao travar o pipeline.
    ( cd "$VALGRIND_DIR" && timeout "$RUN_TIMEOUT" valgrind --tool=callgrind \
        --callgrind-out-file=callgrind.out.c_serial \
        "$BIN_DIR/gol_serial" > "$LOG_DIR/c_serial_callgrind_stdout.log" 2>"$LOG_DIR/c_serial_callgrind_stderr.log" ) \
        || echo "  [AVISO] callgrind timeout/erro - considere compilar gol.c com max_iter menor"
    if [ "$HAVE_CALLGRIND_ANNOTATE" -eq 1 ] && [ -f "$VALGRIND_DIR/callgrind.out.c_serial" ]; then
        callgrind_annotate "$VALGRIND_DIR/callgrind.out.c_serial" > "$VALGRIND_DIR/callgrind_c_serial_annotate.txt"
    fi

    section "C Serial: valgrind --tool=cachegrind (3.3.3)"
    ( cd "$VALGRIND_DIR" && timeout "$RUN_TIMEOUT" valgrind --tool=cachegrind \
        --cachegrind-out-file=cachegrind.out.c_serial \
        "$BIN_DIR/gol_serial" > "$LOG_DIR/c_serial_cachegrind_stdout.log" 2>"$LOG_DIR/c_serial_cachegrind_stderr.log" ) \
        || echo "  [AVISO] cachegrind timeout/erro - considere compilar gol.c com max_iter menor"
    if [ "$HAVE_CACHEGRIND_ANNOTATE" -eq 1 ] && [ -f "$VALGRIND_DIR/cachegrind.out.c_serial" ]; then
        cg_annotate "$VALGRIND_DIR/cachegrind.out.c_serial" > "$VALGRIND_DIR/cachegrind_c_serial_annotate.txt"
    fi
else
    warn_missing valgrind "sudo apt install valgrind"
fi

section "C Serial: strace -c (3.3.4)"
run_strace "c_serial" "$BIN_DIR/gol_serial"

# ============================================================
# 6. C OPENMP (3.4)
# ============================================================

section "C OpenMP: perf stat/record com OMP_NUM_THREADS=4 (3.4.1)"
OMP_NUM_THREADS=4 run_perf_stat   "c_omp_4t" "$BIN_DIR/gol_omp"
OMP_NUM_THREADS=4 run_perf_record "c_omp_4t" "$BIN_DIR/gol_omp"

section "C OpenMP: escalabilidade 1/2/4/8 threads (3.4.2)"
scalability_sweep "c_omp" "OMP_NUM_THREADS" "$BIN_DIR/gol_omp"

# ============================================================
# 7. PYTHON SERIAL (3.5)
# ============================================================

section "Python Serial: /usr/bin/time -v"
GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER \
    run_time_v "py_serial" python3 "$PY_DIR/gol.py"

section "Python Serial: cProfile (3.5.1)"
GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER \
    python3 -m cProfile -s cumulative "$PY_DIR/gol.py" > "$LOG_DIR/py_serial_cprofile.txt" 2>&1

section "Python Serial: perf stat (3.5.2)"
GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER \
    run_perf_stat "py_serial" python3 "$PY_DIR/gol.py"

section "Python Serial: strace -c (3.5.3)"
GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER \
    run_strace "py_serial" python3 "$PY_DIR/gol.py"

# ============================================================
# 8. PYTHON THREADING (3.6)
# ============================================================

section "Python Threading: cProfile com 4 threads (3.6.1)"
GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 \
    python3 -m cProfile -s cumulative "$PY_DIR/gol_multithread.py" > "$LOG_DIR/py_thread_4t_cprofile.txt" 2>&1

section "Python Threading: perf stat/record com 4 threads (3.6.2)"
GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 \
    run_perf_stat "py_thread_4t" python3 "$PY_DIR/gol_multithread.py"
GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 \
    run_perf_record "py_thread_4t" python3 "$PY_DIR/gol_multithread.py"

section "Python Threading: escalabilidade 1/2/4/8 threads (3.6.3)"
GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$SCALE_ITER \
    scalability_sweep "py_thread" "GOL_WORKERS" python3 "$PY_DIR/gol_multithread.py"

# ============================================================
# 9. PYTHON MULTIPROCESSING - DUAS VERSOES (3.7)
# ============================================================
# Versao A: gol_multiprocess.py            (Pipe, colunas, mensagens)
# Versao B: gol_multiprocess_shared_memory.py (shared_memory, colunas)

for VARIANT in "gol_multiprocess.py:mp_pipe" "gol_multiprocess_shared_memory.py:mp_shm"; do
    SCRIPT_NAME="${VARIANT%%:*}"
    TAG="${VARIANT##*:}"
    SCRIPT_PATH="$PY_DIR/$SCRIPT_NAME"

    section "Python Multiprocessing [$TAG = $SCRIPT_NAME]: cProfile com 4 processos (3.7.1)"
    GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 \
        python3 -m cProfile -s cumulative "$SCRIPT_PATH" > "$LOG_DIR/py_${TAG}_4p_cprofile.txt" 2>&1

    section "Python Multiprocessing [$TAG]: perf stat/record com 4 processos (3.7.2)"
    GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 \
        run_perf_stat "py_${TAG}_4p" python3 "$SCRIPT_PATH"
    GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$GOL_ITER GOL_WORKERS=4 \
        run_perf_record "py_${TAG}_4p" python3 "$SCRIPT_PATH"

    section "Python Multiprocessing [$TAG]: escalabilidade 1/2/4/8 processos (3.7.3)"
    GOL_W=$GOL_W GOL_H=$GOL_H GOL_ITER=$SCALE_ITER \
        scalability_sweep "py_${TAG}" "GOL_WORKERS" python3 "$SCRIPT_PATH"
done

# ============================================================
# 10. COMPACTAR perf.data (requisito 4.2)
# ============================================================

section "Compactando arquivos perf.data"
if [ "$HAVE_PERF" -eq 1 ] && ls "$PERF_DIR"/*.perf.data >/dev/null 2>&1; then
    tar -C "$PERF_DIR" -czf "$OUT_DIR/perf_data_all.tar.gz" $(cd "$PERF_DIR" && ls *.perf.data)
    echo "  gerado: $OUT_DIR/perf_data_all.tar.gz"
else
    echo "  [AVISO] nenhum perf.data encontrado para compactar (perf indisponivel ou falhou em todas as etapas)"
fi

# ============================================================
# 11. LIMPEZA DOS .pbm gerados durante os runs (opcional)
# ============================================================

rm -f "$WORK_DIR"/gol_*.pbm

section "Concluido"
echo "Resultados em: $OUT_DIR"
echo "  - $CSV_TIME_V        (tabela comparativa /usr/bin/time -v, requisito 3.2)"
echo "  - $CSV_SCALE          (dados brutos de escalabilidade 1/2/4/8, requisitos 3.4.2/3.6.3/3.7.3)"
echo "  - $LOG_DIR/            (gprof, cProfile, strace, stdout de cada run)"
echo "  - $PERF_DIR/           (perf stat .log, perf report .txt, *.perf.data)"
echo "  - $VALGRIND_DIR/       (callgrind/cachegrind, com annotate se as ferramentas *_annotate existirem)"
echo
echo "Lembrete: calcule speedup/eficiencia a partir de $CSV_SCALE (ex.: com pandas ou planilha)"
echo "e monte as tabelas comparativas pedidas nas secoes 3.7.4 e 3.8 a partir de $CSV_TIME_V."