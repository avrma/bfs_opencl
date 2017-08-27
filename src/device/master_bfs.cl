    //Current state of GPE   
    __private bfs_state_e curr_state = SYNC;

    //Number of neighbors for current vertex
    __private unsigned int no_of_neighbor = 0;   

    //Start  in edge array for curr vertex
    __private unsigned int vertex = 0;  

    //Current level in level-sync BFS
    __private unsigned int curr_level = 0;   

    //Start pointer for next frontier
    __private unsigned int n_front_curr_ptr = 0;

    //Send the sync to bit map array engine notifying that elements are
    //processed
    __private bool send_sync = false;

    //Use next_frontier0 if false else frontier1
    __private bool buffer_id = 0;          
    

    //Number of nodes to be processed by this GPE in curr_level
    __private unsigned int vertex_to_process_in_frontier = 0;
    
    //Number of nodes processed by this GPE in curr_level
    __private unsigned int processed_vertex_in_frontier = 0;

    __private bool terminate = false;
   
#ifdef DEBUG 
    printf("Started master_bfs_%0d\n",id);
#endif  

#pragma acc kernels loop independent
    for(ulong infinite_cnt = 0; infinite_cnt < ULONG_MAX; infinite_cnt++) {
    __private bfs_state_e next_state;

        switch(curr_state) {
           case NEXT_VERTEX:
                if(((vertex_to_process_in_frontier + 1) ==
                     processed_vertex_in_frontier ) && 
                    terminate == false) {
                        next_state = SYNC;
                }
                else {
                __private unsigned int location;
                __private next_front_t edg;
                __private bool wvalid_edg_v;
                    location = n_front_curr_ptr + 
                               processed_vertex_in_frontier;
                    edg.loc = vertex_to_process_in_frontier ==
                              processed_vertex_in_frontier  ? SYNC_INT 
                                                            : location;
                    edg.buffer_id = buffer_id;
                    edg.level = curr_level;
                    edg.terminate = terminate;
                    wvalid_edg_v = write_channel_nb_altera(frnt_c[id], edg);
                    if(wvalid_edg_v) {
                        processed_vertex_in_frontier++;
#ifdef DEBUG
                        printf("master_bfs[%0d] : Edg: location = %0d \
                        buf_id = %0d, term = %0d level = %0d\n",
                        id, edg.loc, edg.buffer_id, edg.terminate, edg.level);
#endif
                        if(terminate) { 
#ifdef DEBUG
                             printf("returning master_bfs%0d\n",id);
#endif 
                             return;
                        }
                    }
                    next_state = NEXT_VERTEX;
                }
                break;
            case SYNC: {  
                    __private command_gpe_s cmd;
                    __private bool sync_rcvd;
                    cmd = read_channel_nb_altera(cmd_c[id],&sync_rcvd);
                    if(sync_rcvd) {
#ifdef DEBUG
                        printf("master_bfs[%0d] count = %0d, buf_id =%0d \
                        curr_level = %0d, start = %0d \n", 
                        id,cmd.count,cmd.buf_id,curr_level,cmd.start);
#endif 
                        vertex_to_process_in_frontier = (uint) cmd.count;
                        buffer_id = cmd.buf_id;
                        n_front_curr_ptr = cmd.start;
                        curr_level++;
                        processed_vertex_in_frontier = 0;
                        terminate = cmd.terminate;
                        next_state = NEXT_VERTEX;
                    }
                    else
                        next_state = SYNC;
            }
                break;
            default : break;
        }
        curr_state = next_state;
    }

