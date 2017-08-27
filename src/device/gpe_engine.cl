WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_next_frnt_0(__global volatile int * restrict buf0,
                     __global volatile int * restrict buf1,
                     __global int * restrict cost) {

    __private const uint id=0;
    #include "get_next_frnt.cl"
}


WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_row_0(__global int * restrict row) {
    const int id=0;
    #include "get_row.cl"
}

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_neighbors_0(__global int * restrict edge) {
    const int id=0;
    #include "get_neighbors.cl"
}



WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void master_bfs_0() {

    //Engine Id, Master has Id=0
    const unsigned int id=0;
    #include "master_bfs.cl"
}


#if NO_OF_GPE > 1

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_next_frnt_1(__global volatile int * restrict buf0,
                   __global volatile int * restrict buf1,
                   __global int * restrict cost) {

    __private const uint id=1;
    #include "get_next_frnt.cl"
}


WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_row_1(__global int * restrict row) {
    const int id=1;
    #include "get_row.cl"
}

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_neighbors_1(__global int * restrict edge) {
    const int id=1;
    #include "get_neighbors.cl"
}



WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void master_bfs_1() {

    const unsigned int id=1;
    #include "master_bfs.cl"
}


#endif //NO_OF_GPE > 1

#if NO_OF_GPE > 2

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_next_frnt_2(__global volatile int * restrict buf0,
                   __global volatile int * restrict buf1,
                   __global int * restrict cost) {

    __private const uint id=2;
    #include "get_next_frnt.cl"
}


WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_row_2(__global int * restrict row) {
    const int id=2;
    #include "get_row.cl"
}

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_neighbors_2(__global int * restrict edge) {
    const int id=2;
    #include "get_neighbors.cl"
}



WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void master_bfs_2() {

    //Engine Id, Master has id=2
    const unsigned int id=2;
    #include "master_bfs.cl"
}


#endif //NO_OF_GPE > 2


#if NO_OF_GPE > 3

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_next_frnt_3(__global volatile int * restrict buf0,
                   __global volatile int * restrict buf1,
                   __global int * restrict cost) {

    __private const uint id=3;
    #include "get_next_frnt.cl"
}


WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_row_3(__global int * restrict row) {
    const int id=3;
    #include "get_row.cl"
}

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_neighbors_3(__global int * restrict edge) {
    const int id=3;
    #include "get_neighbors.cl"
}



WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void master_bfs_3() {

    //Engine Id, Master has id=3
    const unsigned int id=3;
    #include "master_bfs.cl"
}


#endif //NO_OF_GPE > 3

#if NO_OF_GPE > 4

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_next_frnt_4(__global volatile int * restrict buf0,
                   __global volatile int * restrict buf1,
                   __global int * restrict cost) {

    __private const uint id=4;
    #include "get_next_frnt.cl"
}


WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_row_4(__global int * restrict row) {
    const int id=4;
    #include "get_row.cl"
}

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_neighbors_4(__global int * restrict edge) {
    const int id=4;
    #include "get_neighbors.cl"
}



WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void master_bfs_4() {

    //Engine Id, Master has id=4
    const unsigned int id=4;
    #include "master_bfs.cl"
}


#endif //NO_OF_GPE > 4

#if NO_OF_GPE > 5

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_next_frnt_5(__global volatile int * restrict buf0,
                   __global volatile int * restrict buf1,
                   __global int * restrict cost) {

    __private const uint id=5;
    #include "get_next_frnt.cl"
}


WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_row_5(__global int * restrict row) {
    const int id=5;
    #include "get_row.cl"
}

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_neighbors_5(__global int * restrict edge) {
    const int id=5;
    #include "get_neighbors.cl"
}



WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void master_bfs_5() {

    //Engine Id, Master has id=5
    const unsigned int id=5;
    #include "master_bfs.cl"
}


#endif //NO_OF_GPE > 5

#if NO_OF_GPE > 6

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_next_frnt_6(__global volatile int * restrict buf0,
                   __global volatile int * restrict buf1,
                   __global int * restrict cost) {

    __private const uint id=6;
    #include "get_next_frnt.cl"
}


WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_row_6(__global int * restrict row) {
    const int id=6;
    #include "get_row.cl"
}

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_neighbors_6(__global int * restrict edge) {
    const int id=6;
    #include "get_neighbors.cl"
}



WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void master_bfs_6() {

    //Engine Id, Master has id=6
    const unsigned int id=6;
    #include "master_bfs.cl"
}


#endif //NO_OF_GPE > 6

#if NO_OF_GPE > 7

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_next_frnt_7(__global volatile int * restrict buf0,
                     __global volatile int * restrict buf1,
                     __global int * restrict cost) {

    __private const uint id=7;
    #include "get_next_frnt.cl"
}


WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_row_7(__global int * restrict row) {
    const int id=7;
    #include "get_row.cl"
}

WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void get_neighbors_7(__global int * restrict edge) {
    const int id=7;
    #include "get_neighbors.cl"
}



WORK_DIM(0)
COMP_UNIT(1,1)
kernel
void master_bfs_7() {

    //Engine Id, Master has id=7
    const unsigned int id=7;
    #include "master_bfs.cl"
}


#endif //NO_OF_GPE > 7

#if NO_OF_GPE > 8
#pragma error "Support upto 8 GPE Engines, update NO_OF_GPE define"
#endif //NO_OF_GPE

