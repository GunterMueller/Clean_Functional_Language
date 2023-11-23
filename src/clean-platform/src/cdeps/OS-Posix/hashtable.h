/*
 * This file provides a hashtable which is used to store the (write)queues of clients and pipes
 * using the System.AsyncIO module.
 *
 * The hashtable could be replaced by a generic hashtable provided by an external library.
 *
 * The Posix version is different from the Windows version because for Posix,
 * a single receive buffer can be used for all clients as reading is done synchronously.
 * On Windows, the hashtable also stores a receive buffer for every client and pipe because
 * reading is done asynchronously and the receive buffer may not be reused before the
 * asynchronous reading operation completes.
 *
 * Windows does not use a writequeue for each clients and pipe because data is sent asynchronously and data
 * does not need to be stored in a writequeue.
 *
 */
#ifndef __CHT__
#define __CHT__

typedef struct table_entry_t table_entry_t;
typedef struct hashtable_t hashtable_t;
typedef struct queue_t queue_t;

// Stores file descriptor and context it is being monitored for (e.g AcceptEventSock).
typedef struct io_data_s {
	int fd;
	int op;
} io_data_t;

typedef struct table_entry_t {
	queue_t* queue;
	io_data_t* io_data;
	table_entry_t* next_entry;
	char key[];
} table_entry_t;

typedef struct hashtable_t {
	int size;
	table_entry_t** table;
} hashtable_t;


hashtable_t* initHT(int size);

table_entry_t* getHT(hashtable_t* ht, char* key);

int removeHT(hashtable_t* ht, char* key);

int putHT(hashtable_t* ht, char* key, queue_t* queue, io_data_t* io_data);

int hash(char* key);
#endif
