#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

// Função para gerar o arquivo PBM
void save_pbm(void *u, int w, int h, int iter)
{
   int (*univ)[w] = u;
   char filename[64];
   
   // Formata o nome do arquivo para gol_nn.pbm (ex: gol_0, gol_10, gol_20)
   sprintf(filename, "gol_%d.pbm", iter);
   
   FILE *f = fopen(filename, "w");
   if (!f) {
      perror("Erro ao criar o arquivo PBM");
      return;
   }
}
// Função principal que calcula a próxima geração do Game of Life.
// Por ser executada a cada iteração, este é o "hotspot" do programa.
void evolve(void *u, int w, int h)
{
   // Faz o cast do ponteiro genérico 'u' para uma matriz bidimensional de dimensões h x w.
   unsigned (*univ)[w] = u;
   
   // Aloca uma matriz temporária na stack para armazenar o próximo estado.
   // Isso é necessário porque as regras do jogo exigem que a matriz original 
   // permaneça inalterada enquanto os cálculos da geração atual estão sendo feitos.
   unsigned new[h][w];

   // Varredura completa da matriz, célula por célula (eixo Y e eixo X).
   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         
         int n = 0; // Contador de vizinhos vivos para a célula atual (y, x)
         
         // Laços internos para inspecionar a vizinhança 3x3 ao redor da célula.
         for (int y1 = y - 1; y1 <= y + 1; y1++) {
            for (int x1 = x - 1; x1 <= x + 1; x1++) {
               
               // Verifica se a célula vizinha está viva.
               // O uso da operação de módulo (%) com a soma (+ h / + w) cria um 
               // "tabuleiro infinito" (array toroidal). Se passar da borda direita, 
               // reaparece na esquerda.
               // Atenção (Profiling): A operação de módulo (%) na CPU é matematicamente 
               // cara (equivale a uma divisão), e aqui ela é executada 9 vezes por célula.
               if (univ[(y1 + h) % h][(x1 + w) % w]) {
                  n++;
               }
            }
         }

         // Como o laço 3x3 acima incluiu a própria célula (y, x) na contagem caso 
         // ela estivesse viva, precisamos descontá-la para ter apenas os vizinhos reais.
         if (univ[y][x]) n--;
         
         // Aplica as regras matemáticas de sobrevivência e nascimento do Game of Life:
         // - Uma célula viva sobrevive se tiver 2 ou 3 vizinhos (n == 2 && univ[y][x] ou n == 3).
         // - Uma célula morta nasce se tiver exatamente 3 vizinhos (n == 3).
         // O resultado (1 para vivo, 0 para morto) é salvo na matriz temporária.
         new[y][x] = (n == 3 || (n == 2 && univ[y][x]));
      }
   }

   // Segunda passagem pela matriz inteira.
   // Copia o estado calculado da matriz temporária 'new' de volta para a matriz original 'univ'.
   // Atenção (Profiling): Esta é uma operação intensa de acesso à memória (Memory Bound).
   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         univ[y][x] = new[y][x];
      }
   }
}

// A função game recebe largura e altura da matriz, o total de iterações 
void game(int w, int h, int max_iter)
{
   unsigned univ[h][w];
   
   // Inicialização aleatória
   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         univ[y][x] = rand() < RAND_MAX / 10 ? 1 : 0;
      }
   }

   
   // Substituição do while(1) por um laço iterativo
   const int save_interval = 500; // Salva a cada 500 iterações
   for (int iter = 0; iter <= max_iter; iter++) {
      if (iter % save_interval == 0) {
         save_pbm(univ, w, h, iter);
      }
      evolve(univ, w, h);
   }
}

int main(void)
{
   // Dimensões e iterações fixas
   int w = 500;
   int h = 500;
   int max_iter = 5000;
   
   // Semente randômica baseada no tempo para gerar matrizes diferentes a cada execução
   srand(time(NULL));

   // Estruturas de tempo obrigatórias para validação
   struct timespec start, end;

   // Captura o tempo EXATAMENTE ANTES do processamento iniciar
   clock_gettime(CLOCK_MONOTONIC, &start);

   // Chama a função principal
   game(w, h, max_iter);

   // Captura o tempo EXATAMENTE APÓS o processamento terminar
   clock_gettime(CLOCK_MONOTONIC, &end);

   // Calcula o tempo total combinando segundos e nanossegundos
   double time_taken = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1000000000.0;

   // Imprime o tempo de validação exigido pela atividade
   printf("Tempo interno de execucao: %f segundos\n", time_taken);
   
   return 0;
}
