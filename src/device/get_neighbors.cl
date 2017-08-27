    __private neighbor_t vertex;
    __private unsigned int count=0;
    __private unsigned int loc_count=0;
    __private unsigned int neighbor = 0;
    __private bool terminate = false;
    __private bool fetched = false;

#ifdef DEBUG
    printf("Started : get_neighbors_%0d\n",id);
#endif

#pragma acc kernels loop independent
    for(ulong inf_counter = 0; inf_counter < ULONG_MAX; inf_counter++) { 
    __private bool rvalid = false; 
    __private bool wvalid = false;
        if(count == 0) { 
            vertex = read_channel_nb_altera(out_v[id],&rvalid);
            if(rvalid) {
                count = vertex.count;
                terminate = vertex.terminate;
            }
        }
        else { 
            if(fetched == false) {
                if((vertex.start != SYNC_INT) & (terminate == false))
                    neighbor = edge[vertex.start+loc_count]; 
                else {
                    neighbor = SYNC_INT;
                    count = 1;
                }
                fetched = true;
            }
            wvalid = write_channel_nb_altera(child_c[id], neighbor);
            if(wvalid) {
#ifdef DEBUG 
                printf("get_neighbor[%0d], child = %0d\n", id,neighbor);
#endif
        
                loc_count++;
                fetched = false;
                if(loc_count == count) {
                    count = 0; 
                    loc_count = 0;
                }
                if(terminate) {
#ifdef DEBUG
                    printf("returning get_neighbor%0d\n",id);
#endif 
                    return;
                }
            }
        }
    }

