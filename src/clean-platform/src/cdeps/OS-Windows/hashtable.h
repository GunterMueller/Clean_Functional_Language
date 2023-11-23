/*
 * This file provides a hashtable which is used to store the:
 * - Receive buffer of clients and pipes
 * - The amount of packets remaining to be asynchronously sent to the peer.
 *
 * It is used by the System.AsyncIO module.
 *
 * The hashtable could be replaced by a generic hashtable provided by an external library.
 *
 * The Posix version is different from the Windows version because for Posix,
 * a single receive buffer can be used for all clients as reading is done synchronously.
 * On Windows, the hashtable also stores a receive buffer for every client and pipe because
 * reading is done asynchronously and the receive buffer may not be reused before the
 * asynchronous reading operation completes. The writequeue used by the Posix hashtable is
 * not necessary for Windows as data is sent asynchronously and thus does not need to be stored in a writequeue.
 *
 * On Windows the number of packets to write is stored as well.
 * This is done to be able to determine whether all the data to be sent has been sent.
 * This is relevant because a connection to a peer is only closed when a callback indicates to close the connection
 * after all data has arrived. On Posix this can be determined by looking at whether the writequeue is empty.
 */

#ifndef __CHT__
#define __CHT__

#include <winsock2.h>
#include <windows.h>
#include "..\Clean.h"

typedef struct table_entry_s table_entry_t;

typedef struct table_entry_s {
// The internal buffer of the receivebuffer provided to WSARecv is the buffer (CleanStringCharacters) of the CleanString below.
	// The received data thus gets loaded into rcv_buf_clean, this is done to return a CleanString to Clean.
	CleanString rcv_buf_clean;
	int packets_to_write;
	table_entry_t* next_entry;
	char key[];
} table_entry_t;

typedef struct hashtable_s {
	int size;
	table_entry_t** table;
} hashtable_t;

hashtable_t* initHT(int size);

table_entry_t* getHT(hashtable_t* ht, char* key);

int removeHT(hashtable_t* ht, char* key);

int putHT(hashtable_t* ht, char* key, table_entry_t* entry);

int hash(char* key);
#endif
