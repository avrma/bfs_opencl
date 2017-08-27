    __private bool rvalid;
    __private bool wvalid = false;
    __private edge_t ptr;
    __private bool count = false;
    __private neighbor_t out;
    __private bool fetch = false;
    __private bool terminate = true;
    __private bool sync = false;

#ifdef DEBUG 
    printf("Started ; get_row_%0d\n", id);
#endif

#pragma acc kernels loop independent
    for(ulong inf_counter = 0 ; inf_counter < ULONG_MAX; inf_counter++) { 
        if(count == false) {
            ptr = read_channel_nb_altera(out_edge_c[id], &rvalid);
            if(rvalid) {
                terminate = ptr.terminate;
                sync = (ptr.vertex == SYNC_INT);
                out.start = (sync | terminate) ? 
                            SYNC_INT : row[ptr.vertex-1];
                out.terminate = terminate;
                count = true;
                fetch = true;
#ifdef DEBUG 
                printf("get_row[%0d]: start = %0d vrx = %0du, termte = %0d\n",
                id,out.start,ptr.vertex,out.terminate);
#endif 
            }
        }       
        else { 
            if(fetch == true) {
                out.count =  (sync | terminate) ?
                              1 : (row[ptr.vertex] - out.start); 
                fetch = false;
            }
            wvalid = write_channel_nb_altera(out_v[id],out);
            if(wvalid) { 
#ifdef DEBUG 
                printf("get_row[%0d] : count = %0d : terminate = %0d \
                        Start = %0d\n", id, out.count, out.terminate, out.start);
#endif 
                count = false;
                if(terminate) { 
#ifdef DEBUG
                    printf("returning get_row_%0d\n",id);
#endif 
                    return;
                }
            }
        }
    }

