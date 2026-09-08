import multiprocessing as mp
import os
import random
import time


def _split_columns(w, n_tasks):
    """Divide as w colunas do tabuleiro em n_tasks blocos contíguos [x_start, x_end)."""
    base = w // n_tasks
    extra = w % n_tasks
    blocks = []
    x = 0
    for i in range(n_tasks):
        size = base + (1 if i < extra else 0)
        blocks.append((x, x + size))
        x += size
    return blocks


def _worker(task_id, n_tasks, local_w, h, max_iter,
            init_cols, left_conn, right_conn, result_conn):
    """
    Executa a simulação completa para o bloco de colunas [x_start, x_end)
    deste worker, por max_iter+1 gerações.

    Requisito (a): cada tarefa possui seu PRÓPRIO bloco contíguo de colunas
    (init_cols já vem recortado do tabuleiro global antes de chegar aqui).

    Requisito (b): todas as colunas do bloco são atualizadas de forma
    independente, exceto pela borda, que depende de uma coluna "fantasma"
    (ghost column) vinda da tarefa vizinha.

    Requisito (c): a cada geração, a tarefa troca sua coluna da esquerda e
    da direita com as tarefas vizinhas (left_conn / right_conn). Como o
    tabuleiro é periódico, a tarefa 0 e a tarefa (n_tasks-1) são vizinhas
    entre si — essa topologia de anel já é montada pelo processo
    coordenador antes de disparar os workers (ver run_parallel_columns).
    """
    # cur[y][x] / nxt[y][x]: matriz local (h linhas x local_w colunas).
    cur = init_cols
    nxt = [[0] * local_w for _ in range(h)]

    for _gen in range(max_iter + 1):

        if n_tasks == 1:
            # Caso degenerado: uma única tarefa é vizinha dela mesma (anel
            # de tamanho 1). A coluna fantasma da esquerda é a própria
            # última coluna do bloco, e vice-versa -- sem necessidade de
            # comunicação entre processos.
            left_ghost = [cur[y][local_w - 1] for y in range(h)]
            right_ghost = [cur[y][0] for y in range(h)]
        else:
            # --- Requisito (c): comunicação com a tarefa vizinha ---
            # Colunas de borda enviadas aos vizinhos. Para h na ordem de
            # centenas/poucos milhares, o payload é pequeno o bastante
            # para caber no buffer interno do Pipe sem bloquear o send();
            # por isso é seguro mandar antes de receber, sem risco de
            # deadlock. (Para tabuleiros muito maiores, alternar a ordem
            # de send/recv entre tarefas pares/ímpares seria mais seguro.)
            left_col = [cur[y][0] for y in range(h)]
            right_col = [cur[y][local_w - 1] for y in range(h)]

            left_conn.send(left_col)
            right_conn.send(right_col)

            left_ghost = left_conn.recv()    # última coluna da tarefa à esquerda
            right_ghost = right_conn.recv()  # primeira coluna da tarefa à direita

        # --- Requisito (b): atualização independente do bloco de colunas ---
        # A dimensão Y (linhas) é sempre local e completa (não houve corte
        # por linha), então o wraparound vertical usa módulo normalmente.
        # A dimensão X só precisa das colunas fantasmas nas bordas x=0 e
        # x=local_w-1; todas as colunas internas são 100% independentes.
        for y in range(h):
            for x in range(local_w):
                n = 0
                for dy in (-1, 0, 1):
                    yy = (y + dy) % h
                    for dx in (-1, 0, 1):
                        xx = x + dx
                        if xx < 0:
                            val = left_ghost[yy]
                        elif xx >= local_w:
                            val = right_ghost[yy]
                        else:
                            val = cur[yy][xx]
                        if val:
                            n += 1
                if cur[y][x]:
                    n -= 1
                nxt[y][x] = 1 if (n == 3 or (n == 2 and cur[y][x])) else 0

        cur, nxt = nxt, cur  # ping-pong local de buffers

    if result_conn is not None:
        result_conn.send(cur)
        result_conn.close()
    if left_conn is not None:
        left_conn.close()
    if right_conn is not None:
        right_conn.close()


def run_parallel_columns(w, h, max_iter, n_tasks=None, gather_result=False):
    """
    Monta a topologia em anel (necessária pois o tabuleiro é periódico),
    distribui os blocos de colunas e executa a simulação em paralelo.
    """
    if n_tasks is None:
        n_tasks = os.cpu_count() or 1
    n_tasks = max(1, min(n_tasks, w))  # não faz sentido ter mais tarefas que colunas

    col_blocks = _split_columns(w, n_tasks)

    # Geração única do estado inicial (mesma semente lógica para todas as
    # tarefas, evitando que o resultado mude dependendo de quantas tarefas
    # forem usadas). Recorta o tabuleiro global em blocos de colunas.
    full_init = [[1 if random.random() < 0.1 else 0 for _ in range(w)] for _ in range(h)]
    init_blocks = []
    for (x_start, x_end) in col_blocks:
        block = [[full_init[y][x] for x in range(x_start, x_end)] for y in range(h)]
        init_blocks.append(block)

    # --- Topologia em anel: uma Pipe por aresta (tarefa i <-> tarefa i+1) ---
    # edge[i] liga a tarefa i (lado "direita") à tarefa (i+1) % n_tasks (lado "esquerda").
    # Como o tabuleiro é periódico, a última aresta conecta a última tarefa
    # de volta à primeira, fechando o anel.
    right_ends = [None] * n_tasks   # right_ends[i]: ponta que a tarefa i usa para falar com a tarefa à direita
    left_ends = [None] * n_tasks    # left_ends[i]: ponta que a tarefa i usa para falar com a tarefa à esquerda

    if n_tasks > 1:
        for i in range(n_tasks):
            a, b = mp.Pipe(duplex=True)
            right_ends[i] = a                  # tarefa i fala com sua direita por aqui
            left_ends[(i + 1) % n_tasks] = b   # tarefa (i+1) fala com sua esquerda por aqui

    result_parent_conns = [None] * n_tasks
    result_child_conns = [None] * n_tasks
    if gather_result:
        for i in range(n_tasks):
            p_conn, c_conn = mp.Pipe(duplex=False)
            result_parent_conns[i] = p_conn
            result_child_conns[i] = c_conn

    processes = []
    for i in range(n_tasks):
        local_w = col_blocks[i][1] - col_blocks[i][0]
        proc = mp.Process(
            target=_worker,
            args=(i, n_tasks, local_w, h, max_iter,
                  init_blocks[i], left_ends[i], right_ends[i], result_child_conns[i]),
        )
        processes.append(proc)

    for proc in processes:
        proc.start()

    # Fecha no processo pai as pontas que só os filhos devem usar.
    for i in range(n_tasks):
        if result_child_conns[i] is not None:
            result_child_conns[i].close()

    final_board = None
    if gather_result:
        final_board = [[0] * w for _ in range(h)]
        for i, (x_start, x_end) in enumerate(col_blocks):
            block = result_parent_conns[i].recv()
            for y in range(h):
                for j, x in enumerate(range(x_start, x_end)):
                    final_board[y][x] = block[y][j]

    for proc in processes:
        proc.join()

    return final_board


def main():
    # Dimensões e iterações fixas (mesmos parâmetros das versões anteriores).
    w = 500
    h = 500
    max_iter = 5000
    n_tasks = os.cpu_count() or 1       #Vai precisar trocar o n_tasks para (1,2,4,8) para testar o speedup

    print(f"Executando com {n_tasks} tarefas (blocos de colunas), "
          f"grade {w}x{h}, {max_iter} gerações...")

    start = time.perf_counter()

    run_parallel_columns(w, h, max_iter, n_tasks=n_tasks, gather_result=False)

    end = time.perf_counter()
    time_taken = end - start

    print(f"Tempo interno de execucao: {time_taken:f} segundos")


if __name__ == "__main__":
    main()