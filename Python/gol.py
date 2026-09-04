import random
import time

def evolve(univ, w, h):
    # Cria uma matriz temporária para armazenar o próximo estado
    new = [[0 for _ in range(w)] for _ in range(h)]

    # Varredura completa da matriz
    for y in range(h):
        for x in range(w):
            n = 0
            
            # Laços internos para inspecionar a vizinhança 3x3
            for y1 in range(y - 1, y + 2):
                for x1 in range(x - 1, x + 2):
                    # Verifica se a célula vizinha está viva, usando módulo para tabuleiro infinito
                    if univ[(y1 + h) % h][(x1 + w) % w]:
                        n += 1

            # Desconta a própria célula caso ela esteja viva
            if univ[y][x]:
                n -= 1
            
            # Aplica as regras de sobrevivência e nascimento
            if n == 3 or (n == 2 and univ[y][x]):
                new[y][x] = 1
            else:
                new[y][x] = 0

    # Segunda passagem para copiar o estado calculado de volta para a matriz original
    for y in range(h):
        for x in range(w):
            univ[y][x] = new[y][x]

def game(w, h, max_iter):
    # Inicialização aleatória (aprox. 10% de chance de estar viva)
    univ = [[1 if random.random() < 0.1 else 0 for _ in range(w)] for _ in range(h)]

    # Laço iterativo simulando o jogo
    for _ in range(max_iter + 1):
        evolve(univ, w, h)

def main():
    # Dimensões e iterações fixas
    w = 500
    h = 500
    max_iter = 5000
    
    # Captura o tempo EXATAMENTE ANTES do processamento iniciar
    start = time.perf_counter()

    # Chama a função principal
    game(w, h, max_iter)

    # Captura o tempo EXATAMENTE APÓS o processamento terminar
    end = time.perf_counter()

    # Calcula o tempo total
    time_taken = end - start

    # Imprime o tempo de validação
    print(f"Tempo interno de execucao: {time_taken:f} segundos")

if __name__ == "__main__":
    main()