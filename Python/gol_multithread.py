import random
import time
from concurrent.futures import ThreadPoolExecutor

def process_chunk(univ, new, w, h, start_y, end_y):
    """Calcula o próximo estado para um bloco de linhas."""
    for y in range(start_y, end_y):
        for x in range(w):
            n = 0
            
            for y1 in range(y - 1, y + 2):
                for x1 in range(x - 1, x + 2):
                    if univ[(y1 + h) % h][(x1 + w) % w]:
                        n += 1

            if univ[y][x]:
                n -= 1
            
            if n == 3 or (n == 2 and univ[y][x]):
                new[y][x] = 1
            else:
                new[y][x] = 0

def copy_chunk(univ, new, w, start_y, end_y):
    """Copia o novo estado de volta para a matriz original para o bloco correspondente."""
    for y in range(start_y, end_y):
        for x in range(w):
            univ[y][x] = new[y][x]

def evolve_mt(univ, w, h, executor, num_threads):
    new = [[0 for _ in range(w)] for _ in range(h)]
    
    chunk_size = h // num_threads
    futures = []
    
    # Fase 1: Calcula o próximo estado em paralelo
    for i in range(num_threads):
        start_y = i * chunk_size
        # Garante que a última thread pegue qualquer resto de divisão
        end_y = h if i == num_threads - 1 else (i + 1) * chunk_size
        futures.append(executor.submit(process_chunk, univ, new, w, h, start_y, end_y))
        
    # Sincroniza as threads antes de iniciar a cópia
    for f in futures:
        f.result()
        
    # Fase 2: Copia o estado calculado de volta em paralelo
    futures = []
    for i in range(num_threads):
        start_y = i * chunk_size
        end_y = h if i == num_threads - 1 else (i + 1) * chunk_size
        futures.append(executor.submit(copy_chunk, univ, new, w, start_y, end_y))
        
    for f in futures:
        f.result()

def game(w, h, max_iter, num_threads):
    # Inicialização aleatória com ~10% de chance de célula viva, igual à versão serial
    univ = [[1 if random.random() < 0.1 else 0 for _ in range(w)] for _ in range(h)]

    # Inicializa o executor fora do laço para não recriar threads a cada geração
    with ThreadPoolExecutor(max_workers=num_threads) as executor:
        for _ in range(max_iter + 1):
            evolve_mt(univ, w, h, executor, num_threads)

def main():
    # Dimensões e iterações mantidas conforme a versão original
    w = 500
    h = 500
    max_iter = 5000
    num_threads = 4 # Você pode ajustar este número com base nos núcleos lógicos da máquina
    
    start = time.perf_counter()

    game(w, h, max_iter, num_threads)

    end = time.perf_counter()
    time_taken = end - start

    print(f"Tempo interno de execucao (Multithread): {time_taken:f} segundos")

if __name__ == "__main__":
    main()