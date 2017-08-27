/* Author : Anshuman Verma
 * Email  : anshuman@vt.edu
 * Description : Kernel for Breadth First Search, targeted for FPGA when
 * compiled using Altera OpenCL Compiler. It uses multiple parallel engines to
 -* traverse the graph and stores the costance for each of the node from a
 * provided source node. It uses a bit-map array to store the traversal
 * information. This bit map array is implemented using M20K blocks in FPGA.
 * This is a level sensitive Breadth first search. Refer to the paper for more
 * details about the design of kernels and algorithm.
 */

/* Enable the altera channels */
#pragma OPENCL EXTENSION cl_altera_channels : enable

/* Maximum number of Vertex that this program is expected to handle. This number
 * is limited by the amound of available memory on Chip. A better idea is to
 * have bit map array created in SRAM. Unfortunately, my current board does not
 * have a SRAM attached to it.
 */
#define MAX_VERTEX_COUNT 4*1024*1024

#define BIT_MAP_DEPTH MAX_VERTEX_COUNT/32

/* Defines for shortcut: Declare work dimension of kerel and number of compute
 * units. I intend to write the kernels manually for operation and set the
 * arguments.
 */
#define WORK_DIM(N)    __attribute__((max_global_work_dim(N)))

#define COMP_UNIT(M,N) __attribute__((num_compute_units(M,N)))

/* Spcify Graph Processing Engines (GPE) are working in Parallel */
#define NO_OF_GPE 4

/* Specify the channel depth. This would be optimized by the kernel anyhow, in
 * case of optimization does not happen, the provided number of be the depth of
 * the channel.
 */
#define CHANNEL_DEPTH 16

/* Sync from GPE to bit map */
#define SYNC_INT 0xFFFFFFFF

//DEBUG Flag, Enable for printf messages
//#define DEBUG

/* Enumerator to specify the state of FSM in GPE */
typedef enum {
              //CHILD,       //Traverse neighbor of a node
              NEXT_VERTEX,   //Get the next vertex from assigned buffer
              SYNC           //Wait for sync and move to next level
              //EXIT          //Exit when all the connected components complete
             } bfs_state_e;

//Struct for command channel to each of the Graph Processing Engine
typedef struct { uint   start;  //Start pointer in next frontier array
                 ushort count;  //Number of vertices to be processed
                 bool   buf_id; //Which array to process
                 bool   terminate; //No more nodes to process
               } command_gpe_s;

typedef struct { unsigned int   start;
                 unsigned short count;
                 bool           terminate;
               } neighbor_t;

typedef struct { unsigned int loc;
                 unsigned char level;
                 bool buffer_id;
                 bool terminate;
               } next_front_t;

typedef struct { unsigned int vertex;
                 bool terminate;
               } edge_t;


/* Command channel from bit map arrray to each of the GPE to notify that they
 * can process the next frontier array and move to next level. Most of the time
 * GPE would twiddle the thumbs because of high latency from DRAM to read the
 * data words and irregular pattern of algorithm.
 */
channel command_gpe_s cmd_c[NO_OF_GPE]   __attribute__((depth(CHANNEL_DEPTH)));

//Request the next front
channel next_front_t frnt_c[NO_OF_GPE] __attribute__((depth(CHANNEL_DEPTH)));

//Request the edge
channel edge_t out_edge_c[NO_OF_GPE] __attribute__((depth(CHANNEL_DEPTH)));

//Provide count and neighbors
channel neighbor_t out_v [NO_OF_GPE] __attribute__((depth(CHANNEL_DEPTH)));

/* Channel from each of GPE to bit map array locater that would find the
 * traversal information from local array and push the node to a next frontier
 * queue in case this node has not been visited earlier.
 */
channel int child_c[NO_OF_GPE] __attribute__((depth(CHANNEL_DEPTH)));

#include "gpe_engine.cl"

WORK_DIM(0)
COMP_UNIT(1,1)
__kernel
void bit_map_array(__global volatile int * restrict next_f1,
                   __global volatile int * restrict next_f2,
                   unsigned int source) {

    __private unsigned int vertex_bit_map[BIT_MAP_DEPTH];
    __private unsigned int count_in_next_level = 1;
    __private unsigned int curr_level = 0;
    __private bool sync_expected[NO_OF_GPE];
    __private bool sync_flag[NO_OF_GPE];
    __private bool data_written[NO_OF_GPE];
    __private bool terminate = false;
    __private bool exit_cond = false;

    next_f1[0] = source;
    vertex_bit_map[(source >> 5) & (BIT_MAP_DEPTH-1)] = 1 << (source & 0x1F);
    
     mem_fence(CLK_GLOBAL_MEM_FENCE|CLK_LOCAL_MEM_FENCE);

#ifdef DEBUG 
    printf("Kernel bit_map_array started soruce= %0d\n",source);
#endif 

#pragma acc kernels loop independent
    for(ulong inf_cnt = 0 ; inf_cnt < ULONG_MAX; inf_cnt++)  {
        __private bool wvalid[NO_OF_GPE];
        __private command_gpe_s cmd[NO_OF_GPE];
        __private uint vertex[NO_OF_GPE];
        __private int k = 0;
        __private bool sync_achieved = true;

        k  = 0;

#pragma unroll NO_OF_GPE 
        for(uint channel_no = 0; channel_no < NO_OF_GPE; channel_no++) {
            data_written[channel_no] = false;
        }

#pragma unroll NO_OF_GPE
        for(uint channel_no = 0 ; channel_no < NO_OF_GPE; channel_no++) {
        __private bool rvalid[NO_OF_GPE];

            vertex[channel_no] = read_channel_nb_altera(child_c[channel_no],
                                                        &rvalid[channel_no]);

            if(rvalid[channel_no]) {
                __private uint read_id = (vertex[channel_no] >> 5) & 
                                         (BIT_MAP_DEPTH-1);
                __private bool traversed;
                __private uchar mask;
                __private uint curr_state;
                __private bool is_sync; 

                is_sync = (vertex[channel_no] == SYNC_INT);

                sync_flag[channel_no] |= is_sync;
                mask = vertex[channel_no] & 0x1F;
                curr_state = vertex_bit_map[read_id];
                traversed = (vertex_bit_map[read_id] >> mask) & 0x1;
                data_written[channel_no] = (is_sync == false) &  
                                           (traversed == false);

                if(traversed == false) {
                    vertex_bit_map[read_id] = curr_state | (1 << mask);
                }
            }
        }


#pragma unroll NO_OF_GPE
        for(uint channel_no = 0; channel_no < NO_OF_GPE; channel_no++) {
            if(data_written[channel_no]) {
                if(curr_level & 0x1) {
                    next_f2[count_in_next_level+k] = vertex[channel_no];
                }
                else {
                    next_f1[count_in_next_level+k] = vertex[channel_no];
                }
                k++;
            }
        }

        mem_fence(CLK_GLOBAL_MEM_FENCE|CLK_CHANNEL_MEM_FENCE);

#pragma unroll NO_OF_GPE
        for(uint channel_no = 0; channel_no < NO_OF_GPE; channel_no++) {
            if(data_written[channel_no] == true)
                count_in_next_level+=1;
        }

#pragma unroll NO_OF_GPE
        for(uint channel_no = 0; channel_no < NO_OF_GPE; channel_no++) {

            sync_achieved = sync_achieved & 
                            sync_flag[channel_no];
        }

        exit_cond = terminate & sync_achieved;

        if( (sync_achieved|(curr_level == 0))) {
            __private uint elem[NO_OF_GPE];
            __private uint count_for_each;
            __private uint extra_elem;
#ifdef DEBUG
            printf("Bit_Map_Array: Sync %0d\n", sync_achieved);
#endif 

            count_for_each = count_in_next_level/NO_OF_GPE;
            extra_elem     = count_in_next_level%NO_OF_GPE;

#pragma unroll NO_OF_GPE
            for(int channel_no = 0; channel_no < NO_OF_GPE; channel_no++) { 
                sync_flag[channel_no] = false;
                if(channel_no == 0)
                    elem[channel_no] = (extra_elem == 0) ? 
                                        count_for_each : 
                                        count_for_each + extra_elem ;
                else 
                    elem[channel_no] = count_for_each;
            }

#pragma unroll NO_OF_GPE
            for(int channel_no = 0; channel_no < NO_OF_GPE; channel_no++) { 
                if(channel_no == 0)
                    cmd[channel_no].start = 0; 
                else 
                    cmd[channel_no].start = cmd[channel_no-1].start +
                                             elem[channel_no-1];
                cmd[channel_no].count = elem[channel_no];
                cmd[channel_no].terminate = (count_in_next_level == 0);
                cmd[channel_no].buf_id = curr_level & 0x1;
            }

            terminate = count_in_next_level == 0;


#pragma unroll NO_OF_GPE
            //if(count_in_next_level == 0) return;
            for(uint channel_no = 0 ; channel_no < NO_OF_GPE; channel_no++) {
                write_channel_altera(cmd_c[channel_no], cmd[channel_no]);
#ifdef DEBUG 
                printf("bit_map_array sending Level = %0d command[%0d]:\
                        Start = %0d, count = %0d, terminate = %0d, \
                        buffer_id = %0d count_in_next_lvl = %0d \n", 
                        curr_level, channel_no,cmd[channel_no].start, 
                        cmd[channel_no].count, cmd[channel_no].terminate,
                        cmd[channel_no].buf_id, count_in_next_level);
#endif 
             }
             mem_fence(CLK_CHANNEL_MEM_FENCE|CLK_LOCAL_MEM_FENCE);
            //Reset count for next level sync BFS 
            curr_level++;
            count_in_next_level = 0;
        }
    }
}
