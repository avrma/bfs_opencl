    __private next_front_t frnt; 
    __private unsigned int edge;
    __private bool word_fetched = false;
    __private bool rvalid = false;
    __private bool terminate = false;
    __private edge_t edge_send;

#ifdef DEBUG 
    printf("Started : get_next_frnt_%0d\n",id);
#endif 

#pragma acc kernels loop independent
    for(ulong inf_counter = 0 ; inf_counter < ULONG_MAX; inf_counter++) { 
        if(!rvalid) {
            frnt = read_channel_nb_altera(frnt_c[id], &rvalid);
        }
        else { 
            if (word_fetched == false) {
                if((frnt.loc != SYNC_INT) & (frnt.terminate != true)) {
                    edge = frnt.buffer_id ? buf1[frnt.loc] : buf0[frnt.loc];
                    cost[edge-1] = frnt.level;
#ifdef DEBUG 
                    printf("get_next_frnt[%0d]: edge = %0d L = %0d\n",
                            id,edge,frnt.level);
#endif 
                } 
                else 
                    edge = SYNC_INT;

                word_fetched = true;
                terminate = frnt.terminate;
                edge_send.vertex = edge; 
                edge_send.terminate = terminate;
            }
            else {
            __private bool wvalid = false;
                wvalid = write_channel_nb_altera(out_edge_c[id], edge_send);
                if(wvalid) {
#ifdef DEBUG
                    printf("get_next_frnt[%0d]: vertex %0du : Term = %0d\n",
                            id, edge_send.vertex,edge_send.terminate);
#endif
                    rvalid = false;
                    word_fetched = false;
                    if(terminate) {
#ifdef DEBUG
                        printf("returning get_next_frnt%0d\n",id);
#endif 
                        return;
                    }
                }
            }
        }
    }

