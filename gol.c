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

   // Cabeçalho obrigatório do formato PBM (P1 = texto, seguido de largura e altura)
  // fprintf(f, "P1\n%d %d\n", w, h);
   
   // Escreve os pixels (1 para vivo, 0 para morto)
   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         fprintf(f, "%d ", univ[y][x] ? 1 : 0);
      }
      fprintf(f, "\n");
   }
   
   fclose(f);
}


// desenhar a matriz diretamente no terminal.
void show(void *u, int w, int h)
{
   int (*univ)[w] = u;
   printf("\033[H"); // Retorna o cursor para o topo (canto superior esquerdo)
   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         // Imprime um bloco branco se vivo, ou espaços vazios se morto
         printf(univ[y][x] ? "\033[07m  \033[m" : "  ");
      }
      printf("\033[E"); // Pula para a próxima linha
   }
   fflush(stdout);
}

void evolve(void *u, int w, int h)
{
   unsigned (*univ)[w] = u;
   unsigned new[h][w];

   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         int n = 0;
         for (int y1 = y - 1; y1 <= y + 1; y1++) {
            for (int x1 = x - 1; x1 <= x + 1; x1++) {
               if (univ[(y1 + h) % h][(x1 + w) % w]) {
                  n++;
               }
            }
         }

         if (univ[y][x]) n--;
         new[y][x] = (n == 3 || (n == 2 && univ[y][x]));
      }
   }

   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         univ[y][x] = new[y][x];
      }
   }
}

// A função game recebe o total de iterações e a frequência (XX)
void game(int w, int h, int max_iter, int print_freq)
{
   unsigned univ[h][w];
   
   // Inicialização aleatória
   for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
         univ[y][x] = rand() < RAND_MAX / 10 ? 1 : 0;
      }
   }

   // Limpa a tela do terminal uma vez caso vá usar a função show
   printf("\033[2J"); 

   // Substituição do while(1) por um laço iterativo
   for (int iter = 0; iter <= max_iter; iter++) {
      
      /* =======================================================================
       * LEMBRETE PARA O TRABALHO DE PROFILING:
       * Quando for executar testes rigorosos de profiling de CPU (como gprof, 
       * perf ou callgrind), lembre-se de TESTAR TAMBÉM COMENTANDO AS LINHAS ABAIXO.
       * 
       * Motivo: Operações de gravação de arquivos no disco (I/O) são extremamente
       * lentas comparadas ao processador. Deixar a gravação ativada "sujará" 
       * os seus resultados de tempo e métricas, dificultando a análise exigida 
       * para identificar se a aplicação é puramente CPU-bound ou I/O-bound.
       * ======================================================================= */
       
      // Verifica se é o momento de imprimir a placa (múltiplo de XX)
      //if (iter % print_freq == 0) {
         //save_pbm(univ, w, h, iter);
         
        // mostrar a evolução no terminal (opcional, mas útil para visualização)
          //show(univ, w, h);
         // usleep(200000); 
    //  }
      
      evolve(univ, w, h);
   }
}

int main(int argc, char **argv)
{
   int w = 30, h = 30;
   int max_iter = 100;   // Valor padrão de iterações totais
   int print_freq = 10;  // Valor padrão para o parâmetro XX

   // Coleta de argumentos via linha de comando
   if (argc > 1) w = atoi(argv[1]);
   if (argc > 2) h = atoi(argv[2]);
   if (argc > 3) max_iter = atoi(argv[3]);
   if (argc > 4) print_freq = atoi(argv[4]);

   // Tratamento para evitar dimensões zeradas ou negativas
   if (w <= 0) w = 30;
   if (h <= 0) h = 30;
   if (max_iter < 0) max_iter = 100;
   if (print_freq <= 0) print_freq = 1;

   // adicionado uma semente randômica baseada no tempo para gerar matrizes diferentes a cada execução
   srand(time(NULL));

   // Estruturas de tempo obrigatórias para validação (Adicionado)
   struct timespec start, end;

   // Captura o tempo EXATAMENTE ANTES do processamento iniciar (Adicionado)
   clock_gettime(CLOCK_MONOTONIC, &start);

   // Chama a função principal
   game(w, h, max_iter, print_freq);

   // Captura o tempo EXATAMENTE APÓS o processamento terminar (Adicionado)
   clock_gettime(CLOCK_MONOTONIC, &end);

   // Calcula o tempo total combinando segundos e nanossegundos (Adicionado)
   double time_taken = (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1000000000.0;

   // Imprime o tempo de validação exigido pela atividade (Adicionado)
   printf("Tempo interno de execucao: %f segundos\n", time_taken);
   
   return 0;
}
