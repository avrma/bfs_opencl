/***********************************************************************
 * BFS.c
 *
 * Author: Anshuman Verma
 * Email : anshuman@vt.edu
 * Date  : Apr 20th, 2016
 * Description : BFS using CSR Format designed for FPGA platform
 **********************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <malloc.h>
#include <list>

#include "rdtsc.h"
#include "common_args.h"

#include <utility>
#define __NO_STD_VECTOR  // Use cl::vector and cl::string and
#define __NO_STD_STRING  // not STL versions, more on this later
#include <ctime>

#define AOCL_ALIGNMENT 64
#define UINT_MAX 0xFFFFFFFF

#define TIME_RECORD(EVENT,TIMER_TAG,TYPE,TIMER_POINTER) \
    clFinish(commands); \
	//START_TIMER(EVENT, TIMER_TAG, TYPE, TIMER_POINTER) \
	//END_TIMER(ocdTempTimer)

#define CHECK_CL_ERROR(E,MSG) \
    if(E != CL_SUCCESS)   \
        printf("Error(code:%0d): %s", E,MSG);

#define NO_OF_GPE 4

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
	ocd_init(&argc, &argv, NULL);
	ocd_initCL();
	BFSGraph(argc, argv);
	ocd_finalize();
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


    for(int i = 0 ; i < nodes; i++) {
        visited[i] = 0;
    }
    visited[source-1] = level;
    frontier.push_back(source);
    while(frontier.size()) {
        level++;
        next = new std::list<int>;
        top_down_step(frontier, next, a_row, a_dist, a_edge, visited,level);
        frontier = *next;
        delete next;
    }
    //for(int i = 0; i < nodes; i++)
    //    printf("Node %0d Parent = %0d\n", i+1,visited[i]);

    frontier.~list();
 }


int get_kernel_count(const kernel_t *k, int count) { 
    int k_num=0; 
    for(int i = 0; i < count; i++) { 
        k_num += k[i].count;
    }
    return k_num;
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
    char aocx_file[100];
    unsigned int source;

    const int kernel_count = 5;

    const kernel_t kernel_info[] = { 
                  { "master_bfs_",    NO_OF_GPE, false, true},
                  { "get_next_frnt_", NO_OF_GPE, false, true},
                  { "get_row_",       NO_OF_GPE, false, true},
                  { "get_neighbors_", NO_OF_GPE, true,  true},
                  { "bit_map_array",  1,         false, false}
                  };

    cl_program        bfs_program;
    cl_kernel        *kernels;
    cl_command_queue *queues;
    cl_int            error;
    unsigned int      no_of_kernels;

	if(argc < 2)
	{
		printf("Usage: <filename>\n");
		exit(1);
	}

    source = atoi(argv[4]);
    strcpy(aocx_file,argv[2]);

    no_of_kernels = get_kernel_count(kernel_info,kernel_count);

    printf("Total Kernels = %0d\n", no_of_kernels);

    kernels = (cl_kernel *) malloc(sizeof(cl_kernel)*no_of_kernels);
    queues  = (cl_command_queue *) malloc(sizeof(cl_command_queue)*no_of_kernels);

    //Read the graphs and put it in CSR format. Currently takes a sorted list of edges generated from GTGraphs
    read_csr(argv[3], &a_row, &a_edge, &a_dist, &a_cost, &nodes, &edges);

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
    //serial_bfs ( source ,a_row ,a_edge ,a_dist ,a_serial_dist ,nodes);
    //END_HOST_TIMER(host_timer)
    clock_t end_serial = clock();


    //Build device program
    bfs_program = ocdBuildProgramFromFile(context,
                                          device_id,
                                          aocx_file,
                                          NULL);


    //Create the memory buffers for device
    cl_mem d_row = clCreateBuffer(context,
                                  CL_MEM_READ_ONLY,
                                  sizeof(int) * (nodes + 1),
                                  NULL,
                                  &error);
    CHECK_CL_ERROR(error,"Did not create buffer node")

    cl_mem d_edge = clCreateBuffer(context,
                                   CL_MEM_READ_ONLY,
                                   sizeof(int) * edges,
                                   NULL, 
                                   &error);
    CHECK_CL_ERROR(error,"Did not create buffer edge")

    cl_mem d_buf0 = clCreateBuffer(context,
                                   CL_MEM_READ_WRITE,
                                   sizeof(int) * nodes,
                                   NULL,
                                   &error);
    CHECK_CL_ERROR(error,"Did not create buffer buf0")

    cl_mem d_buf1 = clCreateBuffer(context,
                                   CL_MEM_READ_WRITE,
                                   sizeof(int) * nodes,
                                   NULL , &error);
    CHECK_CL_ERROR(error,"Did not create buffer buf1")

    cl_mem d_cost = clCreateBuffer(context,
                                   CL_MEM_READ_WRITE,
                                   sizeof(int) * nodes,
                                   NULL , &error);
    CHECK_CL_ERROR(error,"Did not create buffer hier")
        //
    //Transfer the buffer data to device
	clEnqueueWriteBuffer(commands,
                         d_buf0,
                         CL_TRUE,
                         0,
                         sizeof(int) * (nodes),
                         a_row,
                         0,
                         NULL,
                         &ocdTempEvent);
 //   TIME_RECORD(ocdTempEvent,OCD_TIMER_H2D,"Bfs Graph Copy", ocdTempTimer)

    //Transfer the buffer data to device
	clEnqueueWriteBuffer(commands,
                         d_buf1,
                         CL_TRUE,
                         0,
                         sizeof(int) * (nodes),
                         a_row,
                         0,
                         NULL,
                         &ocdTempEvent);
 //   TIME_RECORD(ocdTempEvent,OCD_TIMER_H2D,"Bfs Graph Copy", ocdTempTimer)


    //Transfer the buffer data to device
	clEnqueueWriteBuffer(commands,
                         d_row,
                         CL_TRUE,
                         0,
                         sizeof(int) * (nodes+1),
                         a_row,
                         0,
                         NULL,
                         &ocdTempEvent);
 //   TIME_RECORD(ocdTempEvent,OCD_TIMER_H2D,"Bfs Graph Copy", ocdTempTimer)

	clEnqueueWriteBuffer(commands,
                         d_edge,
                         CL_TRUE,
                         0,
                         sizeof(int) * edges,
                         a_edge,
                         0,
                         NULL,
                         &ocdTempEvent);
 //   TIME_RECORD(ocdTempEvent,OCD_TIMER_H2D,"Bfs Graph Copy", ocdTempTimer)

	clEnqueueWriteBuffer(commands,
                         d_cost,
                         CL_TRUE,
                         0,
                         sizeof(int) * nodes,
                         a_cost,
                         0,
                         NULL,
                         &ocdTempEvent);
    TIME_RECORD(ocdTempEvent,OCD_TIMER_H2D,"Bfs Graph Copy", ocdTempTimer)

    clFinish(commands);

    for(unsigned int i = 0; i < kernel_count; i++) {
        for(unsigned int j = 0; j < kernel_info[i].count; j++) { 
            char name[30];
            unsigned int id;

            id = i*kernel_count + j;

            if(kernel_info[i].suffix) 
                sprintf(name, "%s%0d", kernel_info[i].name,j);
            else 
                strcpy(name,kernel_info[i].name);

            kernels[id] = clCreateKernel(bfs_program,
                                         name, 
                                         &error);

            CHECK_CL_ERROR(error,"Could not create Kernel")

            queues[id] = clCreateCommandQueue(context,
                                              device_id,
                                              CL_QUEUE_PROFILING_ENABLE,
                                              &error);
            CHECK_CL_ERROR(error,"Could not create command_queue")
            printf("Name : %s\n", name);     
            switch(i) { 
                case 1: 
	                  error  = clSetKernelArg(kernels[id], 0, sizeof(cl_mem), (void*)&d_buf0);
	                  error |= clSetKernelArg(kernels[id], 1, sizeof(cl_mem), (void*)&d_buf1);
	                  error |= clSetKernelArg(kernels[id], 2, sizeof(cl_mem), (void*)&d_cost);
                      CHECK_CL_ERROR(error,"Arugment can not be set for kernel 1")
                      break;
                case 2:
	                  error  = clSetKernelArg(kernels[id], 0, sizeof(cl_mem), (void*)&d_row);
                      CHECK_CL_ERROR(error,"Arugment can not be set")
                      break;
                case 3:
	                  error  = clSetKernelArg(kernels[id], 0, sizeof(cl_mem), (void*)&d_edge);
                      CHECK_CL_ERROR(error,"Arugment can not be set")
                      break;
                case 4:
	                  error  = clSetKernelArg(kernels[id], 0, sizeof(cl_mem), (void*)&d_buf0);
	                  error |= clSetKernelArg(kernels[id], 1, sizeof(cl_mem), (void*)&d_buf1);
	                  error |= clSetKernelArg(kernels[id], 2, sizeof(int)   , (void*)&source);
                      CHECK_CL_ERROR(error,"Arugment can not be set")
                      break;
                default: break; 
            }
            error = clEnqueueTask(queues[id],
                                  kernels[id],
                                  0,
                                  NULL,
                                  NULL);
            CHECK_CL_ERROR(error,"Kernel did not run")
       }
    }



    //Wait for the get_neighbor kernel to finish
    for(unsigned int i = 0; i < kernel_count; i++) {
        for(unsigned int j = 0; j < kernel_info[i].count; j++) { 
            char name[30];
            unsigned int id;
            id = i*kernel_count + j;
            if(kernel_info[i].wait_finish) {
                printf("Waiting for kenel %s%d\n",kernel_info[i].name,j);
                clFinish(queues[id]);
            }

        }
    }

    //Transfer the result back to device
    clEnqueueReadBuffer(commands,
                        d_cost,
                        CL_TRUE,
                        0,
                        sizeof(int) * nodes,
                        (void*)a_cost,
                        0,
                        NULL,
                        &ocdTempEvent);
    TIME_RECORD(ocdTempEvent,OCD_TIMER_D2H,"Bfs Graph Results Copy", ocdTempTimer)

    if(debug) 
        for(int i = 0; i < nodes; i++) 
            printf("Cost[%0d] : %0d\n", i, a_cost[i]);


//This section checks the correctness of program
    for(int i = 0; i < nodes; i++)
    {
        if(a_cost[i] != a_serial_dist[i])
            printf("Error: FPGA Distance [%0d] = Serial = %0d : FPGA %0d\n",
                    i+1, a_serial_dist[i],a_cost[i]);
    }

 //   printf("CPU TIME: Serial: %f\n", (end_serial - start_serial)/(double)CLOCKS_PER_SEC);

    //Free the memory
    for(unsigned int i = 0; i < kernel_count; i++) {
        for(unsigned int j = 0; j < kernel_info[i].count; j++) { 
            unsigned int id;
            id = i*kernel_count + j;
	        clReleaseKernel(kernels[id]);
	        clReleaseCommandQueue(queues[id]);
        }
    }

//    free(kernels);
//    free(queues);

    free(a_dist);
    free(a_row);
    free(a_edge);
    clReleaseMemObject(d_buf0);
    clReleaseMemObject(d_buf1);
    clReleaseMemObject(d_row);
    clReleaseMemObject(d_edge);
    clReleaseMemObject(d_cost);
	clReleaseProgram(bfs_program);
	clReleaseCommandQueue(commands);
	clReleaseContext(context);

}
