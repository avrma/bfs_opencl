#pragma OPENCL EXTENSION cl_altera_channels : enable

#define MAX_VERTEX_COUNT  50000
#define MAX_EDGE_SIZE   1000000
#define WRITE 0xFFFFFFFF;
#define READ  0xFFFFFFFE;
#define UNROLL_FACTOR 8

channel int in  __attribute__((depth(20)));
channel int out __attribute__((depth(10)));

void write_data(int data_in) { 
bool success; 
    success = write_channel_nb_altera(in,data_in);
}
    


__attribute__((reqd_work_group_size(1,1,1)))
__kernel void bfs_kernel (__global int * restrict node,
                          __global int * restrict edge,
                          __global int * restrict dist,
                          __global int * restrict hier, 
                                   int   edge_count,
                                   int   node_count,
                                   int   source) 
{
    __private int curr_pointer = 0;
    __private int curr_level = 1;
    __private int nodes_in_level = 1;
    __private int nodes_in_next_level = 0;
    __private int  rd_ptr = 0; 
    __private int  wr_ptr = 0; 
    __private bool visited[MAX_VERTEX_COUNT]; //Initialize this ? 
    __local   int  fifo[MAX_EDGE_SIZE];



    do {
       nodes_in_next_level = 0;
       for(int i = 0; i < nodes_in_level; i++) {
        __private int curr_node; 
        __private int node_start_ptr;
        __private int node_end_ptr;
        __private int neighbor_start;
        __private int neighbor_count;
        __private int neighbor_count_unroll;
        __private int neighbor_count_unroll_remain;
               if(visited[source-1] == false) {
                    visited[source - 1] = true; 
                    hier[source - 1 ]   = 0;
                    curr_node = source;
               } else {
                    curr_node = fifo[rd_ptr];
                    rd_ptr++;
                    if(rd_ptr == MAX_EDGE_SIZE) rd_ptr = 0;
               }
              //printf("Current Node = %0d Level = %0d \n", curr_node, curr_level);

               node_start_ptr = node[curr_node - 1];
               node_end_ptr   = node[curr_node];
               neighbor_count = node_end_ptr - node_start_ptr;
               neighbor_count_unroll        = neighbor_count/UNROLL_FACTOR;
               neighbor_count_unroll_remain = neighbor_count%UNROLL_FACTOR;

              #pragma loop unroll UNROLL_FACTOR
               for(int j = 0; j < UNROLL_FACTOR * (neighbor_count_unroll+1); j++) {
               __private int neighbor;
                       neighbor = edge[node_start_ptr+j] - 1;
                       if(visited[neighbor] == false && j < neighbor_count) {
                            nodes_in_next_level++;
                            hier[neighbor]    = curr_level;
                            visited[neighbor] = true;
                            fifo[wr_ptr] = neighbor+1;
                            wr_ptr++;
                            if(wr_ptr == MAX_EDGE_SIZE) wr_ptr = 0; 
                       }
               }
               //for(int j = 0; j < neighbor_count_unroll_remain; j++) {
               //__private int neighbor;
               //        neighbor = edge[node_start_ptr+j+UNROLL_FACTOR*neighbor_count_unroll] - 1;
               //        if(visited[neighbor] == false) {
               //             nodes_in_next_level++;
               //             hier[neighbor]    = curr_level;
               //             visited[neighbor] = true;
               //             fifo[wr_ptr] = neighbor+1;
               //             wr_ptr++;
               //             if(wr_ptr == MAX_EDGE_SIZE) wr_ptr = 0; 
               //        }
               //}
    }
        nodes_in_level = nodes_in_next_level;
        curr_level++;
    } while (nodes_in_next_level);

    
    //mem_fence(CLK_GLOBAL_MEM_FENCE);

    //for(int i = 0; i < node_count; i++) 
    //      printf("Distance from Source[%0d] = %0d\n", i+1, hier[i]);

    //for(int i = 0; i < node_count; i++) {
    //    for(int j = 0; j < node[i+1]- node[i]; j++) {
    //        printf("FPGA Edge S = %0d D = %0d W = %0d H = %0d\n", i+1, edge[curr_pointer], dist[i], hier[i]);
    //        curr_pointer++;
    //    }
    //}
}

__kernel void bfs_queue() {
//__local int fifo[MAX_VERTEX_COUNT];
int fifo_depth = 0;
int in_data;
int top_data = -1;
int  rd_ptr = 0;
int  wr_ptr = 0;
bool success = false;
bool first_data = true;

//    while(1) { 
//        in_data = read_channel_nb_altera(in, &success);
//        if(success) {
//            fifo[wr_ptr] = in_data;
//            wr_ptr++;
//            if(wr_ptr == MAX_VERTEX_COUNT - 1) wr_ptr = 0;
//            fifo_depth++;
//        }
//        if(fifo_depth) {
//            top_data = fifo[rd_ptr];
//            success = write_channel_nb_altera(out,top_data);
//            if(success) {
//                rd_ptr++;
//                if(rd_ptr == MAX_VERTEX_COUNT - 1) rd_ptr = 0;
//                fifo_depth--;
//            }
//        }
//    }
}
