/***********************************************************************
 * BFS.c
 *
 * Description : BFS using CSR Format designed for FPGA platform
 **********************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <malloc.h>
#include <list>


#include <utility>
#define __NO_STD_VECTOR  // Use cl::vector and cl::string and
#define __NO_STD_STRING  // not STL versions, more on this later
#include <ctime>

#define AOCL_ALIGNMENT 64
#define UINT_MAX 0xFFFFFFFF


int debug = 0;

//Structure for Nodes in the graph
//__attribute__((packed))
//__attribute__((aligned(16)))
struct Node
{
	int starting;     //Index where the edges of the node start
	int no_of_edges;  //The degree of the node
};

typedef struct {  const char *name;
                  int  count;
                  bool wait_finish; 
                  bool suffix;} kernel_t; 

void BFSGraph(int argc, char** argv);
bool read_csr( char *filename
              ,unsigned int  **a_row
              ,unsigned int  **a_edge
              ,unsigned int  **a_dist
              ,unsigned int  **a_cost
              ,unsigned int   *nodes
              ,unsigned int   *edges);


/******************************************************************************
 * MAIN METHOD
 *****************************************************************************/
int main(int argc, char** argv)
{
	BFSGraph(argc, argv);
	return 0;
}

bool read_csr( char *filename
              ,unsigned int  **a_row
              ,unsigned int  **a_edge
              ,unsigned int  **a_dist
              ,unsigned int  **a_cost
              ,unsigned int   *nodes
              ,unsigned int   *edges) {
    FILE *f;
    char command;
    char comment_buffer[200];
    char statement[10];
    int  source, dest, weight;

    int count_node=0;
    int current_node  = 0;
    int curr_pointer  = 0;


    f = fopen(filename, "r");

    if(!f) {
        printf("Filename %s does not exist", filename);
        return false;
    }

    while(fscanf(f,"%c", &command) != EOF) {
        fgets(comment_buffer, 200, f);
        switch(command) {
            case 'c' :
                //printf("Comment ");
                //printf(": %s", comment_buffer);
                break;
            case 'p' :
                sscanf(comment_buffer, "%s %d %d", statement, nodes, edges);
                *a_row = (unsigned int *) memalign (AOCL_ALIGNMENT, sizeof(int) * (*nodes + 1)); //Last element has NNZ + 1
                *a_edge =(unsigned int *) memalign (AOCL_ALIGNMENT, sizeof(int) * *edges);
                *a_dist = (unsigned int *) memalign (AOCL_ALIGNMENT, sizeof(int) * *edges);
                *a_cost = (unsigned int *) memalign (AOCL_ALIGNMENT, sizeof(int) * *nodes);
                for(int i = 0; i < *nodes; i++)
                    (*a_cost)[i] = 0;
                printf("Statement %s Has %d nodes and %0d edges\n", 
                        statement, *nodes, *edges);
                break;
            case 'a' :
                //printf("Edge : ");
                sscanf(comment_buffer, "%d %d %d", &source, &dest, &weight);
                while(source != current_node) {
                    (*a_row)[current_node] = curr_pointer;
                    current_node++;
                }
                (*a_edge)[curr_pointer] = dest;
                (*a_dist)[curr_pointer] = weight;
                curr_pointer++;
                //printf("S = %0d, D = %0d, Weight = %0d CP= %0d CN=%0d\n",
                //        source, dest, weight , curr_pointer,current_node);
                break;
        }
    }
    while(*nodes >= current_node) {
        (*a_row)[current_node] = curr_pointer;
        current_node++;
    }

    return true;
}

void top_down_step(std::list<int> &frontier
                  ,std::list<int> *next
                  ,unsigned int  *a_row
                  ,unsigned int  *a_dist
                  ,unsigned int  *a_edge
                  ,unsigned int  *visited
                  ,unsigned int   iter) {

    while(!frontier.empty()) {
        int vertex;
        int edge_size_for_vertex;
        int edge_start_pointer;
        vertex = frontier.front();
        frontier.pop_front();
        edge_size_for_vertex = a_row[vertex] - a_row[vertex-1];
        edge_start_pointer = a_row[vertex - 1];
        for(int i = 0; i < edge_size_for_vertex; i++) {
        int child_node;
            child_node = a_edge[edge_start_pointer+i];
            if(!visited[child_node - 1]) {
                visited[child_node - 1] = iter;
                next->push_back(child_node);
            }
        }
    }
}


 void serial_bfs ( unsigned int source
                  ,unsigned int *a_row
                  ,unsigned int *a_edge
                  ,unsigned int *a_dist
                  ,unsigned int *visited
                  ,unsigned int  nodes) {

    std::list<int> frontier;
    std::list<int> *next;
    int  level = 1;
    if (source == 0) { 
        printf("-ERROR- Source shall be non-zero, Check the args. Exiting...\n");
        exit(1);
    }
       


    for(int i = 0 ; i < nodes; i++) {
        visited[i] = 0;
    }
    visited[source-1] = level;
    frontier.push_back(source);
    while(frontier.size()) {
        level++;
        next = new std::list<int>;
        //printf("Starting Top Down\n");
        top_down_step(frontier, next, a_row, a_dist, a_edge, visited,level);
        frontier = *next;
        delete next;
    }
    //for(int i = 0; i < nodes; i++)
    //    printf("Node %0d Parent = %0d\n", i+1,visited[i]);

    frontier.~list();
 }



/******************************************************************************
 * Apply BFS on a Graph using OpenCL
 *****************************************************************************/
void BFSGraph(int argc, char ** argv)
{
    unsigned int *a_dist; //Distance
    unsigned int *a_row;  //Row Pointer in CSR
    unsigned int *a_edge; //Edge to given node
    unsigned int *a_cost; //Node traversal information,distance from source
    unsigned int *a_serial_dist;
    unsigned int edges;
    unsigned int nodes;
    unsigned int source;


	if(argc < 2)
	{
		printf("Usage: <filename>\n");
        printf("Args 0: %s ::1 : %s ::2 : %s\n", argv[0], argv[1], argv[2]);
		exit(1);
	}

    source = atoi(argv[2]);


    //Read the graphs and put it in CSR format. Currently takes a sorted list of edges generated from GTGraphs
    read_csr(argv[1], &a_row, &a_edge, &a_dist, &a_cost, &nodes, &edges);

    //Just print out the CSR nodes, for debug purposes
    if(debug) {
        int curr_pointer = 0;
        for(int i = 0; i < nodes; i++) {
            printf("--------------------------------\n");
            printf("Vertex[%0d] = %0d %0d\n", i,a_row[i], a_row[i+1]);
            for(int j = 0; j < a_row[i+1]- a_row[i]; j++) {
                printf("Edge S = %0d D = %0d W = %0d\n",
                        i+1, a_edge[curr_pointer], a_dist[curr_pointer]);
                curr_pointer++;
            }
            printf("--------------------------------\n");
        }
    }

    a_serial_dist = (unsigned int *) memalign (AOCL_ALIGNMENT, sizeof(int) * nodes);

    //DO a serial traversal of Graph
    struct ocdHostTimer *host_timer;
    clock_t start_serial = clock();
    //START_HOST_TIMER(OCD_TIMER_HOST, host_timer)
    serial_bfs ( source ,a_row ,a_edge ,a_dist ,a_serial_dist ,nodes);
    //END_HOST_TIMER(host_timer)
    clock_t end_serial = clock();
    printf("Serial BFS done, time taken %d\n", end_serial - start_serial);

}
