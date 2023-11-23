#include <stdlib.h>
#include <stddef.h>
#include <stdio.h>
#include "string.h"
#include "hashtable.h"

hashtable_t* initHT(int size) {
	hashtable_t* ht = (hashtable_t*) calloc(1, sizeof(hashtable_t));
	if (ht == NULL) {
		return NULL;
	}
	ht->table = calloc(1, size*sizeof(table_entry_t*));
	if(ht->table == NULL) {
		return NULL;
	}
	ht->size = size;
	for (unsigned int i = 0; i < size; i++) {
		ht->table[i] = NULL;
	}

	return ht;
}


table_entry_t* getHT(hashtable_t* ht, char* key) {
	int index = hash(key) % ht->size;
	table_entry_t* entry = ht->table[index];
	while (entry != NULL) {
		if (!strcmp(entry->key,key)) {
			return entry;
		}
		entry = entry->next_entry;
	}
	return NULL;
}

int removeHT(hashtable_t* ht, char* key) {
	int index = hash(key) % ht->size;
	table_entry_t* entry = ht->table[index];
	// Previous entry in case of collision.
	table_entry_t* prev_entry = NULL;
	while (entry != NULL) {
		if(!strcmp(entry->key, key)) {
			// Was a collision at some point so the next_entry needs to be linked up.
			if (prev_entry != NULL) {
				prev_entry->next_entry = entry->next_entry;
			} else { // No collision.
				ht->table[index] = entry->next_entry;
			}
			free(entry->rcv_buf_clean);
			free(entry);
			entry = NULL;
			return 0;
		}
		prev_entry = entry;
		entry = entry->next_entry;
	}
	return -1;
}

int putHT(hashtable_t* ht, char* key, table_entry_t* entry) {
	int index = hash(key) % ht->size;
	table_entry_t* curr_entry = ht->table[index];

	// Case value is present
	while (curr_entry != NULL) {
		if (!strcmp(curr_entry->key, key)) {
			curr_entry = entry;
			return 0;
		}
		curr_entry = curr_entry->next_entry;
	}

	// Case value is not present
	strcpy(entry->key, key);
	entry->next_entry = ht->table[index];
	ht->table[index] = entry;
	return 0;
}

// Daniel J. Bernstein hashing algorithmn.
int hash(char* key) {
	unsigned int h = 5381;
	while(*(key++)){
		h = ((h << 5) + h) + (*key);
	}
	return h;
}
