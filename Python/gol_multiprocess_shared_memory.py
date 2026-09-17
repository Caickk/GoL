"""
Game of Life - multiprocessing + shared_memory

Mesma decomposicao logica do codigo original baseado em Pipe (blocos de
colunas contiguos, bordas verticais trocadas entre vizinhos), mas trocando
a troca de bordas via Pipe (serializacao a cada geracao) por leitura direta
de um bloco unico de shared_memory (sem serializacao, sem copia).

Layout do grid em memoria: row-major, achatado em bytearray, indice
(y, x) -> y*w + x (igual ao das outras versoes). Isso significa que,
embora a particao de TRABALHO seja por colunas, o ARMAZENAMENTO continua
row-major -- por isso cada worker, para ler sua faixa de colunas de uma
linha y, acessa buf[y*w + x_start : y*w + x_end], um slice contiguo
dentro da linha (nao precisa mais montar coluna por coluna via lacos
Python, que era o custo alto da versao com Pipe).
"""

import multiprocessing as mp
import os
import time
from multiprocessing import shared_memory

RULE = bytes(1 if i in (3, 19, 20) else 0 for i in range(256))
TO_ASCII = bytes((0x30 + i) if i < 2 else 0x30 for i in range(256))


# def save_pbm(buf, off, w, h, gen):
#     filename = f"gol_{gen}.pbm"
#     try:
#         with open(filename, "wb") as f:
#             f.write(b"P1\n%d %d\n" % (w, h))
#             line = bytearray(2 * w + 1)
#             line[1::2] = b" " * w
#             line[2 * w] = 0x0A
#             for y in range(h):
#                 base = off + y * w
#                 line[0:2 * w:2] = bytes(buf[base:base + w]).translate(TO_ASCII)
#                 f.write(line)
#     except IOError as e:
#         print(f"Erro ao criar o arquivo PBM: {e}")


def split_columns(w, n_tasks):
    base, extra = divmod(w, n_tasks)
    blocks, x = [], 0
    for i in range(n_tasks):
        size = base + (1 if i < extra else 0)
        blocks.append((x, x + size))
        x += size
    return blocks


def _worker(shm, w, h, x0, x1, max_iter, barrier):
    """Cada worker cuida das colunas [x0, x1) de TODAS as h linhas."""
    buf = shm.buf
    plane = w * h
    cur_off, nxt_off = 0, plane
    local_w = x1 - x0
    rule = RULE

    for _gen in range(max_iter):
        for y in range(h):
            row_base = cur_off + y * w
            up_base = cur_off + ((y - 1) % h) * w
            dn_base = cur_off + ((y + 1) % h) * w
            out_base = nxt_off + y * w

            for x in range(x0, x1):
                n = 0
                for yy_base in (up_base, row_base, dn_base):
                    left_x = (x - 1) % w
                    right_x = (x + 1) % w
                    n += buf[yy_base + left_x]
                    n += buf[yy_base + x]
                    n += buf[yy_base + right_x]
                # n aqui ja e o "total" (soma das 9 celulas, incluindo a
                # propria, que entra uma vez via buf[row_base + x]).
                # RULE foi construida para indice = total + 16*self.
                idx = n + (buf[row_base + x] << 4)
                buf[out_base + x] = rule[idx]

        barrier.wait()
        cur_off, nxt_off = nxt_off, cur_off


def count_alive(shm, w, h, cur_off):
    """Reducao sem NENHUMA mensagem entre processos: como o buffer e
    compartilhado, o processo pai le e soma diretamente, sem precisar
    que os workers mandem nada de volta - diferente da versao com Pipe,
    onde cada worker precisa enviar sua soma parcial explicitamente."""
    plane = w * h
    return sum(shm.buf[cur_off:cur_off + plane])


def run(w, h, max_iter, n_tasks=None, save_interval=500):
    if n_tasks is None:
        n_tasks = os.cpu_count() or 1
    n_tasks = max(1, min(n_tasks, w))

    plane = w * h
    shm = shared_memory.SharedMemory(create=True, size=2 * plane)
    try:
        buf = shm.buf
        buf[0:plane] = bytes(plane)
        row_mid = bytearray(w)
        for x in range(w):
            row_mid[x] = 1
        buf[(h // 2) * w:(h // 2) * w + w] = row_mid
        xc = w // 2
        for y in range(h):
            buf[y * w + xc] = 1

        # if save_interval:
        #     save_pbm(buf, 0, w, h, 0)

        barrier = mp.Barrier(n_tasks + 1)
        blocks = split_columns(w, n_tasks)

        procs = [
            mp.Process(target=_worker,
                       args=(shm, w, h, x0, x1, max_iter, barrier))
            for (x0, x1) in blocks
        ]
        for p in procs:
            p.start()

        cur_off = 0
        for gen in range(max_iter):
            barrier.wait()
            cur_off = plane - cur_off
            # if save_interval and (gen + 1) % save_interval == 0:
            #     save_pbm(buf, cur_off, w, h, gen + 1)

        for p in procs:
            p.join()

        final_alive = count_alive(shm, w, h, cur_off)

        del buf
    finally:
        shm.close()
        shm.unlink()

    return final_alive


def main():
    w = int(os.environ.get("GOL_W", 500))
    h = int(os.environ.get("GOL_H", 500))
    max_iter = int(os.environ.get("GOL_ITER", 5000))
    n_tasks = int(os.environ.get("GOL_WORKERS", 4))
    interval = int(os.environ.get("GOL_SAVE", 500))

    print(f"Executando com {n_tasks} tarefas (blocos de colunas, shared_memory), "
          f"grade {w}x{h}, {max_iter} geracoes...")

    start = time.perf_counter()
    final_alive = run(w, h, max_iter, n_tasks=n_tasks, save_interval=interval)
    end = time.perf_counter()

    print(f"Total de celulas vivas ao final: {final_alive}")
    print(f"Tempo interno de execucao: {end - start:f} segundos")


if __name__ == "__main__":
    mp.set_start_method("fork")
    main()