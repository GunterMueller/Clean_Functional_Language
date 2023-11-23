#include <stdlib.h>
#include "queue.h"
#include <string.h>

queue_t* initQueue() {
	queue_t* queue = (queue_t*) malloc(sizeof(queue_t));
	if (queue == NULL) {
		return NULL;
	}
	queue->begin = NULL;
	queue->end = NULL;
	return queue;
}

packet_t* createPacket(char* data, int size) {
	packet_t* packet = (packet_t*) malloc(sizeof(packet_t));
	if (packet == NULL) {
		return NULL;
	}
	packet->data = data;
	packet->size = size;
	packet->next_packet = NULL;
	return packet;
}

int enqueue(queue_t* queue, char* data, int size) {
	packet_t* packet = createPacket(data, size);
	// Malloc fail.
	if (packet == NULL) {
		return -1;
	}
	if (queue->begin == NULL) {
		queue->begin = packet;
		queue->end = packet;
	} else {
		queue->end->next_packet = packet;
		queue->end = packet;
	}

	return 0;
}

// Data is going to be a pointer not obtained through malloc(). The packet is recreated so it can be freed.
int enqueueFront(queue_t* queue, char* data, int size) {

	char* newPacketData = (char*) malloc(size * sizeof(char));
	memcpy(newPacketData, data, size * sizeof(char));
	packet_t* packet = createPacket(newPacketData, size);
	if (packet == NULL) {
		return -1;
	}

	if (queue->begin == NULL) {
		queue->begin = packet;
		queue->end = packet;
	} else {
		packet->next_packet = queue->begin;
		queue->begin = packet;
	}
	return 0;
}

packet_t* dequeue (queue_t* queue) {
	if (queue->begin == NULL) {
		return NULL;
	}

	packet_t* packet = queue->begin;
	queue->begin = packet->next_packet;
	if(queue->begin == NULL) {
		queue->end = NULL;
	}
	return packet;
}

int isEmpty (queue_t* queue) {
	if (queue == NULL) {
		return 1;
	}
	return queue->begin == NULL;
}

int freeQueue (queue_t* queue) {
	while (!isEmpty(queue)){
		packet_t* packet = dequeue(queue);
		free(packet->data);
		free(packet);
	}
	free(queue);
	return 0;
}
